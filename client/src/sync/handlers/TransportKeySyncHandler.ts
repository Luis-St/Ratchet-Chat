import type {
  SyncHandler,
  SyncContext,
  TransportKeyRotatedEvent,
} from "../types"
import { validateSyncEvent } from "../validation"

export type TransportKeyRotationPayload = {
  public_transport_key: string
  encrypted_transport_key: string
  encrypted_transport_iv: string
  rotated_at?: number
  timestamp?: string
}

export type TransportKeyApplyFn = (
  payload: TransportKeyRotationPayload
) => Promise<void>

export class TransportKeySyncHandler
  implements SyncHandler<"TRANSPORT_KEY_ROTATED">
{
  eventTypes: ["TRANSPORT_KEY_ROTATED"] = ["TRANSPORT_KEY_ROTATED"]
  private applyRotation: TransportKeyApplyFn

  constructor(applyRotation: TransportKeyApplyFn) {
    this.applyRotation = applyRotation
  }

  validate(
    eventType: "TRANSPORT_KEY_ROTATED",
    payload: unknown
  ): payload is TransportKeyRotatedEvent {
    return validateSyncEvent(eventType, payload) !== null
  }

  shouldProcess(
    _event: TransportKeyRotatedEvent,
    context: SyncContext
  ): boolean {
    // Only process if authenticated with master key
    return context.userId !== null && context.masterKey !== null
  }

  async handle(
    event: TransportKeyRotatedEvent,
    _context: SyncContext
  ): Promise<void> {
    console.log("[TransportKeySyncHandler] Applying transport key rotation")
    await this.applyRotation({
      public_transport_key: event.public_transport_key,
      encrypted_transport_key: event.encrypted_transport_key,
      encrypted_transport_iv: event.encrypted_transport_iv,
      rotated_at: event.rotated_at,
      timestamp: event.timestamp,
    })
    console.log("[TransportKeySyncHandler] Transport key rotation applied")
  }
}
