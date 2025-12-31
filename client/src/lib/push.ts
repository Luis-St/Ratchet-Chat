import { apiFetch } from "./api"
import { db } from "./db"
import {
  decryptTransitBlob,
  bytesToBase64,
  encryptTransitEnvelope,
} from "./crypto"

export interface NotificationSettings {
  pushNotificationsEnabled: boolean
  pushShowContent: boolean
  pushShowSenderName: boolean
  sessionNotificationsEnabled: boolean  // Per-device toggle (local only)
}

export const DEFAULT_NOTIFICATION_SETTINGS: NotificationSettings = {
  pushNotificationsEnabled: true,
  pushShowContent: true,
  pushShowSenderName: true,
  sessionNotificationsEnabled: true,
}

export interface PushPreviewPayload {
  type: "message" | "reaction" | "call" | "mention"
  sender_handle: string
  sender_display_name?: string
  sender_avatar_url?: string
  preview: string
  message_id?: string
  timestamp: string
}

function isNetworkError(error: unknown): boolean {
  return (
    error instanceof TypeError ||
    (error instanceof Error && /failed to fetch/i.test(error.message))
  )
}

function logPushError(message: string, error: unknown) {
  if (isNetworkError(error)) {
    console.warn(message, error)
    return
  }
  console.error(message, error)
}

// ============================================
// Push Preview Encryption
// ============================================

/**
 * Create an encrypted push preview for E2EE notifications
 * The preview is encrypted with the recipient's transport key
 * Note: No signature included to stay within ~4KB web push payload limit
 * (ML-DSA-65 signatures are ~4.4KB alone)
 */
export async function createEncryptedPushPreview(
  payload: Omit<PushPreviewPayload, "timestamp">,
  recipientPublicTransportKey: string
): Promise<string> {
  const fullPayload: PushPreviewPayload = {
    ...payload,
    timestamp: new Date().toISOString(),
  }

  // Encrypt with recipient's transport key (ML-KEM-768 + AES-GCM)
  return encryptTransitEnvelope(
    JSON.stringify(fullPayload),
    recipientPublicTransportKey
  )
}

// ============================================
// Service Worker Registration
// ============================================

let swRegistration: ServiceWorkerRegistration | null = null

export async function registerServiceWorker(): Promise<ServiceWorkerRegistration | null> {
  if (typeof window === "undefined") return null
  if (!("serviceWorker" in navigator)) {
    console.log("[Push] Service workers not supported")
    return null
  }
  if (!("PushManager" in window)) {
    console.log("[Push] Push notifications not supported")
    return null
  }

  try {
    const registration = await navigator.serviceWorker.register("/sw.js", {
      scope: "/",
    })

    // Wait for the service worker to be ready
    await navigator.serviceWorker.ready

    swRegistration = registration
    console.log("[Push] Service worker registered")
    return registration
  } catch (error) {
    console.error("[Push] Service worker registration failed:", error)
    return null
  }
}

export function getServiceWorkerRegistration(): ServiceWorkerRegistration | null {
  return swRegistration
}

/**
 * Unregister all service workers
 * Call this on full logout to clean up
 */
export async function unregisterServiceWorker(): Promise<void> {
  if (typeof window === "undefined") return

  try {
    const registrations = await navigator.serviceWorker?.getRegistrations()
    if (!registrations) return

    for (const registration of registrations) {
      await registration.unregister()
    }
    swRegistration = null
    console.log("[Push] Service worker unregistered")
  } catch (error) {
    console.error("[Push] Failed to unregister service worker:", error)
  }
}

// ============================================
// Push Subscription Management
// ============================================

export async function getVapidPublicKey(): Promise<string | null> {
  try {
    const response = await apiFetch<{ vapidPublicKey: string }>("/auth/push/vapid-key")
    return response.vapidPublicKey
  } catch (error) {
    logPushError("[Push] Failed to get VAPID key:", error)
    return null
  }
}

function urlBase64ToUint8Array(base64String: string): Uint8Array {
  const padding = "=".repeat((4 - (base64String.length % 4)) % 4)
  const base64 = (base64String + padding).replace(/-/g, "+").replace(/_/g, "/")
  const rawData = window.atob(base64)
  const outputArray = new Uint8Array(rawData.length)
  for (let i = 0; i < rawData.length; ++i) {
    outputArray[i] = rawData.charCodeAt(i)
  }
  return outputArray
}

export async function subscribeToPush(): Promise<boolean> {
  const registration = swRegistration || (await registerServiceWorker())
  if (!registration) return false

  try {
    // Check permission
    const permission = await Notification.requestPermission()
    if (permission !== "granted") {
      console.log("[Push] Notification permission denied")
      return false
    }

    // Get VAPID key from server
    const vapidPublicKey = await getVapidPublicKey()
    if (!vapidPublicKey) {
      console.warn("[Push] No VAPID public key available")
      return false
    }

    // Check for existing subscription
    let subscription = await registration.pushManager.getSubscription()

    // Subscribe if not already subscribed
    if (!subscription) {
      const serverKey = urlBase64ToUint8Array(vapidPublicKey)
      subscription = await registration.pushManager.subscribe({
        userVisibleOnly: true,
        // TypeScript strict typing requires cast - Uint8Array is valid BufferSource
        applicationServerKey: serverKey as unknown as ArrayBuffer,
      })
    }

    // Register subscription with server
    const subscriptionJson = subscription.toJSON()
    const keys = subscriptionJson.keys
    if (!keys?.p256dh || !keys?.auth) {
      throw new Error("Missing push subscription keys")
    }

    await apiFetch("/auth/push/subscribe", {
      method: "POST",
      body: {
        endpoint: subscriptionJson.endpoint,
        keys: {
          p256dh: keys.p256dh,
          auth: keys.auth,
        },
      },
    })

    console.log("[Push] Successfully subscribed to push notifications")
    return true
  } catch (error) {
    logPushError("[Push] Failed to subscribe:", error)
    return false
  }
}

export async function unsubscribeFromPush(): Promise<boolean> {
  const registration = swRegistration || (await navigator.serviceWorker?.ready)
  if (!registration) return false

  try {
    const subscription = await registration.pushManager.getSubscription()
    if (subscription) {
      await subscription.unsubscribe()
    }

    // Notify server
    await apiFetch("/auth/push/subscribe", {
      method: "DELETE",
    })

    console.log("[Push] Unsubscribed from push notifications")
    return true
  } catch (error) {
    logPushError("[Push] Failed to unsubscribe:", error)
    return false
  }
}

export async function isPushSubscribed(): Promise<boolean> {
  const registration = swRegistration || (await navigator.serviceWorker?.ready)
  if (!registration) return false

  try {
    const subscription = await registration.pushManager.getSubscription()
    return subscription !== null
  } catch {
    return false
  }
}

// ============================================
// IndexedDB Storage for Service Worker
// ============================================

/**
 * Store transport private key in IndexedDB for service worker access
 */
export async function storeTransportKeyForSW(
  transportPrivateKey: Uint8Array
): Promise<void> {
  try {
    await db.syncState.put({
      key: "transportPrivateKeyForSW",
      value: bytesToBase64(transportPrivateKey),
    })
    console.log("[Push] Transport key stored for service worker")
  } catch (error) {
    console.error("[Push] Failed to store transport key:", error)
  }
}

/**
 * Clear transport private key from IndexedDB
 * Call this on lock/logout
 */
export async function clearTransportKeyForSW(): Promise<void> {
  try {
    await db.syncState.delete("transportPrivateKeyForSW")
    console.log("[Push] Transport key cleared from service worker storage")
  } catch (error) {
    console.error("[Push] Failed to clear transport key:", error)
  }
}

/**
 * Store notification settings in IndexedDB for service worker access
 * Preserves the sessionNotificationsEnabled toggle (device-specific)
 */
export async function storeNotificationSettings(
  settings: Omit<NotificationSettings, "sessionNotificationsEnabled">
): Promise<void> {
  try {
    // Get current session setting to preserve it
    const currentRecord = await db.syncState.get("notificationSettings")
    const currentSettings = currentRecord?.value as NotificationSettings | undefined

    const merged: NotificationSettings = {
      ...settings,
      sessionNotificationsEnabled: currentSettings?.sessionNotificationsEnabled ?? true,
    }

    await db.syncState.put({
      key: "notificationSettings",
      value: merged,
    })
  } catch (error) {
    console.error("[Push] Failed to store notification settings:", error)
  }
}

/**
 * Get notification settings from IndexedDB
 */
export async function getNotificationSettings(): Promise<NotificationSettings> {
  try {
    const record = await db.syncState.get("notificationSettings")
    return (record?.value as NotificationSettings) || DEFAULT_NOTIFICATION_SETTINGS
  } catch {
    return DEFAULT_NOTIFICATION_SETTINGS
  }
}

/**
 * Set per-session notifications enabled/disabled
 * This is device-specific and never syncs to server
 */
export async function setSessionNotificationsEnabled(enabled: boolean): Promise<void> {
  try {
    const record = await db.syncState.get("notificationSettings")
    const current = (record?.value as NotificationSettings) || DEFAULT_NOTIFICATION_SETTINGS

    await db.syncState.put({
      key: "notificationSettings",
      value: { ...current, sessionNotificationsEnabled: enabled },
    })
    console.log("[Push] Session notifications:", enabled ? "enabled" : "disabled")
  } catch (error) {
    console.error("[Push] Failed to set session notifications:", error)
  }
}

/**
 * Get per-session notifications enabled state
 */
export async function getSessionNotificationsEnabled(): Promise<boolean> {
  try {
    const record = await db.syncState.get("notificationSettings")
    const settings = record?.value as NotificationSettings | undefined
    return settings?.sessionNotificationsEnabled ?? true
  } catch {
    return true
  }
}

// ============================================
// Service Worker Communication
// ============================================

/**
 * Set up message listener for service worker communication
 * Must be called with the transport private key when authenticated
 */
export function setupPushDecryptionHandler(
  transportPrivateKey: Uint8Array | null
): () => void {
  if (typeof window === "undefined") return () => {}

  console.log("[Push] Setting up decryption handler, has key:", !!transportPrivateKey)

  const handler = async (event: MessageEvent) => {
    const messageType = event.data?.type
    console.log("[Push] Received SW message:", messageType)

    if (messageType !== "DECRYPT_PUSH_NOTIFICATION") return

    if (!event.ports?.[0]) {
      console.log("[Push] No message port in event")
      return
    }

    const port = event.ports[0]
    const encryptedPreview = event.data.encrypted_preview as string

    if (!transportPrivateKey) {
      console.log("[Push] No transport key available, returning null")
      port.postMessage(null)
      return
    }

    try {
      console.log("[Push] Attempting decryption...")
      // encryptedPreview is a TransitEnvelope JSON string
      const decryptedBytes = await decryptTransitBlob(
        encryptedPreview,
        transportPrivateKey
      )
      const decryptedText = new TextDecoder().decode(decryptedBytes)
      const decrypted = JSON.parse(decryptedText) as PushPreviewPayload
      console.log("[Push] Decryption successful:", decrypted.preview?.slice(0, 50))
      port.postMessage(decrypted)
    } catch (error) {
      console.error("[Push] Decryption handler error:", error)
      port.postMessage(null)
    }
  }

  navigator.serviceWorker?.addEventListener("message", handler)

  return () => {
    navigator.serviceWorker?.removeEventListener("message", handler)
  }
}

/**
 * Set up notification click handler
 * Navigates to the chat when notification is clicked
 */
export function setupNotificationClickHandler(
  navigate: (path: string) => void
): () => void {
  if (typeof window === "undefined") return () => {}

  const handler = (event: MessageEvent) => {
    if (event.data?.type !== "NOTIFICATION_CLICK") return

    const data = event.data.data
    if (data?.url) {
      navigate(data.url)
    }
  }

  navigator.serviceWorker?.addEventListener("message", handler)

  return () => {
    navigator.serviceWorker?.removeEventListener("message", handler)
  }
}

// ============================================
// Test Notification
// ============================================

export async function sendTestNotification(): Promise<boolean> {
  try {
    await apiFetch("/auth/push/test", { method: "POST" })
    return true
  } catch (error) {
    console.error("[Push] Failed to send test notification:", error)
    return false
  }
}
