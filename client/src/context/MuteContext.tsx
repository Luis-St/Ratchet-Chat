"use client"

import * as React from "react"
import { db, type MutedConversationRecord } from "@/lib/db"
import { encryptString, decryptString, type EncryptedPayload } from "@/lib/crypto"
import { apiFetch } from "@/lib/api"
import { useAuth } from "./AuthContext"
import {
  type MuteDuration,
  syncMutedConversationsToLocal,
  getMutedConversationsForSync,
  clearMutedConversationsLocal,
} from "@/lib/mute"

type MuteEntry = {
  handle: string
  mutedUntil: number | null
  mutedAt: number
}

type MuteList = MuteEntry[]

type MuteContextValue = {
  mutedConversations: Map<string, { mutedUntil: number | null; mutedAt: number }>
  isMuted: (handle: string) => boolean
  getMuteInfo: (handle: string) => { mutedUntil: number | null; mutedAt: number } | null
  muteConversation: (handle: string, duration: MuteDuration) => Promise<void>
  unmuteConversation: (handle: string) => Promise<void>
  isLoading: boolean
  applyEncryptedMuteList: (encrypted: EncryptedPayload | null) => Promise<void>
}

const MUTE_LIST_KEY = "encryptedMutedConversations"

const MUTE_DURATIONS: Record<MuteDuration, number | null> = {
  "1h": 60 * 60 * 1000,
  "8h": 8 * 60 * 60 * 1000,
  "24h": 24 * 60 * 60 * 1000,
  "1w": 7 * 24 * 60 * 60 * 1000,
  forever: null,
}

const MuteContext = React.createContext<MuteContextValue | undefined>(undefined)

export function MuteProvider({ children }: { children: React.ReactNode }) {
  const { status, masterKey } = useAuth()
  const [mutedConversations, setMutedConversations] = React.useState<
    Map<string, { mutedUntil: number | null; mutedAt: number }>
  >(new Map())
  const [isLoading, setIsLoading] = React.useState(true)

  const applyEncryptedMuteList = React.useCallback(
    async (encrypted: EncryptedPayload | null) => {
      if (!encrypted) {
        setMutedConversations(new Map())
        await db.syncState.delete(MUTE_LIST_KEY)
        await clearMutedConversationsLocal()
        return
      }

      await db.syncState.put({ key: MUTE_LIST_KEY, value: encrypted })

      if (!masterKey) {
        return
      }

      try {
        const decrypted = await decryptString(masterKey, encrypted)
        const muteList = JSON.parse(decrypted) as MuteList

        // Filter out expired mutes
        const now = Date.now()
        const validMutes = muteList.filter(
          (entry) => entry.mutedUntil === null || entry.mutedUntil > now
        )

        // Update React state
        const muteMap = new Map<string, { mutedUntil: number | null; mutedAt: number }>()
        for (const entry of validMutes) {
          muteMap.set(entry.handle.toLowerCase(), {
            mutedUntil: entry.mutedUntil,
            mutedAt: entry.mutedAt,
          })
        }
        setMutedConversations(muteMap)

        // Sync to local IndexedDB for service worker access
        await syncMutedConversationsToLocal(validMutes)
      } catch (error) {
        console.error("Failed to decrypt mute list:", error)
      }
    },
    [masterKey]
  )

  // Load mute list: try server first, fall back to local cache
  React.useEffect(() => {
    if (status !== "authenticated" || !masterKey) {
      setMutedConversations(new Map())
      setIsLoading(false)
      return
    }

    let active = true
    setIsLoading(true)

    async function loadMuteList() {
      try {
        // Try to load from server first
        const serverData = await apiFetch<{ ciphertext: string | null; iv: string | null }>(
          "/auth/muted-conversations"
        ).catch(() => null)

        let encrypted: EncryptedPayload | null = null

        if (serverData?.ciphertext && serverData?.iv) {
          encrypted = { ciphertext: serverData.ciphertext, iv: serverData.iv }
        } else {
          const record = await db.syncState.get(MUTE_LIST_KEY)
          if (record?.value) {
            encrypted = record.value as EncryptedPayload
          }
        }

        await applyEncryptedMuteList(encrypted)
      } catch (error) {
        console.error("Failed to load mute list:", error)
      } finally {
        if (active) {
          setIsLoading(false)
        }
      }
    }

    void loadMuteList()
    return () => {
      active = false
    }
  }, [status, masterKey, applyEncryptedMuteList])

  // Save encrypted mute list to both local and server
  const saveMuteList = React.useCallback(
    async (mutes: Map<string, { mutedUntil: number | null; mutedAt: number }>) => {
      if (!masterKey) return

      // Convert Map to array for JSON serialization
      const muteList: MuteList = Array.from(mutes.entries()).map(([handle, info]) => ({
        handle,
        mutedUntil: info.mutedUntil,
        mutedAt: info.mutedAt,
      }))

      const encrypted = await encryptString(masterKey, JSON.stringify(muteList))

      // Save to local encrypted cache
      await db.syncState.put({
        key: MUTE_LIST_KEY,
        value: encrypted,
      })

      // Sync unencrypted to local IndexedDB for service worker
      await syncMutedConversationsToLocal(muteList)

      // Sync to server (fire and forget, don't block UI)
      apiFetch("/auth/muted-conversations", {
        method: "PUT",
        body: encrypted,
      }).catch((error) => {
        console.error("Failed to sync mute list to server:", error)
      })
    },
    [masterKey]
  )

  const isMuted = React.useCallback(
    (handle: string): boolean => {
      const normalizedHandle = handle.toLowerCase()
      const info = mutedConversations.get(normalizedHandle)
      if (!info) return false

      // Check if expired
      if (info.mutedUntil !== null && info.mutedUntil <= Date.now()) {
        return false
      }

      return true
    },
    [mutedConversations]
  )

  const getMuteInfo = React.useCallback(
    (handle: string): { mutedUntil: number | null; mutedAt: number } | null => {
      const normalizedHandle = handle.toLowerCase()
      const info = mutedConversations.get(normalizedHandle)
      if (!info) return null

      // Check if expired
      if (info.mutedUntil !== null && info.mutedUntil <= Date.now()) {
        return null
      }

      return info
    },
    [mutedConversations]
  )

  const muteConversation = React.useCallback(
    async (handle: string, duration: MuteDuration) => {
      const normalizedHandle = handle.toLowerCase()
      const now = Date.now()
      const durationMs = MUTE_DURATIONS[duration]

      const newMutes = new Map(mutedConversations)
      newMutes.set(normalizedHandle, {
        mutedUntil: durationMs === null ? null : now + durationMs,
        mutedAt: now,
      })

      setMutedConversations(newMutes)
      await saveMuteList(newMutes)
    },
    [mutedConversations, saveMuteList]
  )

  const unmuteConversation = React.useCallback(
    async (handle: string) => {
      const normalizedHandle = handle.toLowerCase()
      const newMutes = new Map(mutedConversations)
      newMutes.delete(normalizedHandle)

      setMutedConversations(newMutes)
      await saveMuteList(newMutes)
    },
    [mutedConversations, saveMuteList]
  )

  const value = React.useMemo(
    (): MuteContextValue => ({
      mutedConversations,
      isMuted,
      getMuteInfo,
      muteConversation,
      unmuteConversation,
      isLoading,
      applyEncryptedMuteList,
    }),
    [
      mutedConversations,
      isMuted,
      getMuteInfo,
      muteConversation,
      unmuteConversation,
      isLoading,
      applyEncryptedMuteList,
    ]
  )

  return <MuteContext.Provider value={value}>{children}</MuteContext.Provider>
}

export function useMute(): MuteContextValue {
  const context = React.useContext(MuteContext)
  if (!context) {
    throw new Error("useMute must be used within MuteProvider")
  }
  return context
}
