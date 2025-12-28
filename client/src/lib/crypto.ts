import { ml_dsa65 } from "@noble/post-quantum/ml-dsa.js"
import { ml_kem768 } from "@noble/post-quantum/ml-kem.js"

const textEncoder = new TextEncoder()
const textDecoder = new TextDecoder()
const MESSAGE_SIGNATURE_PREFIX = "ratchet-chat:message:v1"
export const identitySecretKeyLength = ml_dsa65.lengths.secretKey
export const transportSecretKeyLength = ml_kem768.lengths.secretKey

type WebCryptoWithSubtle = Crypto & { subtle: SubtleCrypto }

const buildWebCryptoError = () => {
  const isSecure =
    typeof globalThis.isSecureContext === "boolean" && globalThis.isSecureContext
  if (!isSecure) {
    return new Error(
      "WebCrypto requires a secure context. Use https or access via localhost (LAN IPs over http are not secure)."
    )
  }
  return new Error("WebCrypto is unavailable in this browser.")
}

const getWebCrypto = (): WebCryptoWithSubtle => {
  const cryptoRef = globalThis.crypto
  if (!cryptoRef?.subtle) {
    throw buildWebCryptoError()
  }
  return cryptoRef as WebCryptoWithSubtle
}

export const getSubtleCrypto = (): SubtleCrypto => getWebCrypto().subtle

export type EncryptedPayload = {
  ciphertext: string
  iv: string
}

export type IdentityKeyPair = {
  publicKey: string
  privateKey: Uint8Array
}

export type TransportKeyPair = {
  publicKey: string
  privateKey: Uint8Array
}

export type TransitEnvelope = {
  cipherText: string
  iv: string
  ciphertext: string
}

export function bytesToBase64(bytes: Uint8Array): string {
  let binary = ""
  for (let i = 0; i < bytes.length; i += 0x8000) {
    binary += String.fromCharCode(...bytes.subarray(i, i + 0x8000))
  }
  return btoa(binary)
}

export function base64ToBytes(base64: string): Uint8Array {
  const binary = atob(base64)
  const bytes = new Uint8Array(binary.length)
  for (let i = 0; i < binary.length; i += 1) {
    bytes[i] = binary.charCodeAt(i)
  }
  return bytes
}

function bytesToArrayBuffer(bytes: Uint8Array): ArrayBuffer {
  const copy = new Uint8Array(bytes.byteLength)
  copy.set(bytes)
  return copy.buffer
}

export function arrayBufferToBase64(buffer: ArrayBuffer): string {
  return bytesToBase64(new Uint8Array(buffer))
}

export function base64ToArrayBuffer(base64: string): ArrayBuffer {
  return bytesToArrayBuffer(base64ToBytes(base64))
}

export function encodeUtf8(value: string): Uint8Array {
  return textEncoder.encode(value)
}

export function decodeUtf8(value: Uint8Array): string {
  return textDecoder.decode(value)
}

export function buildMessageSignaturePayload(
  senderHandle: string,
  content: string,
  messageId?: string
): Uint8Array {
  const payload = messageId
    ? [MESSAGE_SIGNATURE_PREFIX, senderHandle, content, messageId]
    : [MESSAGE_SIGNATURE_PREFIX, senderHandle, content]
  return encodeUtf8(
    JSON.stringify(payload)
  )
}

export function generateSalt(length = 16): Uint8Array {
  return getWebCrypto().getRandomValues(new Uint8Array(length))
}

export async function deriveMasterKey(
  password: string,
  salt: Uint8Array,
  iterations = 310_000
): Promise<CryptoKey> {
  const subtle = getSubtleCrypto()
  const baseKey = await subtle.importKey(
    "raw",
    textEncoder.encode(password),
    "PBKDF2",
    false,
    ["deriveKey"]
  )
  return subtle.deriveKey(
    {
      name: "PBKDF2",
      salt: bytesToArrayBuffer(salt),
      iterations,
      hash: "SHA-256",
    },
    baseKey,
    {
      name: "AES-GCM",
      length: 256,
    },
    true,
    ["encrypt", "decrypt"]
  )
}

export async function deriveAuthHash(
  password: string,
  salt: Uint8Array,
  iterations = 200_000
): Promise<string> {
  const subtle = getSubtleCrypto()
  const baseKey = await subtle.importKey(
    "raw",
    textEncoder.encode(password),
    "PBKDF2",
    false,
    ["deriveBits"]
  )
  const bits = await subtle.deriveBits(
    {
      name: "PBKDF2",
      salt: bytesToArrayBuffer(salt),
      iterations,
      hash: "SHA-256",
    },
    baseKey,
    256
  )
  return arrayBufferToBase64(bits)
}

export async function generateIdentityKeyPair(): Promise<IdentityKeyPair> {
  const pair = ml_dsa65.keygen()
  return {
    publicKey: bytesToBase64(pair.publicKey),
    privateKey: pair.secretKey,
  }
}

export async function generateTransportKeyPair(): Promise<TransportKeyPair> {
  const pair = ml_kem768.keygen()
  return {
    publicKey: bytesToBase64(pair.publicKey),
    privateKey: pair.secretKey,
  }
}

export function getIdentityPublicKey(privateKey: Uint8Array): string {
  const dsa = ml_dsa65 as unknown as {
    getPublicKey?: (secretKey: Uint8Array) => Uint8Array
    publicKeyFromSecretKey?: (secretKey: Uint8Array) => Uint8Array
  }
  const publicKey =
    dsa.getPublicKey?.(privateKey) ??
    dsa.publicKeyFromSecretKey?.(privateKey)
  if (!publicKey) {
    throw new Error("Unable to derive ML-DSA public key from secret key")
  }
  return bytesToBase64(publicKey)
}

export async function encryptBytes(
  key: CryptoKey,
  plaintext: Uint8Array
): Promise<{ ciphertext: Uint8Array; iv: Uint8Array }> {
  const cryptoRef = getWebCrypto()
  const iv = cryptoRef.getRandomValues(new Uint8Array(12))
  const ciphertext = new Uint8Array(
    await cryptoRef.subtle.encrypt(
      { name: "AES-GCM", iv: bytesToArrayBuffer(iv) },
      key,
      bytesToArrayBuffer(plaintext)
    )
  )
  return { ciphertext, iv }
}

export async function decryptBytes(
  key: CryptoKey,
  ciphertext: Uint8Array,
  iv: Uint8Array
): Promise<Uint8Array> {
  const plaintext = await getSubtleCrypto().decrypt(
    { name: "AES-GCM", iv: bytesToArrayBuffer(iv) },
    key,
    bytesToArrayBuffer(ciphertext)
  )
  return new Uint8Array(plaintext)
}

export function signMessage(message: Uint8Array, privateKey: Uint8Array): string {
  const signature = ml_dsa65.sign(message, privateKey)
  return bytesToBase64(signature)
}

export async function encryptString(
  key: CryptoKey,
  plaintext: string
): Promise<EncryptedPayload> {
  const { ciphertext, iv } = await encryptBytes(key, textEncoder.encode(plaintext))
  return {
    ciphertext: bytesToBase64(ciphertext),
    iv: bytesToBase64(iv),
  }
}

export async function decryptString(
  key: CryptoKey,
  payload: EncryptedPayload
): Promise<string> {
  const plaintext = await decryptBytes(
    key,
    base64ToBytes(payload.ciphertext),
    base64ToBytes(payload.iv)
  )
  return textDecoder.decode(plaintext)
}

export async function encryptPrivateKey(
  masterKey: CryptoKey,
  privateKey: Uint8Array
): Promise<EncryptedPayload> {
  const { ciphertext, iv } = await encryptBytes(masterKey, privateKey)
  return {
    ciphertext: bytesToBase64(ciphertext),
    iv: bytesToBase64(iv),
  }
}

export async function decryptPrivateKey(
  masterKey: CryptoKey,
  payload: EncryptedPayload
): Promise<Uint8Array> {
  return decryptBytes(
    masterKey,
    base64ToBytes(payload.ciphertext),
    base64ToBytes(payload.iv)
  )
}

export async function encryptTransitEnvelope(
  payload: string,
  recipientPublicKey: string
): Promise<string> {
  const cryptoRef = getWebCrypto()
  const { cipherText, sharedSecret } = ml_kem768.encapsulate(
    base64ToBytes(recipientPublicKey)
  )
  const aesKey = await cryptoRef.subtle.importKey(
    "raw",
    bytesToArrayBuffer(sharedSecret),
    "AES-GCM",
    false,
    ["encrypt", "decrypt"]
  )
  const { ciphertext, iv } = await encryptBytes(
    aesKey,
    textEncoder.encode(payload)
  )
  const envelope: TransitEnvelope = {
    cipherText: bytesToBase64(cipherText),
    iv: bytesToBase64(iv),
    ciphertext: bytesToBase64(ciphertext),
  }
  return JSON.stringify(envelope)
}

export async function decryptTransitBlob(
  encryptedBlob: string,
  transportPrivateKey: Uint8Array
): Promise<Uint8Array> {
  let envelope: TransitEnvelope
  try {
    envelope = JSON.parse(encryptedBlob) as TransitEnvelope
  } catch {
    throw new Error("Invalid transit envelope")
  }
  if (!envelope?.cipherText || !envelope.iv || !envelope.ciphertext) {
    throw new Error("Invalid transit envelope")
  }

  const sharedSecret = ml_kem768.decapsulate(
    base64ToBytes(envelope.cipherText),
    transportPrivateKey
  )
  const aesKey = await getSubtleCrypto().importKey(
    "raw",
    bytesToArrayBuffer(sharedSecret),
    "AES-GCM",
    false,
    ["decrypt"]
  )
  return decryptBytes(
    aesKey,
    base64ToBytes(envelope.ciphertext),
    base64ToBytes(envelope.iv)
  )
}

export function verifySignature(
  message: Uint8Array,
  signature: string,
  publicKey: string
): boolean {
  return ml_dsa65.verify(
    base64ToBytes(signature),
    message,
    base64ToBytes(publicKey)
  )
}

export async function generateSafetyNumber(
  key1: string,
  key2: string
): Promise<string> {
  const sorted = [key1, key2].sort()
  const input = sorted.join("")
  const hash = await getSubtleCrypto().digest(
    "SHA-256",
    textEncoder.encode(input)
  )
  const bytes = new Uint8Array(hash)

  // Take first 8 bytes (64 bits) -> ~1.8x10^19 possibilities
  // We want a human readable number, say 12 digits (4 blocks of 3)
  // We can treat the bytes as a large integer and modulo 10^12

  let num = BigInt(0)
  for (let i = 0; i < 8; i++) {
    num = (num << BigInt(8)) + BigInt(bytes[i])
  }

  const fingerprint = (num % BigInt(1000000000000)).toString().padStart(12, "0")

  // Format as XXX XXX XXX XXX
  return fingerprint.match(/.{1,3}/g)?.join(" ") ?? fingerprint
}
