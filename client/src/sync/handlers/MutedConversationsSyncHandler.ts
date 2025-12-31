import type {
  SyncHandler,
  SyncContext,
  MutedConversationsUpdatedEvent,
} from "../types"
import { validateSyncEvent } from "../validation"

export type MutedConversationsApplyFn = (encrypted: {
  ciphertext: string
  iv: string
}) => Promise<void>

export class MutedConversationsSyncHandler
  implements SyncHandler<"MUTED_CONVERSATIONS_UPDATED">
{
  eventTypes: ["MUTED_CONVERSATIONS_UPDATED"] = ["MUTED_CONVERSATIONS_UPDATED"]
  private applyMutedConversations: MutedConversationsApplyFn

  constructor(applyMutedConversations: MutedConversationsApplyFn) {
    this.applyMutedConversations = applyMutedConversations
  }

  validate(
    eventType: "MUTED_CONVERSATIONS_UPDATED",
    payload: unknown
  ): payload is MutedConversationsUpdatedEvent {
    return validateSyncEvent(eventType, payload) !== null
  }

  shouldProcess(
    _event: MutedConversationsUpdatedEvent,
    context: SyncContext
  ): boolean {
    // Only process if authenticated
    return context.userId !== null && context.masterKey !== null
  }

  async handle(
    event: MutedConversationsUpdatedEvent,
    _context: SyncContext
  ): Promise<void> {
    await this.applyMutedConversations({
      ciphertext: event.ciphertext,
      iv: event.iv,
    })
  }
}
