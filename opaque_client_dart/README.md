# opaque_client_dart

A pure Dart implementation of the OPAQUE password-authenticated key exchange (PAKE) protocol (RFC 9497).

This is a port of Cloudflare's [@cloudflare/opaque-ts](https://github.com/cloudflare/opaque-ts) TypeScript library, providing client-side OPAQUE operations for Flutter applications.

## Features

- P-256 elliptic curve for OPRF and key exchange
- SHA-256 for hashing
- HKDF for key derivation
- Scrypt for password hardening
- Compatible with @cloudflare/opaque-ts server implementations

## Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  opaque_client_dart:
    path: ../opaque_client_dart  # Or use git/pub reference
```

## Usage

### Registration

```dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:opaque_client_dart/opaque_client_dart.dart';

// Create client
final config = getOpaqueConfig(OpaqueId.opaqueP256);
final client = OpaqueClient(config);

// Step 1: Start registration
final request = client.registerInit(password);
final requestBytes = Uint8List.fromList(request.serialize());
// Send base64.encode(requestBytes) to server

// Step 2: Receive server response and finish
final responseBytes = base64.decode(serverResponseBase64);
final response = RegistrationResponse.deserialize(config, responseBytes.toList());
final result = client.registerFinish(response);
final recordBytes = Uint8List.fromList(result.record.serialize());
// Send base64.encode(recordBytes) to server to complete registration
```

### Login

```dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:opaque_client_dart/opaque_client_dart.dart';

// Create client
final config = getOpaqueConfig(OpaqueId.opaqueP256);
final client = OpaqueClient(config);

// Step 1: Start login
final ke1 = client.authInit(password);
final ke1Bytes = Uint8List.fromList(ke1.serialize());
// Send base64.encode(ke1Bytes) to server

// Step 2: Receive server response and finish
final ke2Bytes = base64.decode(serverKe2Base64);
final ke2 = KE2.deserialize(config, ke2Bytes.toList());
final result = client.authFinish(ke2);
final ke3Bytes = Uint8List.fromList(result.ke3.serialize());
// Send base64.encode(ke3Bytes) to server

// Use result.sessionKey for encryption
// Use result.exportKey for deriving additional keys
```

## API Reference

### OpaqueClient

The main client class for OPAQUE operations.

- `registerInit(String password)` - Start the registration flow
- `registerFinish(RegistrationResponse response)` - Complete registration
- `authInit(String password)` - Start the login flow
- `authFinish(KE2 ke2)` - Complete login and get session key

### Configuration

- `getOpaqueConfig(OpaqueId.opaqueP256)` - Get P-256 OPAQUE configuration

### Message Types

- `RegistrationRequest` - Client's first registration message
- `RegistrationResponse` - Server's registration response
- `RegistrationRecord` - Final registration record to store on server
- `KE1` - Client's first login message
- `KE2` - Server's login response
- `KE3` - Client's final login message

## Security

OPAQUE is a secure password-authenticated key exchange protocol that:

- Never sends the password to the server (not even hashed)
- Uses oblivious pseudorandom functions (OPRF) for password blinding
- Provides mutual authentication between client and server
- Derives a shared session key for secure communication

## License

BSD-3-Clause License - see [LICENSE](LICENSE) for details.

Original TypeScript implementation copyright (c) 2021 Cloudflare, Inc.
