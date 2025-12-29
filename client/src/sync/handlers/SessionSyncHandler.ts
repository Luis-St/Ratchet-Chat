import type {
  SyncHandler,
  SyncContext,
  SyncEventMap,
  SessionInvalidatedEvent,
  SessionDeletedEvent,
} from "../types"
import { validateSyncEvent } from "../validation"

type SessionEventType = "SESSION_INVALIDATED" | "SESSION_DELETED"

export type SessionInvalidatedFn = (reason?: string) => void
export type SessionDeletedFn = (sessionId: string) => void

export class SessionSyncHandler implements SyncHandler<SessionEventType> {
  eventTypes: SessionEventType[] = ["SESSION_INVALIDATED", "SESSION_DELETED"]
  private onSessionInvalidated: SessionInvalidatedFn
  private onSessionDeleted: SessionDeletedFn
  private currentSessionId: string | null = null

  constructor(
    onSessionInvalidated: SessionInvalidatedFn,
    onSessionDeleted: SessionDeletedFn
  ) {
    this.onSessionInvalidated = onSessionInvalidated
    this.onSessionDeleted = onSessionDeleted
  }

  setCurrentSessionId(sessionId: string | null): void {
    this.currentSessionId = sessionId
  }

  validate(
    eventType: SessionEventType,
    payload: unknown
  ): payload is SyncEventMap[SessionEventType] {
    return validateSyncEvent(eventType, payload) !== null
  }

  shouldProcess(
    event: SyncEventMap[SessionEventType],
    context: SyncContext
  ): boolean {
    // Always process session events when authenticated
    if (context.userId === null) {
      return false
    }

    // For SESSION_INVALIDATED, check if it's for our session
    if (event.type === "SESSION_INVALIDATED") {
      const invalidatedEvent = event as SessionInvalidatedEvent
      // If no sessionId specified, it's for all sessions (legacy)
      // If sessionId matches our session, process it
      if (invalidatedEvent.sessionId && this.currentSessionId) {
        return invalidatedEvent.sessionId === this.currentSessionId
      }
      return true
    }

    return true
  }

  async handle(
    event: SyncEventMap[SessionEventType],
    _context: SyncContext
  ): Promise<void> {
    if (event.type === "SESSION_INVALIDATED") {
      const invalidatedEvent = event as SessionInvalidatedEvent
      this.onSessionInvalidated(invalidatedEvent.reason)
    } else if (event.type === "SESSION_DELETED") {
      const deletedEvent = event as SessionDeletedEvent
      // Notify about the deleted session (for UI refresh)
      this.onSessionDeleted(deletedEvent.sessionId)
    }
  }
}
