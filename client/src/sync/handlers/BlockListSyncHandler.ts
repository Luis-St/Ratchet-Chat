import type {
  SyncHandler,
  SyncContext,
  BlockListUpdatedEvent,
} from "../types"
import { validateSyncEvent } from "../validation"

export type BlockListApplyFn = (encrypted: {
  ciphertext: string
  iv: string
}) => Promise<void>

export class BlockListSyncHandler
  implements SyncHandler<"BLOCK_LIST_UPDATED">
{
  eventTypes: ["BLOCK_LIST_UPDATED"] = ["BLOCK_LIST_UPDATED"]
  private applyBlockList: BlockListApplyFn

  constructor(applyBlockList: BlockListApplyFn) {
    this.applyBlockList = applyBlockList
  }

  validate(
    eventType: "BLOCK_LIST_UPDATED",
    payload: unknown
  ): payload is BlockListUpdatedEvent {
    return validateSyncEvent(eventType, payload) !== null
  }

  shouldProcess(
    _event: BlockListUpdatedEvent,
    context: SyncContext
  ): boolean {
    // Only process if authenticated
    return context.userId !== null && context.masterKey !== null
  }

  async handle(
    event: BlockListUpdatedEvent,
    _context: SyncContext
  ): Promise<void> {
    await this.applyBlockList({
      ciphertext: event.ciphertext,
      iv: event.iv,
    })
  }
}
