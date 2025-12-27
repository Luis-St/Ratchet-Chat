export const CONTACT_TRANSPORT_KEY_UPDATED_EVENT =
  "ratchet-contact-transport-key-updated"

export type ContactTransportKeyUpdatedDetail = {
  handle: string
  publicTransportKey: string
}
