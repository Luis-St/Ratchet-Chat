import crypto from "crypto";

const N_HEX =
  "AC6BDB41324A9A9BF166DE5E1389582FAF72B6651987EE07FC3192943DB56050" +
  "A37329CBB4A099ED8193E0757767A13DD52312AB4B03310DCD7F48A9DA04FD50" +
  "E8083969EDB767B0CF6096F4CBE8FBC4B429207B98C5F4E6C8D2E0D9238FCA5" +
  "B1F8F4F8FD6F5C1A7A3A18E8C46B6F5B6F406B7EDEE386BFB5A899FA5AE9F2411" +
  "7C4B1FE649286651ECE45B3DC2007CB8A163BF0598DA48361C55D39A69163FA8" +
  "FD24CF5F83655D23DCA3AD961C62F356208552BB9ED529077096966D670C354E4" +
  "ABC9804F1746C08CA18217C32905E462E36CE3BE39E772C180E86039B2783A2EC" +
  "07A28FB5C55DF06F4C52C9DE2BCBF6955817183995497CEA956AE515D2261898F";

const N = BigInt(`0x${N_HEX}`);
const G = 2n;
const N_BYTES = N_HEX.length / 2;

const sha256 = (...buffers: Buffer[]) =>
  crypto.createHash("sha256").update(Buffer.concat(buffers)).digest();

const toBigInt = (bytes: Uint8Array): bigint =>
  BigInt(`0x${Buffer.from(bytes).toString("hex") || "0"}`);

const toBytes = (value: bigint, length = N_BYTES): Buffer => {
  let hex = value.toString(16);
  if (hex.length % 2) {
    hex = `0${hex}`;
  }
  const raw = Buffer.from(hex, "hex");
  if (raw.length >= length) {
    return raw;
  }
  const padded = Buffer.alloc(length);
  raw.copy(padded, length - raw.length);
  return padded;
};

const modPow = (base: bigint, exp: bigint, mod: bigint): bigint => {
  let result = 1n;
  let b = base % mod;
  let e = exp;
  while (e > 0n) {
    if (e & 1n) {
      result = (result * b) % mod;
    }
    e >>= 1n;
    b = (b * b) % mod;
  }
  return result;
};

const k = toBigInt(sha256(toBytes(N), toBytes(G)));

export type SrpServerEphemeral = {
  b: bigint;
  B: string;
  BBytes: Buffer;
};

export type SrpServerSession = {
  key: Buffer;
  M1: string;
  M2: string;
};

export const srp = {
  N,
  G,
  N_BYTES,
  k,
  toBigInt,
  toBytes,
  modPow,
  sha256,
};

export const generateServerEphemeral = (verifierBase64: string): SrpServerEphemeral => {
  const verifier = toBigInt(Buffer.from(verifierBase64, "base64"));
  const b = toBigInt(crypto.randomBytes(32));
  const gb = modPow(G, b, N);
  const B = (k * verifier + gb) % N;
  const BBytes = toBytes(B);
  return {
    b,
    B: BBytes.toString("base64"),
    BBytes,
  };
};

export const computeServerSession = (
  ABase64: string,
  BBytes: Buffer,
  b: bigint,
  verifierBase64: string
): SrpServerSession | null => {
  const ABytes = Buffer.from(ABase64, "base64");
  const A = toBigInt(ABytes);
  if (A % N === 0n) {
    return null;
  }
  const u = toBigInt(sha256(toBytes(A), BBytes));
  if (u === 0n) {
    return null;
  }
  const verifier = toBigInt(Buffer.from(verifierBase64, "base64"));
  const S = modPow((A * modPow(verifier, u, N)) % N, b, N);
  const K = sha256(toBytes(S));
  const M1 = sha256(toBytes(A), BBytes, K);
  const M2 = sha256(toBytes(A), M1, K);
  return {
    key: K,
    M1: M1.toString("base64"),
    M2: M2.toString("base64"),
  };
};
