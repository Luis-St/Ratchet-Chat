import {
  KE2,
  OpaqueClient,
  OpaqueID,
  RegistrationResponse,
  getOpaqueConfig,
} from "@cloudflare/opaque-ts"

export type ClientRegistrationState = OpaqueClient
export type ClientLoginState = OpaqueClient

const config = getOpaqueConfig(OpaqueID.OPAQUE_P256)

const toBytes = (bytes: number[]): Uint8Array => Uint8Array.from(bytes)
const toNumbers = (bytes: Uint8Array): number[] => Array.from(bytes)

export async function registerStart(password: string): Promise<{
  request: Uint8Array
  state: ClientRegistrationState
}> {
  const client = new OpaqueClient(config)
  const request = await client.registerInit(password)
  if (request instanceof Error) {
    throw new Error(request.message)
  }
  return { request: toBytes(request.serialize()), state: client }
}

export async function registerFinish(
  state: ClientRegistrationState,
  serverResponse: Uint8Array
): Promise<Uint8Array> {
  const response = RegistrationResponse.deserialize(config, toNumbers(serverResponse))
  const result = await state.registerFinish(response)
  if (result instanceof Error) {
    throw new Error(result.message)
  }
  return toBytes(result.record.serialize())
}

export async function loginStart(password: string): Promise<{
  request: Uint8Array
  state: ClientLoginState
}> {
  const client = new OpaqueClient(config)
  const ke1 = await client.authInit(password)
  if (ke1 instanceof Error) {
    throw new Error(ke1.message)
  }
  return { request: toBytes(ke1.serialize()), state: client }
}

export async function loginFinish(
  state: ClientLoginState,
  serverResponse: Uint8Array
): Promise<{ sessionKey: Uint8Array; finishMessage: Uint8Array }> {
  const ke2 = KE2.deserialize(config, toNumbers(serverResponse))
  const result = await state.authFinish(ke2)
  if (result instanceof Error) {
    throw new Error(result.message)
  }
  return {
    sessionKey: toBytes(result.session_key),
    finishMessage: toBytes(result.ke3.serialize()),
  }
}
