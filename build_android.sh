#!/bin/bash
# Rich Gang AI — full Android build pipeline (2026).
# 1. Cross-compile the Rust daemon for aarch64-linux-android (release).
# 2. Stage libdaemon.so into the Flutter app's jniLibs.
# 3. Verify 16 KB alignment + FFI/JNI symbol exports (spec Section 6).
# 4. Build the release APK.
#
# NDK linker: cargo needs an Android clang linker for the target. This
# script auto-detects, in order: $ANDROID_NDK_HOME, the sdkmanager NDK
# under $ANDROID_HOME/ndk/*, and ~/workspace/toolchain/android-ndk-r27
# (the layout used by the 2026-10-20 VM build, docs/BUILD_2026-10-20.md).
# Set MIN_API to override the API level used for the clang triple (24).
set -e
cd "$(dirname "$0")"
MIN_API="${MIN_API:-24}"

NDK_HOME="${ANDROID_NDK_HOME:-}"
if [ -z "$NDK_HOME" ] && [ -n "${ANDROID_HOME:-}" ]; then
  for d in "$ANDROID_HOME"/ndk/*; do [ -d "$d" ] && NDK_HOME="$d" && break; done
fi
if [ -z "$NDK_HOME" ] && [ -d "$HOME/workspace/toolchain/android-ndk-r27" ]; then
  NDK_HOME="$HOME/workspace/toolchain/android-ndk-r27"
fi
if [ -z "$NDK_HOME" ]; then
  echo "ERROR: no Android NDK found. Install NDK r27+ or set ANDROID_NDK_HOME." >&2
  exit 1
fi
LLVM_BIN="$NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin"
CLANG="$LLVM_BIN/aarch64-linux-android${MIN_API}-clang"
echo "[+] NDK: $NDK_HOME (API $MIN_API clang)"

cd rich_gang_ai_core
rustup target add aarch64-linux-android
CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER="$CLANG" \
CC_aarch64_linux_android="$CLANG" \
CXX_aarch64_linux_android="$LLVM_BIN/aarch64-linux-android${MIN_API}-clang++" \
AR_aarch64_linux_android="$LLVM_BIN/llvm-ar" \
  cargo build --target aarch64-linux-android --release

TARGET_DIR="../flutter_app/android/app/src/main/jniLibs/arm64-v8a"
mkdir -p "$TARGET_DIR"
cp target/aarch64-linux-android/release/libdaemon.so "$TARGET_DIR/"
echo "[✓] libdaemon.so staged"

SO="$TARGET_DIR/libdaemon.so"
echo "--- LOAD alignment (every LOAD segment must be Align 0x4000) ---"
"$LLVM_BIN/llvm-readelf" -l "$SO" | grep LOAD
echo "--- FFI + JNI symbols ---"
"$LLVM_BIN/llvm-nm" -D "$SO" | grep -E " rga_| Java_com_richgang" 
sha256sum "$SO"

cd ../flutter_app
flutter pub get
flutter build apk --release
echo "[✓] APK built: build/app/outputs/flutter-apk/app-release.apk"
