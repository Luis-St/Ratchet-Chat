// Ratchet-Chat Service Worker for Push Notifications
// Handles E2EE push notifications with client-encrypted previews

const DB_NAME = "RatchetChat"

// ============================================
// Crypto imports (loaded via importScripts)
// ============================================

let ml_kem768 = null
let cryptoLoadAttempted = false

function loadCrypto() {
  if (ml_kem768) return true
  if (cryptoLoadAttempted) return !!ml_kem768

  cryptoLoadAttempted = true
  try {
    // Load the bundled noble-post-quantum library
    importScripts("/sw-crypto.js")
    // The script should set self.noblePostQuantum
    if (self.noblePostQuantum?.ml_kem768) {
      ml_kem768 = self.noblePostQuantum.ml_kem768
      return true
    }
    return false
  } catch (error) {
    console.error("[SW] Failed to load crypto:", error)
    return false
  }
}

// ============================================
// Crypto Helpers
// ============================================

function base64ToBytes(base64) {
  const binary = atob(base64)
  const bytes = new Uint8Array(binary.length)
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i)
  }
  return bytes
}

async function decryptTransitBlob(encryptedBlob, transportPrivateKey) {
  if (!ml_kem768) {
    throw new Error("Crypto not loaded")
  }

  let envelope
  try {
    envelope = JSON.parse(encryptedBlob)
  } catch {
    throw new Error("Invalid transit envelope")
  }

  if (!envelope?.cipherText || !envelope.iv || !envelope.ciphertext) {
    throw new Error("Invalid transit envelope")
  }

  // ML-KEM-768 decapsulation to get shared secret
  const sharedSecret = ml_kem768.decapsulate(
    base64ToBytes(envelope.cipherText),
    transportPrivateKey
  )

  // Copy shared secret to a clean ArrayBuffer (avoid buffer view issues)
  const sharedSecretCopy = new Uint8Array(sharedSecret.length)
  sharedSecretCopy.set(sharedSecret)

  // Import shared secret as AES-GCM key
  const aesKey = await crypto.subtle.importKey(
    "raw",
    sharedSecretCopy.buffer,
    "AES-GCM",
    false,
    ["decrypt"]
  )

  // Decrypt the payload
  const decrypted = await crypto.subtle.decrypt(
    { name: "AES-GCM", iv: base64ToBytes(envelope.iv) },
    aesKey,
    base64ToBytes(envelope.ciphertext)
  )

  return new Uint8Array(decrypted)
}

// ============================================
// IndexedDB Helpers
// ============================================

function openDatabase() {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(DB_NAME)
    request.onerror = () => reject(request.error)
    request.onsuccess = () => resolve(request.result)
  })
}

async function getFromStore(storeName, key) {
  try {
    const db = await openDatabase()
    return new Promise((resolve, reject) => {
      const tx = db.transaction(storeName, "readonly")
      const store = tx.objectStore(storeName)
      const request = store.get(key)
      request.onerror = () => reject(request.error)
      request.onsuccess = () => resolve(request.result)
    })
  } catch (error) {
    console.error("[SW] IndexedDB error:", error)
    return null
  }
}

async function getNotificationSettings() {
  const defaults = {
    pushNotificationsEnabled: true,
    pushShowContent: true,
    pushShowSenderName: true,
    sessionNotificationsEnabled: true,
  }
  try {
    const record = await getFromStore("syncState", "notificationSettings")
    return { ...defaults, ...(record?.value || {}) }
  } catch {
    return defaults
  }
}

/**
 * Check if a conversation is muted
 * Returns true if muted, false otherwise
 */
async function isConversationMuted(senderHandle) {
  if (!senderHandle) return false

  try {
    const normalizedHandle = senderHandle.toLowerCase().trim()
    const db = await openDatabase()

    return new Promise((resolve) => {
      try {
        const tx = db.transaction("mutedConversations", "readonly")
        const store = tx.objectStore("mutedConversations")
        const request = store.get(normalizedHandle)

        request.onerror = () => resolve(false)
        request.onsuccess = () => {
          const record = request.result
          if (!record) {
            resolve(false)
            return
          }

          // Check if mute has expired
          if (record.mutedUntil === null) {
            resolve(true) // Forever muted
            return
          }

          if (record.mutedUntil > Date.now()) {
            resolve(true) // Still active
            return
          }

          // Mute expired
          resolve(false)
        }
      } catch {
        resolve(false)
      }
    })
  } catch {
    return false
  }
}

async function getTransportPrivateKey() {
  try {
    const record = await getFromStore("syncState", "transportPrivateKeyForSW")
    if (!record?.value) return null
    // Key is stored as base64 string
    return base64ToBytes(record.value)
  } catch (error) {
    console.error("[SW] Failed to get transport key:", error)
    return null
  }
}

// ============================================
// Service Worker Lifecycle
// ============================================

self.addEventListener("install", (event) => {
  loadCrypto()
  self.skipWaiting()
})

self.addEventListener("activate", (event) => {
  event.waitUntil(clients.claim())
})

// ============================================
// Push Notification Handler
// ============================================

self.addEventListener("push", (event) => {
  if (!event.data) return
  event.waitUntil(handlePushEvent(event))
})

async function handlePushEvent(event) {
  let envelope
  try {
    envelope = event.data.json()
  } catch (error) {
    console.error("[SW] Failed to parse push data:", error)
    return showFallbackNotification()
  }

  const settings = await getNotificationSettings()

  // Check 1: Global notifications disabled
  if (!settings.pushNotificationsEnabled) {
    return
  }

  // Check 2: Session/device notifications disabled
  if (!settings.sessionNotificationsEnabled) {
    return
  }

  // Check 3: Conversation is muted
  const senderHandle = envelope.sender_handle
  if (senderHandle && await isConversationMuted(senderHandle)) {
    return
  }

  let decryptedPayload = null

  // First, check if there's an open window to handle decryption
  const windowClients = await clients.matchAll({
    type: "window",
    includeUncontrolled: true,
  })

  if (windowClients.length > 0 && settings.pushShowContent) {
    try {
      const channel = new MessageChannel()

      const decryptPromise = new Promise((resolve) => {
        const timeout = setTimeout(() => resolve(null), 3000)

        channel.port1.onmessage = (event) => {
          clearTimeout(timeout)
          resolve(event.data)
        }
      })

      windowClients[0].postMessage(
        {
          type: "DECRYPT_PUSH_NOTIFICATION",
          encrypted_preview: envelope.encrypted_preview,
          sender_handle: envelope.sender_handle,
        },
        [channel.port2]
      )

      decryptedPayload = await decryptPromise
    } catch (error) {
      console.error("[SW] Failed to forward to app:", error)
    }
  }

  // If no window or window decryption failed, try to decrypt directly
  if (!decryptedPayload && settings.pushShowContent && envelope.encrypted_preview) {
    try {
      loadCrypto()
      const transportKey = await getTransportPrivateKey()

      if (transportKey) {
        const decryptedBytes = await decryptTransitBlob(
          envelope.encrypted_preview,
          transportKey
        )
        const decryptedText = new TextDecoder().decode(decryptedBytes)
        decryptedPayload = JSON.parse(decryptedText)
      }
    } catch (error) {
      console.error("[SW] Direct decryption failed:", error.message)
    }
  }

  // Build notification
  let title, body, data, icon

  if (decryptedPayload && settings.pushShowContent) {
    title = settings.pushShowSenderName
      ? decryptedPayload.sender_display_name || decryptedPayload.sender_handle
      : "New message"
    body = decryptedPayload.preview || "Sent you a message"
    data = {
      url: `/?chat=${encodeURIComponent(decryptedPayload.sender_handle)}`,
      sender_handle: decryptedPayload.sender_handle,
      message_id: decryptedPayload.message_id,
    }
    // Use sender's avatar if available
    icon = decryptedPayload.sender_avatar_url || "/icons/icon-192.png"
  } else if (settings.pushShowSenderName && envelope.sender_handle) {
    title = envelope.sender_handle
    body = "Sent you a message"
    data = {
      url: `/?chat=${encodeURIComponent(envelope.sender_handle)}`,
      sender_handle: envelope.sender_handle,
    }
    icon = "/icons/icon-192.png"
  } else {
    title = "Ratchet Chat"
    body = "New message"
    data = { url: "/" }
    icon = "/icons/icon-192.png"
  }

  return self.registration.showNotification(title, {
    body,
    icon,
    badge: "/icons/badge-72.png",
    tag: `msg-${Date.now()}`,
    data,
    requireInteraction: false,
    silent: false,
  })
}

async function showFallbackNotification() {
  return self.registration.showNotification("Ratchet Chat", {
    body: "New notification",
    icon: "/icons/icon-192.png",
    tag: `fallback-${Date.now()}`,
    data: { url: "/" },
  })
}

// ============================================
// Notification Click Handler
// ============================================

self.addEventListener("notificationclick", (event) => {
  event.notification.close()

  const url = event.notification.data?.url || "/"

  event.waitUntil(
    clients
      .matchAll({ type: "window", includeUncontrolled: true })
      .then((windowClients) => {
        for (const client of windowClients) {
          if (client.url.includes(self.location.origin) && "focus" in client) {
            client.focus()
            client.postMessage({
              type: "NOTIFICATION_CLICK",
              data: event.notification.data,
            })
            return
          }
        }

        if (clients.openWindow) {
          return clients.openWindow(url)
        }
      })
  )
})

// ============================================
// Message Handler
// ============================================

self.addEventListener("message", (event) => {
  if (event.data?.type === "SKIP_WAITING") {
    self.skipWaiting()
  }
})
