// Copyright (c) 2021 Cloudflare, Inc. and contributors.
// Ported to Dart for Ratchet-Chat Flutter client.
// Licensed under the BSD-3-Clause license.

/// OPAQUE Password-Authenticated Key Exchange (PAKE) implementation.
///
/// This is a pure Dart port of @cloudflare/opaque-ts, providing
/// password-authenticated key exchange using the OPAQUE protocol (RFC 9497).
///
/// ## Features
/// - P-256 elliptic curve for OPRF and key exchange
/// - SHA-256 for hashing
/// - HKDF for key derivation
/// - Scrypt for password hardening
/// - Compatible with @cloudflare/opaque-ts server implementations
///
/// ## Usage
///
/// ### Registration
/// ```dart
/// import 'package:opaque_client_dart/opaque_client_dart.dart';
///
/// final config = getOpaqueConfig(OpaqueId.opaqueP256);
/// final client = OpaqueClient(config);
///
/// // Step 1: Start registration
/// final request = client.registerInit(password);
/// final requestBytes = Uint8List.fromList(request.serialize());
/// // Send base64.encode(requestBytes) to server
///
/// // Step 2: Receive server response
/// final responseBytes = base64.decode(serverResponseBase64);
/// final response = RegistrationResponse.deserialize(config, responseBytes.toList());
/// final result = client.registerFinish(response);
/// final recordBytes = Uint8List.fromList(result.record.serialize());
/// // Send base64.encode(recordBytes) to server to complete registration
/// ```
///
/// ### Login
/// ```dart
/// final config = getOpaqueConfig(OpaqueId.opaqueP256);
/// final client = OpaqueClient(config);
///
/// // Step 1: Start login
/// final ke1 = client.authInit(password);
/// final ke1Bytes = Uint8List.fromList(ke1.serialize());
/// // Send base64.encode(ke1Bytes) to server
///
/// // Step 2: Receive server response and finish
/// final ke2Bytes = base64.decode(serverKe2Base64);
/// final ke2 = KE2.deserialize(config, ke2Bytes.toList());
/// final result = client.authFinish(ke2);
/// final ke3Bytes = Uint8List.fromList(result.ke3.serialize());
/// // Send base64.encode(ke3Bytes) to server
/// // Use result.sessionKey for encryption
/// ```
library opaque_client_dart;

export 'src/config.dart' show OpaqueId, OpaqueConfig, getOpaqueConfig;
export 'src/crypto.dart' show MemHardFn, ScryptMemHardFn, IdentityMemHardFn;
export 'src/messages.dart'
    show
        Envelope,
        RegistrationRequest,
        RegistrationResponse,
        RegistrationRecord,
        CredentialRequest,
        CredentialResponse,
        AuthInit,
        AuthResponse,
        AuthFinish,
        KE1,
        KE2,
        KE3;
export 'src/opaque_client.dart'
    show OpaqueClient, OpaqueClientState, RegistrationResult, LoginResult;
