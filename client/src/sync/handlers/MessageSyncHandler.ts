import type {
  SyncHandler,
  SyncContext,
  SyncEventMap,
  IncomingMessageEvent,
  OutgoingMessageSyncedEvent,
  IncomingMessageSyncedEvent,
  VaultMessageUpdatedEvent,
} from "../types"
import { validateSyncEvent } from "../validation"
import { db } from "@/lib/db"

type MessageEventType =
  | "INCOMING_MESSAGE"
  | "OUTGOING_MESSAGE_SYNCED"
  | "INCOMING_MESSAGE_SYNCED"
  | "VAULT_MESSAGE_UPDATED"

// Callback for processing incoming queue items (delegates to useRatchetSync's processSingleQueueItem)
export type ProcessQueueItemFn = (item: {
  id: string
  recipient_id: string
  sender_handle: string
  encrypted_blob: string
  created_at: string
}) => Promise<void>

// Callback to trigger a full sync (fallback when partial payload isn't sufficient)
export type RunSyncFn = () => Promise<void>

// Callback to notify when a vault message is synced
export type OnVaultMessageSyncedFn = (
  messageId: string,
  action: "upsert" | "delete"
) => void

// Callback to bump the lastSync timestamp
export type BumpLastSyncFn = () => void

export class MessageSyncHandler implements SyncHandler<MessageEventType> {
  eventTypes: MessageEventType[] = [
    "INCOMING_MESSAGE",
    "OUTGOING_MESSAGE_SYNCED",
    "INCOMING_MESSAGE_SYNCED",
    "VAULT_MESSAGE_UPDATED",
  ]

  private processQueueItem: ProcessQueueItemFn
  private runSync: RunSyncFn
  private onVaultMessageSynced: OnVaultMessageSyncedFn | null
  private bumpLastSync: BumpLastSyncFn

  constructor(options: {
    processQueueItem: ProcessQueueItemFn
    runSync: RunSyncFn
    onVaultMessageSynced?: OnVaultMessageSyncedFn
    bumpLastSync: BumpLastSyncFn
  }) {
    this.processQueueItem = options.processQueueItem
    this.runSync = options.runSync
    this.onVaultMessageSynced = options.onVaultMessageSynced ?? null
    this.bumpLastSync = options.bumpLastSync
  }

  validate(
    eventType: MessageEventType,
    payload: unknown
  ): payload is SyncEventMap[MessageEventType] {
    return validateSyncEvent(eventType, payload) !== null
  }

  shouldProcess(
    event: SyncEventMap[MessageEventType],
    context: SyncContext
  ): boolean {
    // Need authentication for any message processing
    if (!context.userId || !context.masterKey) {
      return false
    }

    // For INCOMING_MESSAGE, need transport key for decryption
    if (event.type === "INCOMING_MESSAGE" && !context.transportPrivateKey) {
      return false
    }

    // Filter blocked users for incoming messages
    if (event.type === "INCOMING_MESSAGE") {
      const incomingEvent = event as IncomingMessageEvent
      if (
        incomingEvent.sender_handle &&
        context.isBlocked(incomingEvent.sender_handle)
      ) {
        return false
      }
    }

    // Filter blocked users for synced incoming messages
    if (event.type === "INCOMING_MESSAGE_SYNCED") {
      const syncedEvent = event as IncomingMessageSyncedEvent
      if (
        syncedEvent.original_sender_handle &&
        context.isBlocked(syncedEvent.original_sender_handle)
      ) {
        return false
      }
    }

    return true
  }

  async handle(
    event: SyncEventMap[MessageEventType],
    context: SyncContext
  ): Promise<void> {
    switch (event.type) {
      case "INCOMING_MESSAGE":
        await this.handleIncomingMessage(event as IncomingMessageEvent, context)
        break
      case "OUTGOING_MESSAGE_SYNCED":
        await this.handleOutgoingMessageSynced(
          event as OutgoingMessageSyncedEvent,
          context
        )
        break
      case "INCOMING_MESSAGE_SYNCED":
        await this.handleIncomingMessageSynced(
          event as IncomingMessageSyncedEvent,
          context
        )
        break
      case "VAULT_MESSAGE_UPDATED":
        await this.handleVaultMessageUpdated(
          event as VaultMessageUpdatedEvent,
          context
        )
        break
    }
  }

  private async handleIncomingMessage(
    event: IncomingMessageEvent,
    _context: SyncContext
  ): Promise<void> {
    // If the payload has the encrypted blob, process it directly
    if (event.encrypted_blob) {
      await this.processQueueItem({
        id: event.id,
        recipient_id: event.recipient_id,
        sender_handle: event.sender_handle,
        encrypted_blob: event.encrypted_blob,
        created_at: event.created_at,
      })
    } else {
      // Fallback for backward compatibility
      await this.runSync()
    }
  }

  private async handleOutgoingMessageSynced(
    event: OutgoingMessageSyncedEvent,
    context: SyncContext
  ): Promise<void> {
    // Check if message already exists locally
    const existing = await db.messages.get(event.message_id)
    if (existing) {
      this.bumpLastSync()
      this.onVaultMessageSynced?.(event.message_id, "upsert")
      return
    }

    // Store the outgoing message from another device
    const ownerId = event.owner_id ?? context.userId ?? context.userHandle ?? ""
    await db.messages.put({
      id: event.message_id,
      ownerId,
      senderId: event.original_sender_handle,
      peerHandle: event.original_sender_handle,
      content: JSON.stringify({
        encrypted_blob: event.encrypted_blob,
        iv: event.iv,
      }),
      verified: event.sender_signature_verified,
      isRead: true, // Our own messages are always read
      vaultSynced: true,
      createdAt: event.created_at,
    })

    this.bumpLastSync()
    this.onVaultMessageSynced?.(event.message_id, "upsert")
  }

  private async handleIncomingMessageSynced(
    event: IncomingMessageSyncedEvent,
    context: SyncContext
  ): Promise<void> {
    // Check if message already exists locally
    const existing = await db.messages.get(event.id)
    if (existing) {
      this.bumpLastSync()
      this.onVaultMessageSynced?.(event.id, "upsert")
      return
    }

    // Store the incoming message that was stored to vault by another device
    const ownerId = event.owner_id ?? context.userId ?? context.userHandle ?? ""
    await db.messages.put({
      id: event.id,
      ownerId,
      senderId: event.original_sender_handle,
      peerHandle: event.original_sender_handle,
      content: JSON.stringify({
        encrypted_blob: event.encrypted_blob,
        iv: event.iv,
      }),
      verified: event.sender_signature_verified,
      isRead: false,
      vaultSynced: true,
      createdAt: event.created_at,
    })

    this.bumpLastSync()
    this.onVaultMessageSynced?.(event.id, "upsert")
  }

  private async handleVaultMessageUpdated(
    event: VaultMessageUpdatedEvent,
    _context: SyncContext
  ): Promise<void> {
    if (event.deleted_at) {
      // Soft delete: remove from local DB
      await db.messages.delete(event.id)
      this.onVaultMessageSynced?.(event.id, "delete")
    } else {
      // Update content
      await db.messages.update(event.id, {
        content: JSON.stringify({
          encrypted_blob: event.encrypted_blob,
          iv: event.iv,
        }),
      })
      this.onVaultMessageSynced?.(event.id, "upsert")
    }

    this.bumpLastSync()
  }
}
