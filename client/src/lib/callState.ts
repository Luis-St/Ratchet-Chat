// Simple shared state to track if a call is active
// Used by AuthContext to pause automatic key rotation during calls

let inCallStatus = false

export function setInCall(active: boolean): void {
  inCallStatus = active
}

export function isInCall(): boolean {
  return inCallStatus
}
