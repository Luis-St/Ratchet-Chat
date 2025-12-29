# Flutter Client Setup Guide

## Overview

This document outlines the requirements and setup for implementing a native Flutter client for Ratchet-Chat.

## Package Availability

| Component | Package | Status |
|-----------|---------|--------|
| Post-Quantum (ML-KEM, ML-DSA) | [`liboqs`](https://pub.dev/packages/liboqs) | Ready |
| WebAuthn/Passkeys | [`passkeys`](https://pub.dev/packages/passkeys) | iOS 16+, Android 28+ |
| Socket.IO | [`socket_io_client`](https://pub.dev/packages/socket_io_client) | Ready |
| WebRTC | [`flutter_webrtc`](https://pub.dev/packages/flutter_webrtc) | Ready |
| Local DB | `sqflite` or `isar` | Ready |
| Secure Storage | `flutter_secure_storage` | Ready |

## Blocker: No OPAQUE Package

There is no Dart/Flutter OPAQUE implementation. Options to resolve:

1. **FFI binding** - Wrap [`opaque-ke`](https://github.com/facebook/opaque-ke) (Rust) via `flutter_rust_bridge`
2. **Port from JS** - Translate `@cloudflare/opaque-ts` to Dart (complex)
3. **Server change** - Add alternative auth (SRP or plain password with Argon2)

## Project Setup

```bash
flutter create ratchet_chat_client
cd ratchet_chat_client
```

### Dependencies (pubspec.yaml)

```yaml
dependencies:
  flutter:
    sdk: flutter

  # Crypto
  liboqs: ^0.0.5              # ML-KEM-768, ML-DSA-65
  pointycastle: ^3.9.1        # AES-GCM, PBKDF2

  # Auth (requires OPAQUE solution first)
  passkeys: ^2.0.3            # WebAuthn/Passkeys

  # Networking
  socket_io_client: ^2.0.3    # Socket.IO
  http: ^1.2.0                # REST API

  # WebRTC
  flutter_webrtc: ^0.9.47

  # Storage
  sqflite: ^2.3.0             # Local database
  flutter_secure_storage: ^9.0.0

  # Utils
  uuid: ^4.2.1
```

## Platform Configuration

### Android

Edit `android/app/build.gradle`:

```gradle
android {
    defaultConfig {
        minSdkVersion 28  // Required for passkeys + WebRTC
    }
}
```

### iOS

Edit `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Camera for video calls</string>
<key>NSMicrophoneUsageDescription</key>
<string>Microphone for calls</string>
```

## Recommended Development Order

1. **Solve OPAQUE first** - Use `flutter_rust_bridge` to wrap Rust `opaque-ke` crate
2. Implement crypto layer (ML-KEM, ML-DSA, AES-GCM)
3. Implement auth flow (registration, login, passkeys)
4. Implement messaging (send, receive, vault sync)
5. Implement WebRTC calling
6. Implement federation support

## Resources

- [liboqs Dart package](https://pub.dev/packages/liboqs)
- [passkeys Flutter package](https://pub.dev/packages/passkeys)
- [socket_io_client](https://pub.dev/packages/socket_io_client)
- [flutter_webrtc](https://pub.dev/packages/flutter_webrtc)
- [flutter_rust_bridge](https://github.com/aspect-dev/aspect-cli)
