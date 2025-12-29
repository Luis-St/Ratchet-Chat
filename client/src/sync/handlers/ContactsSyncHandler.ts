import type {
  SyncHandler,
  SyncContext,
  ContactsUpdatedEvent,
} from "../types"
import { validateSyncEvent } from "../validation"

export type ContactsApplyFn = (encrypted: {
  ciphertext: string
  iv: string
}) => Promise<void>

export class ContactsSyncHandler
  implements SyncHandler<"CONTACTS_UPDATED">
{
  eventTypes: ["CONTACTS_UPDATED"] = ["CONTACTS_UPDATED"]
  private applyContacts: ContactsApplyFn

  constructor(applyContacts: ContactsApplyFn) {
    this.applyContacts = applyContacts
  }

  validate(
    eventType: "CONTACTS_UPDATED",
    payload: unknown
  ): payload is ContactsUpdatedEvent {
    return validateSyncEvent(eventType, payload) !== null
  }

  shouldProcess(
    _event: ContactsUpdatedEvent,
    context: SyncContext
  ): boolean {
    return context.userId !== null && context.masterKey !== null
  }

  async handle(
    event: ContactsUpdatedEvent,
    _context: SyncContext
  ): Promise<void> {
    await this.applyContacts({
      ciphertext: event.ciphertext,
      iv: event.iv,
    })
  }
}
