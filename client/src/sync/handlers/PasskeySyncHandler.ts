import type {
  SyncHandler,
  SyncContext,
  SyncEventMap,
  PasskeyAddedEvent,
  PasskeyRemovedEvent,
} from "../types"
import { validateSyncEvent } from "../validation"

type PasskeyEventType = "PASSKEY_ADDED" | "PASSKEY_REMOVED"

export type PasskeyInfo = {
  id: string
  credentialId: string
  name: string | null
  createdAt: string
}

export type PasskeyAddedFn = (passkey: PasskeyInfo) => void
export type PasskeyRemovedFn = (credentialId: string) => void

export class PasskeySyncHandler implements SyncHandler<PasskeyEventType> {
  eventTypes: PasskeyEventType[] = ["PASSKEY_ADDED", "PASSKEY_REMOVED"]
  private onPasskeyAdded: PasskeyAddedFn
  private onPasskeyRemoved: PasskeyRemovedFn

  constructor(
    onPasskeyAdded: PasskeyAddedFn,
    onPasskeyRemoved: PasskeyRemovedFn
  ) {
    this.onPasskeyAdded = onPasskeyAdded
    this.onPasskeyRemoved = onPasskeyRemoved
  }

  validate(
    eventType: PasskeyEventType,
    payload: unknown
  ): payload is SyncEventMap[PasskeyEventType] {
    return validateSyncEvent(eventType, payload) !== null
  }

  shouldProcess(
    _event: SyncEventMap[PasskeyEventType],
    context: SyncContext
  ): boolean {
    // Only process if authenticated
    return context.userId !== null
  }

  async handle(
    event: SyncEventMap[PasskeyEventType],
    _context: SyncContext
  ): Promise<void> {
    if (event.type === "PASSKEY_ADDED") {
      const addedEvent = event as PasskeyAddedEvent
      this.onPasskeyAdded({
        id: addedEvent.id,
        credentialId: addedEvent.credentialId,
        name: addedEvent.name,
        createdAt: addedEvent.createdAt,
      })
    } else if (event.type === "PASSKEY_REMOVED") {
      const removedEvent = event as PasskeyRemovedEvent
      this.onPasskeyRemoved(removedEvent.credentialId)
    }
  }
}
