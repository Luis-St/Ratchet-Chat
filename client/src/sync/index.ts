// Core sync system
export { SyncManager, getSyncManager, destroySyncManager } from "./SyncManager"
export { DeduplicationService } from "./deduplication"
export { validateSyncEvent, isValidSyncEvent } from "./validation"

// Types
export type {
  SyncEvent,
  SyncEventType,
  SyncEventMap,
  SyncHandler,
  SyncContext,
  SyncEventCallback,
  ISyncManager,
  BaseSyncEvent,
  IncomingMessageEvent,
  OutgoingMessageSyncedEvent,
  IncomingMessageSyncedEvent,
  VaultMessageUpdatedEvent,
  BlockListUpdatedEvent,
  TransportKeyRotatedEvent,
  SettingsUpdatedEvent,
  SessionInvalidatedEvent,
  SessionDeletedEvent,
  PasskeyAddedEvent,
  PasskeyRemovedEvent,
} from "./types"
export { SYNC_EVENT_TYPES } from "./types"

// Handlers
export * from "./handlers"
