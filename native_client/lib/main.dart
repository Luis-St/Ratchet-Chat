import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/services/pq_crypto_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize post-quantum cryptography library
  PqCryptoService.initialize();

  runApp(const ProviderScope(child: App()));
}
