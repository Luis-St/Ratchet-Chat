# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Ratchet-Chat is a federated, end-to-end encrypted messaging application using post-quantum cryptography. The server never sees plaintext messages, raw passwords, or private keys.

## Repository Structure

- `client/`: Next.js 16 app with React 19 (UI + client-side crypto)
- `server/`: Express API + Socket.IO + Prisma (PostgreSQL)

## Development Commands

### Server (from `server/`)
```bash
npm install
npm run prisma:generate    # Generate Prisma client
npm run prisma:migrate     # Run database migrations
npm run dev                # Start dev server (ts-node)
npm run build              # Compile TypeScript
npm start                  # Run compiled server
```

### Client (from `client/`)
```bash
npm install
npm run dev                # Start Next.js dev server
npm run build              # Production build
npm start                  # Start production server
```

### Production (Docker)
```bash
docker compose -f docker-compose.prod.yml up --build -d
```

## Architecture

### Cryptographic Design

The app uses NIST post-quantum primitives from `@noble/post-quantum`:
- **ML-KEM-768** (FIPS 203): Transport key encapsulation for message encryption
- **ML-DSA-65** (FIPS 204): Identity keys for signing messages
- **OPAQUE** (RFC 9497): Password authentication (server never sees plaintext passwords)
- **AES-GCM**: Payload encryption using keys derived from ML-KEM

### Two-Bucket Storage Pattern

The server implements a "blind drop-box" with strict separation:
1. **IncomingQueue**: Transit payloads encrypted to recipient's public transport key (ML-KEM)
2. **MessageVault**: Storage payloads re-encrypted by client with their AES key (derived via PBKDF2)

### Message Flow

1. Sender encrypts message with recipient's public transport key → POST `/messages/send`
2. Recipient pulls from `/messages/queue`, decrypts with private transport key
3. Recipient verifies sender signature (ML-DSA-65), re-encrypts with local AES key
4. Recipient stores via POST `/messages/queue/:id/store` → moves to MessageVault

### Client Architecture

- **Context Providers** (`client/src/context/`):
  - `AuthContext`: Authentication state, key management, OPAQUE flow, passkey (WebAuthn) support
  - `CallContext`: WebRTC voice/video calling
  - `BlockContext`: Encrypted user blocking
  - `SocketContext`: Socket.IO connection
  - `SettingsContext`: User preferences

- **Local Storage** (`client/src/lib/db.ts`): Dexie (IndexedDB) for messages, contacts, auth state
- **Crypto** (`client/src/lib/crypto.ts`): All encryption/signing operations
- **Main UI** (`client/src/components/DashboardLayout.tsx`): Primary chat interface

### Server Architecture

- **Routes** (`server/routes/`):
  - `auth.ts`: OPAQUE registration/login, passkeys, sessions, settings
  - `messages.ts`: Queue, vault, federation relay
  - `directory.ts`: Handle lookup (local + federated)

- **Federation** (`server/lib/federationAuth.ts`): Cross-server communication with ML-DSA-65 signatures
- **Database**: PostgreSQL via Prisma (`server/prisma/schema.prisma`)

### Federation

- Handles are `username@host` format
- TOFU (Trust On First Use) for federated identity trust
- Discovery via `/.well-known/ratchet-chat/federation.json`
- All federated messages are signed with the server's ML-DSA-65 key

### WebSocket Events (Socket.IO)

- `INCOMING_MESSAGE`: New message in queue
- `signal`: Ephemeral events (typing indicators, call signaling)

## Environment Variables

Key variables (see `.env.example` for full list):
- `DATABASE_URL`: PostgreSQL connection string
- `JWT_SECRET`: Session signing key
- `SERVER_HOST`: Federation hostname
- `CORS_ALLOWED_ORIGINS`: Allowed client origins
- `NEXT_PUBLIC_API_URL`: Client API endpoint
