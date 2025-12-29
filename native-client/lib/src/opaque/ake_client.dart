// Copyright (c) 2021 Cloudflare, Inc. and contributors.
// Ported to Dart for Ratchet-Chat Flutter client.
// Licensed under the BSD-3-Clause license.

import 'dart:typed_data';

import 'common.dart';
import 'config.dart';
import 'messages.dart';
import 'util.dart';

/// 3DH Authenticated Key Exchange client.
class Ake3DHClient {
  final OpaqueConfig config;
  Uint8List? _clientSecret;

  Ake3DHClient(this.config);

  /// Start the AKE handshake.
  AuthInit start() {
    final clientNonce = Uint8List.fromList(config.prng.random(config.constants.Nn));
    final keyPair = config.ake.generateAuthKeyPair();
    _clientSecret = keyPair.privateKey;
    return AuthInit(
      clientNonce: clientNonce,
      clientKeyshare: keyPair.publicKey,
    );
  }

  /// Finalize the AKE handshake.
  ///
  /// Returns the auth finish message and session key, or throws on error.
  ({AuthFinish authFinish, Uint8List sessionKey}) finalize({
    required Uint8List clientIdentity,
    required Uint8List clientPrivateKey,
    required Uint8List serverIdentity,
    required Uint8List serverPublicKey,
    required KE1 ke1,
    required KE2 ke2,
    required Uint8List context,
  }) {
    if (_clientSecret == null) {
      throw StateError('AKE client has not started yet');
    }

    // Compute Triple-DH IKM
    final ikm = tripleDhIkm(config, [
      (sk: _clientSecret!, pk: ke2.authResponse.serverKeyshare),
      (sk: _clientSecret!, pk: serverPublicKey),
      (sk: clientPrivateKey, pk: ke2.authResponse.serverKeyshare),
    ]);

    // Build preamble
    final preamble = preambleBuild(
      ke1,
      ke2,
      serverIdentity,
      clientIdentity,
      context,
    );

    // Derive keys
    final keys = deriveKeys(config, ikm, preamble);

    // Verify server MAC
    final hPreamble = config.hash.sum(preamble);
    final serverMacValid = config.mac.withKey(keys.km2).verify(
      hPreamble,
      ke2.authResponse.serverMac,
    );

    if (!serverMacValid) {
      throw Exception('Handshake error: invalid server MAC');
    }

    // Compute client MAC
    final hmacData = config.hash.sum(joinAll([
      preamble,
      ke2.authResponse.serverMac,
    ]));
    final clientMac = config.mac.withKey(keys.km3).sign(hmacData);
    final authFinish = AuthFinish(clientMac: clientMac);

    // Clean up
    _clientSecret = null;

    return (authFinish: authFinish, sessionKey: keys.sessionKey);
  }
}
