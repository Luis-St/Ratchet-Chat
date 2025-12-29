export const CONTACT_TRANSPORT_KEY_UPDATED_EVENT =
  "ratchet-contact-transport-key-updated"

export type ContactTransportKeyUpdatedDetail = {
  handle: string
  publicTransportKey: string
}

export const OPEN_CONTACT_CHAT_EVENT = "ratchet-open-contact-chat"

export type OpenContactChatDetail = {
  handle: string
}
