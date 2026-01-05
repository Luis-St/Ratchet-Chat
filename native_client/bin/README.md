# liboqs Native Libraries

This directory contains prebuilt liboqs libraries for post-quantum cryptography (ML-KEM-768, ML-DSA-65).

## Included Platforms

| Platform | File | Status |
|----------|------|--------|
| Windows x64 | `windows/oqs.dll` | Included |
| Linux x64 | `linux/liboqs.so` | Included |
| Android arm64-v8a | `../android/app/src/main/jniLibs/arm64-v8a/liboqs.so` | Included |
| Android armeabi-v7a | `../android/app/src/main/jniLibs/armeabi-v7a/liboqs.so` | Included |
| Android x86_64 | `../android/app/src/main/jniLibs/x86_64/liboqs.so` | Included |
| Android x86 | `../android/app/src/main/jniLibs/x86/liboqs.so` | Included |
| macOS | - | Manual setup required |
| iOS | - | Manual setup required |

## macOS Setup

Install liboqs via Homebrew:

```bash
brew install liboqs
```

The library will be installed to `/opt/homebrew/lib/liboqs.dylib` (Apple Silicon) or `/usr/local/lib/liboqs.dylib` (Intel).

### For Distribution

To bundle for macOS distribution, copy the dylib to your app bundle:

```bash
# After building
cp /opt/homebrew/lib/liboqs.dylib build/macos/Build/Products/Release/native_client.app/Contents/Frameworks/

# Fix the library path
install_name_tool -id @executable_path/../Frameworks/liboqs.dylib \
  build/macos/Build/Products/Release/native_client.app/Contents/Frameworks/liboqs.dylib
```

## iOS Setup

iOS requires building liboqs from source as a static library or framework.

### Build from Source

```bash
# Clone liboqs
git clone https://github.com/open-quantum-safe/liboqs.git
cd liboqs

# Build for iOS (requires Xcode)
mkdir build-ios && cd build-ios
cmake .. \
  -DCMAKE_TOOLCHAIN_FILE=../cmake/toolchain-ios.cmake \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=OFF \
  -DOQS_BUILD_ONLY_LIB=ON

make -j$(sysctl -n hw.ncpu)
```

### Add to Xcode Project

1. Copy `liboqs.a` to `ios/Frameworks/`
2. In Xcode, add the library to "Link Binary With Libraries"
3. Add the header path to "Header Search Paths"

## Library Version

These binaries are from liboqs v0.14.0, which includes:
- ML-KEM-512, ML-KEM-768, ML-KEM-1024 (FIPS 203)
- ML-DSA-44, ML-DSA-65, ML-DSA-87 (FIPS 204)

## Source

Prebuilt binaries from: https://github.com/bardiakz/liboqs-prebuilt-binaries-v0.14.0

## Updating Libraries

To update to a newer version:

1. Download new binaries or build from source
2. Replace files in this directory
3. Update Android jniLibs in `android/app/src/main/jniLibs/`
4. Test on all platforms
