import { db, type MutedConversationRecord } from "./db"

export type MuteDuration = "1h" | "8h" | "24h" | "1w" | "forever"

const MUTE_DURATIONS: Record<MuteDuration, number | null> = {
  "1h": 60 * 60 * 1000,
  "8h": 8 * 60 * 60 * 1000,
  "24h": 24 * 60 * 60 * 1000,
  "1w": 7 * 24 * 60 * 60 * 1000,
  forever: null,
}

export function getMuteDurationLabel(duration: MuteDuration): string {
  const labels: Record<MuteDuration, string> = {
    "1h": "1 hour",
    "8h": "8 hours",
    "24h": "24 hours",
    "1w": "1 week",
    forever: "Forever",
  }
  return labels[duration]
}

/**
 * Mute a conversation locally (for service worker access)
 */
export async function muteConversationLocal(
  handle: string,
  duration: MuteDuration
): Promise<void> {
  const normalizedHandle = handle.toLowerCase().trim()
  const now = Date.now()
  const durationMs = MUTE_DURATIONS[duration]

  await db.mutedConversations.put({
    handle: normalizedHandle,
    mutedUntil: durationMs === null ? null : now + durationMs,
    mutedAt: now,
  })
}

/**
 * Unmute a conversation locally
 */
export async function unmuteConversationLocal(handle: string): Promise<void> {
  const normalizedHandle = handle.toLowerCase().trim()
  await db.mutedConversations.delete(normalizedHandle)
}

/**
 * Get the mute status of a specific conversation
 */
export async function getConversationMuteStatus(handle: string): Promise<{
  isMuted: boolean
  mutedUntil: number | null
} | null> {
  const normalizedHandle = handle.toLowerCase().trim()
  const record = await db.mutedConversations.get(normalizedHandle)

  if (!record) return null

  // Check if mute has expired
  if (record.mutedUntil !== null && record.mutedUntil <= Date.now()) {
    // Clean up expired mute
    await db.mutedConversations.delete(normalizedHandle)
    return null
  }

  return {
    isMuted: true,
    mutedUntil: record.mutedUntil,
  }
}

/**
 * Get all muted conversations (cleaning up expired ones)
 */
export async function getMutedConversationsLocal(): Promise<
  Map<string, number | null>
> {
  const records = await db.mutedConversations.toArray()
  const now = Date.now()
  const result = new Map<string, number | null>()

  for (const record of records) {
    // Skip and clean up expired mutes
    if (record.mutedUntil !== null && record.mutedUntil <= now) {
      void db.mutedConversations.delete(record.handle)
      continue
    }
    result.set(record.handle, record.mutedUntil)
  }

  return result
}

/**
 * Format mute expiry for display
 */
export function formatMuteExpiry(mutedUntil: number | null): string {
  if (mutedUntil === null) return "Forever"

  const now = Date.now()
  const remaining = mutedUntil - now

  if (remaining <= 0) return "Expired"

  const hours = Math.floor(remaining / (60 * 60 * 1000))
  const days = Math.floor(hours / 24)

  if (days > 0) return `${days}d remaining`
  if (hours > 0) return `${hours}h remaining`
  return "< 1h remaining"
}

/**
 * Sync muted conversations from encrypted server data to local IndexedDB
 * Called by MuteContext after decrypting server data
 */
export async function syncMutedConversationsToLocal(
  mutes: Array<{ handle: string; mutedUntil: number | null; mutedAt: number }>
): Promise<void> {
  // Clear existing local mutes and replace with synced data
  await db.mutedConversations.clear()

  if (mutes.length > 0) {
    await db.mutedConversations.bulkPut(
      mutes.map((m) => ({
        handle: m.handle.toLowerCase().trim(),
        mutedUntil: m.mutedUntil,
        mutedAt: m.mutedAt,
      }))
    )
  }
}

/**
 * Get all muted conversations as array (for encryption/sync)
 */
export async function getMutedConversationsForSync(): Promise<
  MutedConversationRecord[]
> {
  const records = await db.mutedConversations.toArray()
  const now = Date.now()

  // Filter out expired mutes before syncing
  return records.filter(
    (r) => r.mutedUntil === null || r.mutedUntil > now
  )
}

/**
 * Clear all muted conversations (for logout)
 */
export async function clearMutedConversationsLocal(): Promise<void> {
  await db.mutedConversations.clear()
}
