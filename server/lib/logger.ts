import fs from "fs";
import path from "path";
import winston from "winston";

const LOG_DIR = process.env.LOG_DIR ?? path.join(process.cwd(), "logs");
const SERVER_LOG_PATH =
  process.env.SERVER_LOG_PATH ?? path.join(LOG_DIR, "server.log");
const CLIENT_LOG_PATH =
  process.env.CLIENT_LOG_PATH ?? path.join(LOG_DIR, "client.log");
const MAX_STRING_LENGTH = Number(process.env.LOG_MAX_STRING_LENGTH ?? 20000);

// Detect if running in Docker/production - use console logging instead of files
const isProduction = process.env.NODE_ENV === "production";
const isDocker = fs.existsSync("/.dockerenv") || process.env.DOCKER_CONTAINER === "true";
const useConsoleLogging = isProduction || isDocker;

// Default to 'warn' in production to reduce noise, 'info' in development
const LOG_LEVEL = process.env.LOG_LEVEL ?? (isProduction ? "warn" : "info");

const SENSITIVE_KEYS = new Set([
  "password",
  "kdf_salt",
  "encrypted_identity_key",
  "encrypted_transport_key",
  "encrypted_identity_iv",
  "encrypted_transport_iv",
  "encrypted_contacts",
  "encrypted_contacts_iv",
  "private_key",
  "server_private_key",
  "token",
  "authorization",
  "cookie",
  "masterkey",
  "identityprivatekey",
  "transportprivatekey",
]);

const ensureLogDir = () => {
  if (!fs.existsSync(LOG_DIR)) {
    fs.mkdirSync(LOG_DIR, { recursive: true });
  }
};

const buildLogger = (loggerName: string, filename: string) => {
  const format = winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    useConsoleLogging
      ? winston.format.printf(({ timestamp, level, message, ...meta }) => {
          const metaStr = Object.keys(meta).length ? JSON.stringify(meta) : "";
          return `[${timestamp}] [${loggerName}] ${level}: ${message} ${metaStr}`;
        })
      : winston.format.json()
  );

  const transports = useConsoleLogging
    ? [new winston.transports.Console()]
    : (() => {
        ensureLogDir();
        return [new winston.transports.File({ filename })];
      })();

  return winston.createLogger({
    level: LOG_LEVEL,
    format,
    transports,
  });
};

export const serverLogger = buildLogger("SERVER", SERVER_LOG_PATH);
export const clientLogger = buildLogger("CLIENT", CLIENT_LOG_PATH);

export const sanitizeLogPayload = (value: unknown): unknown => {
  const seen = new WeakSet<object>();

  const sanitize = (input: unknown, key?: string): unknown => {
    const loweredKey = key?.toLowerCase();
    if (loweredKey && SENSITIVE_KEYS.has(loweredKey)) {
      return "[redacted]";
    }
    if (typeof input === "string") {
      if (input.length > MAX_STRING_LENGTH) {
        return `${input.slice(0, MAX_STRING_LENGTH)}...[truncated]`;
      }
      return input;
    }
    if (Buffer.isBuffer(input)) {
      return input.toString("base64");
    }
    if (!input || typeof input !== "object") {
      return input;
    }
    if (seen.has(input)) {
      return "[circular]";
    }
    seen.add(input);

    if (Array.isArray(input)) {
      return input.map((item) => sanitize(item));
    }

    return Object.fromEntries(
      Object.entries(input as Record<string, unknown>).map(([childKey, val]) => [
        childKey,
        sanitize(val, childKey),
      ])
    );
  };

  return sanitize(value);
};
