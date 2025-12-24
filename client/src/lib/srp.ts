import {
  base64ToBytes,
  bytesToBase64,
  encodeUtf8,
} from "@/lib/crypto"

const N_HEX =
  "AC6BDB41324A9A9BF166DE5E1389582FAF72B6651987EE07FC3192943DB56050" +
  "A37329CBB4A099ED8193E0757767A13DD52312AB4B03310DCD7F48A9DA04FD50" +
  "E8083969EDB767B0CF6096F4CBE8FBC4B429207B98C5F4E6C8D2E0D9238FCA5" +
  "B1F8F4F8FD6F5C1A7A3A18E8C46B6F5B6F406B7EDEE386BFB5A899FA5AE9F2411" +
  "7C4B1FE649286651ECE45B3DC2007CB8A163BF0598DA48361C55D39A69163FA8" +
  "FD24CF5F83655D23DCA3AD961C62F356208552BB9ED529077096966D670C354E4" +
  "ABC9804F1746C08CA18217C32905E462E36CE3BE39E772C180E86039B2783A2EC" +
  "07A28FB5C55DF06F4C52C9DE2BCBF6955817183995497CEA956AE515D2261898F"

const N = BigInt(`0x${N_HEX}`)
const G = 2n
const N_BYTES = N_HEX.length / 2

const concatBytes = (...chunks: Uint8Array[]) => {
  const total = chunks.reduce((sum, chunk) => sum + chunk.length, 0)
  const output = new Uint8Array(total)
  let offset = 0
  for (const chunk of chunks) {
    output.set(chunk, offset)
    offset += chunk.length
  }
  return output
}

const toBigInt = (bytes: Uint8Array): bigint => {
  let hex = ""
  for (const byte of bytes) {
    hex += byte.toString(16).padStart(2, "0")
  }
  return BigInt(`0x${hex || "0"}`)
}

const toBytes = (value: bigint, length = N_BYTES): Uint8Array => {
  let hex = value.toString(16)
  if (hex.length % 2) {
    hex = `0${hex}`
  }
  const raw = new Uint8Array(hex.length / 2)
  for (let i = 0; i < raw.length; i += 1) {
    raw[i] = Number.parseInt(hex.slice(i * 2, i * 2 + 2), 16)
  }
  if (raw.length >= length) {
    return raw
  }
  const padded = new Uint8Array(length)
  padded.set(raw, length - raw.length)
  return padded
}

const modPow = (base: bigint, exp: bigint, mod: bigint): bigint => {
  let result = 1n
  let b = base % mod
  let e = exp
  while (e > 0n) {
    if (e & 1n) {
      result = (result * b) % mod
    }
    e >>= 1n
    b = (b * b) % mod
  }
  return result
}

const sha256 = async (...chunks: Uint8Array[]) => {
  const data = concatBytes(...chunks)
  const digest = await crypto.subtle.digest("SHA-256", data)
  return new Uint8Array(digest)
}

let cachedK: bigint | null = null

const getK = async () => {
  if (cachedK !== null) {
    return cachedK
  }
  const kBytes = await sha256(toBytes(N), toBytes(G))
  cachedK = toBigInt(kBytes)
  return cachedK
}

const computeX = async (
  username: string,
  password: string,
  saltBytes: Uint8Array
) => {
  const inner = await sha256(encodeUtf8(`${username}:${password}`))
  const xBytes = await sha256(saltBytes, inner)
  return toBigInt(xBytes)
}

export const generateSrpSalt = (): Uint8Array => {
  const cryptoRef = crypto
  return cryptoRef.getRandomValues(new Uint8Array(16))
}

export const computeVerifier = async (
  username: string,
  password: string,
  saltBase64: string
) => {
  const saltBytes = base64ToBytes(saltBase64)
  const x = await computeX(username, password, saltBytes)
  const v = modPow(G, x, N)
  return bytesToBase64(toBytes(v))
}

export const generateClientEphemeral = () => {
  const secret = toBigInt(crypto.getRandomValues(new Uint8Array(32)))
  const A = modPow(G, secret, N)
  const ABytes = toBytes(A)
  return {
    a: secret,
    A: bytesToBase64(ABytes),
    ABytes,
  }
}

export const computeClientProof = async (options: {
  username: string
  password: string
  saltBase64: string
  ABase64: string
  BBase64: string
  a: bigint
}) => {
  const { username, password, saltBase64, ABase64, BBase64, a } = options
  const ABytes = base64ToBytes(ABase64)
  const BBytes = base64ToBytes(BBase64)
  const A = toBigInt(ABytes)
  const B = toBigInt(BBytes)
  if (A % N === 0n || B % N === 0n) {
    throw new Error("Invalid SRP parameters")
  }
  const k = await getK()
  const u = toBigInt(await sha256(toBytes(A), BBytes))
  if (u === 0n) {
    throw new Error("Invalid SRP parameters")
  }
  const x = await computeX(username, password, base64ToBytes(saltBase64))
  const gx = modPow(G, x, N)
  let base = (B - (k * gx) % N) % N
  if (base < 0n) {
    base = (base + N) % N
  }
  const exp = a + u * x
  const S = modPow(base, exp, N)
  const K = await sha256(toBytes(S))
  const M1 = await sha256(toBytes(A), BBytes, K)
  return {
    key: K,
    M1: bytesToBase64(M1),
    ABytes,
  }
}

export const verifyServerProof = async (options: {
  ABase64: string
  M1Base64: string
  key: Uint8Array
  M2Base64: string
}) => {
  const ABytes = base64ToBytes(options.ABase64)
  const M1Bytes = base64ToBytes(options.M1Base64)
  const expectedM2 = await sha256(ABytes, M1Bytes, options.key)
  const actualM2 = base64ToBytes(options.M2Base64)
  if (expectedM2.length !== actualM2.length) {
    return false
  }
  for (let i = 0; i < expectedM2.length; i += 1) {
    if (expectedM2[i] !== actualM2[i]) {
      return false
    }
  }
  return true
}
