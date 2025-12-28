import { webcrypto } from "crypto";
import {
  ExpectedAuthResult,
  KE1,
  KE3,
  OpaqueID,
  OpaqueServer,
  RegistrationRecord,
  RegistrationRequest,
  getOpaqueConfig,
} from "@cloudflare/opaque-ts";

export type ServerRegistrationState = null;
export type ServerLoginState = ExpectedAuthResult;

const globalCrypto = globalThis as typeof globalThis & { crypto?: any };
if (!globalCrypto.crypto) {
  globalCrypto.crypto = webcrypto as any;
}

const config = getOpaqueConfig(OpaqueID.OPAQUE_P256);

let serverInstance: OpaqueServer | null = null;
const getServer = async () => {
  if (serverInstance) {
    return serverInstance;
  }
  const oprfSeed = config.prng.random(config.hash.Nh);
  const akeKeypair = await config.ake.generateAuthKeyPair();
  serverInstance = new OpaqueServer(config, oprfSeed, akeKeypair);
  return serverInstance;
};

const toBytes = (bytes: number[]): Uint8Array => Uint8Array.from(bytes);
const toNumbers = (bytes: Uint8Array): number[] => Array.from(bytes);

export const registerResponse = async (
  username: string,
  clientRequest: Uint8Array
): Promise<{ response: Uint8Array; state: ServerRegistrationState }> => {
  const server = await getServer();
  const request = RegistrationRequest.deserialize(config, toNumbers(clientRequest));
  const response = await server.registerInit(request, username);
  if (response instanceof Error) {
    throw response;
  }
  return { response: toBytes(response.serialize()), state: null };
};

export const registerFinish = (
  _state: ServerRegistrationState,
  clientFinish: Uint8Array
): Uint8Array => {
  const record = RegistrationRecord.deserialize(config, toNumbers(clientFinish));
  return toBytes(record.serialize());
};

export const loginResponse = async (
  username: string,
  passwordFile: Uint8Array,
  clientRequest: Uint8Array
): Promise<{ response: Uint8Array; state: ServerLoginState }> => {
  const server = await getServer();
  const ke1 = KE1.deserialize(config, toNumbers(clientRequest));
  const record = RegistrationRecord.deserialize(config, toNumbers(passwordFile));
  const result = await server.authInit(ke1, record, username);
  if (result instanceof Error) {
    throw result;
  }
  return { response: toBytes(result.ke2.serialize()), state: result.expected };
};

export const loginFinish = async (
  state: ServerLoginState,
  clientFinish: Uint8Array
): Promise<Uint8Array> => {
  const server = await getServer();
  const ke3 = KE3.deserialize(config, toNumbers(clientFinish));
  const response = server.authFinish(ke3, state);
  if (response instanceof Error) {
    throw response;
  }
  return toBytes(response.session_key);
};
