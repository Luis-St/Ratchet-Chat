# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Ratchet Chat is a federated, end-to-end encrypted messaging platform using post-quantum cryptography (ML-KEM-768, ML-DSA-65) and the OPAQUE protocol (RFC 9497) for password-authenticated key exchange.

## Requirements

- Node.js 22
- PostgreSQL (local dev) or Docker for production
- Flutter SDK 3.10+ (for native_client)

## Repository Structure

- **server/** - Express.js + Prisma + PostgreSQL backend
- **client/** - Next.js 16 + React 19 web client (uses shadcn/ui components)
- **native_client/** - Flutter cross-platform mobile/desktop app (uses Riverpod, go_router)
- **opaque_client_dart/** - Pure Dart port of OPAQUE protocol for Flutter

## Development Commands

### Server
```bash
cd server
npm install
npm run prisma:generate    # Generate Prisma client
npm run prisma:migrate     # Run database migrations
npm run dev                # Start dev server (ts-node)
npm run build && npm start # Production build
```

### Client
```bash
cd client
npm install
npm run dev      # Start dev server (localhost:3000)
npm run build    # Build for production (runs prebuild for service worker crypto)
npx shadcn add <component>  # Add shadcn/ui components
```

### Native Client (Flutter)
```bash
cd native_client
flutter pub get
flutter run                  # Run on connected device/emulator
flutter run -d <device_id>   # Run on specific device
flutter analyze              # Lint check
flutter test                 # Run all tests
flutter test test/<file>     # Run single test file
```

### OPAQUE Dart Library
```bash
cd opaque_client_dart
dart pub get
dart test                    # Run all tests
dart test test/<file>        # Run single test file
```

## Architecture

### Security Model (Zero-Knowledge Server)
The server never has access to plaintext messages, private keys, or passwords:
- **Messages**: Encrypted with recipient's ML-KEM-768 public key before sending
- **Storage**: Server stores only encrypted blobs in `IncomingQueue` (transit) and `MessageVault` (permanent)
- **Authentication**: OPAQUE protocol - server only stores password file, never plaintext password
- **Keys**: Private keys encrypted with master key (PBKDF2-derived from password) stored client-side

### Message Flow
1. Sender encrypts with recipient's public transport key (ML-KEM-768)
2. Sender signs with own private identity key (ML-DSA-65)
3. Server stores in recipient's `IncomingQueue`
4. Recipient decrypts with private transport key, verifies signature
5. Recipient re-encrypts with local AES key, stores in `MessageVault`

### Key Components

**Server** (`server/`):
- `lib/opaque.ts` - OPAQUE protocol server logic
- `lib/federationAuth.ts` - Federation key management & TOFU
- `routes/auth.ts` - OPAQUE authentication endpoints
- `routes/messages.ts` - Message send/receive/vault operations
- `routes/directory.ts` - User discovery & federation
- `prisma/schema.prisma` - Database schema

**Client** (`client/src/`):
- `lib/crypto.ts` - ML-DSA-65, ML-KEM-768, AES-GCM operations
- `lib/opaque.ts` - OPAQUE client operations
- `lib/messageUtils.ts` - Message encryption/decryption
- `lib/db.ts` - Dexie/IndexedDB local storage for messages
- `lib/webrtc.ts` - WebRTC peer connections for voice/video calls
- `context/AuthContext.tsx` - Auth state, key management
- `context/SocketContext.tsx` - Real-time messaging (Socket.IO)
- `context/SyncContext.tsx` - Message vault synchronization
- `context/CallContext.tsx` - WebRTC call state management
- `sync/` - Message sync coordination and deduplication

**Native Client** (`native_client/lib/`):
- `data/services/` - API, crypto, OPAQUE, passkey, secure storage services
- `data/repositories/` - Data access layer
- `providers/` - Riverpod state providers
- `routing/` - go_router configuration
- `core/` - Constants, errors, theme
- `ui/screens/` - Screen widgets
- `ui/widgets/` - Reusable UI components

### Database Models
- `User` - Account with public/encrypted-private keys, OPAQUE password file, TOTP 2FA
- `IncomingQueue` - Transit encrypted messages awaiting client decryption
- `MessageVault` - Permanent client-encrypted message storage
- `Session` - JWT sessions with token hashing
- `PasskeyCredential` - WebAuthn/Passkey credentials
- `PushSubscription` - Web push notification endpoints per session
- `TotpRecoveryCode` - Hashed backup codes for TOTP 2FA recovery

### Federation
- TOFU (Trust On First Use) model by default
- Messages signed with server's ML-DSA-65 key
- Discovery via `/.well-known/ratchet-chat/federation.json`
- Optional allowlist via `FEDERATION_ALLOWED_HOSTS`

## Cryptography

Uses NIST post-quantum primitives:
- **ML-KEM-768** (FIPS 203) - Transport key encapsulation
- **ML-DSA-65** (FIPS 204) - Identity keys and signatures
- **AES-256-GCM** - Message payload encryption
- **OPAQUE** (RFC 9497) - Password authentication

Libraries: `@noble/post-quantum`, `@cloudflare/opaque-ts` (TypeScript), `oqs`, `pointycastle` (Flutter)

## Environment Setup

Copy `.env.example` to `.env` in root, server, and client directories. Key variables:
- `DATABASE_URL` - PostgreSQL connection
- `JWT_SECRET` - Must be changed from default
- `NEXT_PUBLIC_API_URL`, `NEXT_PUBLIC_API_HOST` - API endpoints
- `CORS_ALLOWED_ORIGINS` - Allowed origins for CORS

## Docker

```bash
# Development
docker-compose up -d

# Production (requires env configuration)
docker-compose -f docker-compose.prod.yml up --build -d
```

## Key Files

- `server/.cert` - Federation ML-DSA-65 signing keys (auto-generated on first run)
- `server/.opaque` - OPAQUE server credentials (auto-generated on first run)
- `server/logs/server.log` - Server logs
- `client/public/sw-crypto.js` - Service worker crypto bundle (built during `npm run build`)
