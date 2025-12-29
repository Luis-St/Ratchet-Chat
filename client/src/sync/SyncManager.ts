import type { Socket } from "socket.io-client"
import type {
  SyncEventType,
  SyncEventMap,
  SyncHandler,
  SyncContext,
  SyncEventCallback,
  ISyncManager,
  SyncEvent,
  IncomingMessageEvent,
  OutgoingMessageSyncedEvent,
  IncomingMessageSyncedEvent,
  VaultMessageUpdatedEvent,
  SessionDeletedEvent,
  PasskeyAddedEvent,
  PasskeyRemovedEvent,
} from "./types"
import { SYNC_EVENT_TYPES } from "./types"
import { DeduplicationService } from "./deduplication"
import { validateSyncEvent } from "./validation"

export class SyncManager implements ISyncManager {
  private socket: Socket | null = null
  private handlers: Map<SyncEventType, SyncHandler<SyncEventType>[]> = new Map()
  private subscribers: Map<SyncEventType, Set<SyncEventCallback<SyncEventType>>> =
    new Map()
  private context: SyncContext
  private deduplicator: DeduplicationService
  private boundEventHandlers: Map<string, (payload: unknown) => void> =
    new Map()
  private isConnected = false
  private hasLoggedConnect = false

  constructor(initialContext: Partial<SyncContext> = {}) {
    this.deduplicator = new DeduplicationService({
      maxSize: 1000,
      ttlMs: 5 * 60 * 1000, // 5 minutes
    })

    this.context = {
      userId: null,
      userHandle: null,
      sessionId: null,
      masterKey: null,
      transportPrivateKey: null,
      identityPrivateKey: null,
      publicIdentityKey: null,
      isBlocked: () => false,
      ...initialContext,
    }
  }

  // Register a handler for specific event types
  registerHandler<T extends SyncEventType>(handler: SyncHandler<T>): void {
    for (const eventType of handler.eventTypes) {
      const handlers = this.handlers.get(eventType) || []
      handlers.push(handler as SyncHandler<SyncEventType>)
      this.handlers.set(eventType, handlers)
    }
  }

  // Subscribe to events (for components that need to react)
  subscribe<T extends SyncEventType>(
    eventType: T,
    callback: SyncEventCallback<T>
  ): () => void {
    const subs =
      this.subscribers.get(eventType) ||
      new Set<SyncEventCallback<SyncEventType>>()
    subs.add(callback as SyncEventCallback<SyncEventType>)
    this.subscribers.set(eventType, subs)
    console.log(`[SyncManager] Subscribed to ${eventType}, now ${subs.size} subscribers`)

    return () => {
      subs.delete(callback as SyncEventCallback<SyncEventType>)
      console.log(`[SyncManager] Unsubscribed from ${eventType}, now ${subs.size} subscribers`)
    }
  }

  // Update context (when auth state changes, etc.)
  updateContext(updates: Partial<SyncContext>): void {
    this.context = { ...this.context, ...updates }
  }

  // Get current context (for handlers that need it)
  getContext(): SyncContext {
    return this.context
  }

  // Connect to socket
  connect(socket: Socket): void {
    if (this.socket === socket && this.isConnected) {
      console.log("[SyncManager] Already connected to this socket")
      return
    }

    this.disconnect()
    this.socket = socket

    // Register listeners for all known event types
    for (const eventType of SYNC_EVENT_TYPES) {
      const handler = (payload: unknown) => {
        void this.processEvent(eventType, payload)
      }
      this.boundEventHandlers.set(eventType, handler)
      socket.on(eventType, handler)
    }

    this.isConnected = true
    if (!this.hasLoggedConnect) {
      this.hasLoggedConnect = true
      console.log(
        `[SyncManager] Connected, listening for ${SYNC_EVENT_TYPES.length} event types:`,
        SYNC_EVENT_TYPES
      )
    }
  }

  // Disconnect from socket
  disconnect(): void {
    if (this.socket) {
      for (const [eventType, handler] of this.boundEventHandlers) {
        this.socket.off(eventType, handler)
      }
      this.boundEventHandlers.clear()
      this.socket = null
      this.isConnected = false
    }
  }

  // Core event processing
  private async processEvent(
    eventType: SyncEventType,
    payload: unknown
  ): Promise<void> {
    console.log(`[SyncManager] Received ${eventType}`, payload)

    // Step 1: Validate payload
    const validatedEvent = validateSyncEvent(eventType, payload)
    if (!validatedEvent) {
      console.warn(`[SyncManager] Invalid payload for ${eventType}`, payload)
      return
    }

    // Step 2: Check deduplication
    const dedupeKey = this.getDedupeKey(eventType, validatedEvent)
    if (dedupeKey && this.deduplicator.isDuplicate(dedupeKey)) {
      console.debug(`[SyncManager] Duplicate event ignored: ${dedupeKey}`)
      return
    }
    if (dedupeKey) {
      this.deduplicator.markProcessed(dedupeKey)
    }

    // Step 3: Get handlers
    const handlers = this.handlers.get(eventType) || []
    console.log(`[SyncManager] Found ${handlers.length} handlers for ${eventType}`)

    // Step 4: Process through handlers
    for (const handler of handlers) {
      const shouldProcess = handler.shouldProcess(validatedEvent, this.context)
      console.log(`[SyncManager] Handler shouldProcess=${shouldProcess} for ${eventType}`, {
        hasUserId: !!this.context.userId,
        hasMasterKey: !!this.context.masterKey,
      })
      if (shouldProcess) {
        try {
          await handler.handle(validatedEvent, this.context)
          console.log(`[SyncManager] Successfully handled ${eventType}`)
        } catch (error) {
          console.error(`[SyncManager] Handler error for ${eventType}:`, error)
        }
      }
    }

    // Step 5: Notify subscribers
    const subscribers = this.subscribers.get(eventType)
    console.log(`[SyncManager] Notifying ${subscribers?.size ?? 0} subscribers for ${eventType}`)
    if (subscribers) {
      for (const callback of subscribers) {
        try {
          callback(validatedEvent)
        } catch (error) {
          console.error(
            `[SyncManager] Subscriber error for ${eventType}:`,
            error
          )
        }
      }
    }
  }

  // Generate deduplication key based on event type
  private getDedupeKey(
    eventType: SyncEventType,
    event: SyncEvent
  ): string | null {
    switch (eventType) {
      case "INCOMING_MESSAGE":
        return `msg:${(event as IncomingMessageEvent).id}`
      case "OUTGOING_MESSAGE_SYNCED":
        return `out:${(event as OutgoingMessageSyncedEvent).message_id}`
      case "INCOMING_MESSAGE_SYNCED":
        return `in:${(event as IncomingMessageSyncedEvent).id}`
      case "VAULT_MESSAGE_UPDATED": {
        const vaultEvent = event as VaultMessageUpdatedEvent
        return `vault:${vaultEvent.id}:${vaultEvent.version}`
      }
      case "TRANSPORT_KEY_ROTATED":
        // Always process key rotations (they're idempotent)
        return null
      case "BLOCK_LIST_UPDATED":
        // Always process (client-side state is authoritative)
        return null
      case "CONTACTS_UPDATED":
        // Always process (client-side state is authoritative)
        return null
      case "SETTINGS_UPDATED":
        // Always apply latest settings
        return null
      case "SESSION_INVALIDATED":
        // Always process session invalidation
        return null
      case "SESSION_DELETED":
        return `session:${(event as SessionDeletedEvent).sessionId}`
      case "PASSKEY_ADDED":
        return `passkey:add:${(event as PasskeyAddedEvent).credentialId}`
      case "PASSKEY_REMOVED":
        return `passkey:rm:${(event as PasskeyRemovedEvent).credentialId}`
      default:
        return null
    }
  }

  // Check if connected
  isSocketConnected(): boolean {
    return this.isConnected
  }

  // Get deduplicator for testing/debugging
  getDeduplicator(): DeduplicationService {
    return this.deduplicator
  }

  // Cleanup
  destroy(): void {
    this.disconnect()
    this.handlers.clear()
    this.subscribers.clear()
    this.deduplicator.clear()
  }
}

// Singleton instance for the app
let syncManagerInstance: SyncManager | null = null

export function getSyncManager(): SyncManager {
  if (!syncManagerInstance) {
    syncManagerInstance = new SyncManager()
  }
  return syncManagerInstance
}

export function destroySyncManager(): void {
  if (syncManagerInstance) {
    syncManagerInstance.destroy()
    syncManagerInstance = null
  }
}
