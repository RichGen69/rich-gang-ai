#!/bin/bash
# Rich Gang AI — release gate (Richard's "prevent errors" directive, 2026-10-23).
#
# WHY THIS EXISTS: on 2026-10-23 the rusqlite integration updated Rust,
# the FFI header, and the Dart bridge — but the staged libdaemon.so was
# still the previous day's build without the new rga_store_* exports,
# while NativeBridge looks every symbol up unconditionally at boot.
# Every test suite was green and the shipped binary was still wrong.
# Suites alone don't catch a stale artifact. This gate does.
#
# Run it after ANY change to rich_gang_ai_core/ or native_bridge.dart,
# before calling a build integrated / staged / ready. It FAILS (exit 1)
# if any check fails. It never rebuilds or fixes anything itself —
# it reports, a human/agent decides.
#
# Usage: tools/release_gate.sh [--suites]   (--suites also runs
#        cargo test + flutter analyze + flutter test; slow but full)
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAGED="$ROOT/flutter_app/android/app/src/main/jniLibs/arm64-v8a/libdaemon.so"
BUILT="$ROOT/rich_gang_ai_core/target/aarch64-linux-android/release/libdaemon.so"
NDK_HOME="${ANDROID_NDK_HOME:-$HOME/workspace/toolchain/android-ndk-r27}"
LLVM_BIN="$NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin"
FAIL=0

note() { echo "[gate] $*"; }
bad()  { echo "[gate] FAIL: $*"; FAIL=1; }

# --- 1. Staged .so is byte-identical to the last release build -------
# A difference means someone changed Rust and forgot to restage —
# exactly the 2026-10-23 bug. (If no release build exists, that's a
# failure too: nothing verifiable is staged.)
if [ ! -f "$STAGED" ]; then
  bad "staged libdaemon.so missing: $STAGED"
elif [ ! -f "$BUILT" ]; then
  bad "no aarch64 release build at $BUILT — staged .so cannot be proven fresh"
else
  S1=$(sha256sum "$STAGED" | awk '{print $1}')
  S2=$(sha256sum "$BUILT" | awk '{print $1}')
  if [ "$S1" = "$S2" ]; then
    note "OK freshness: staged .so == last release build ($S1)"
  else
    bad "STALE staged .so: staged=$S1 built=$S2 — rebuild + restage before proceeding"
  fi
fi

if [ -f "$STAGED" ]; then
  EXPORTS=$("$LLVM_BIN/llvm-nm" -D "$STAGED" 2>/dev/null | awk '{print $NF}' | sort -u)

  # --- 2. Every FFI export declared in Rust exists in the .so --------
  RUST_EXPORTS=$(grep -o "pub extern \"C\" fn [a-z_]*" "$ROOT/rich_gang_ai_core/src/ffi.rs" \
                 | awk '{print $NF}' | sort -u)
  # JNI exports live in jni_bridge.rs as Java_* fns.
  JNI_EXPORTS=$(grep -o "Java_[A-Za-z_]*" "$ROOT/rich_gang_ai_core/src/jni_bridge.rs" \
                | sort -u)
  for sym in $RUST_EXPORTS $JNI_EXPORTS; do
    echo "$EXPORTS" | grep -qx "$sym" || bad "export declared in Rust but MISSING from staged .so: $sym"
  done
  note "OK exports: $(echo "$EXPORTS" | grep -c '^rga_\|^Java_') dynamic rga_*/Java_* symbols in staged .so"

  # --- 3. Every Dart NativeBridge lookup resolves in the .so ---------
  DART_LOOKUPS=$(grep -o "'rga_[a-z_]*'" "$ROOT/flutter_app/lib/core/native_bridge.dart" \
                 | tr -d "'" | sort -u)
  for sym in $DART_LOOKUPS; do
    echo "$EXPORTS" | grep -qx "$sym" || bad "Dart lookups '$sym' but staged .so does not export it — app would fail at boot"
  done
  note "OK dart: all $(echo "$DART_LOOKUPS" | grep -c .) NativeBridge lookups resolve"

  # --- 4. 16 KB alignment on every LOAD segment ----------------------
  if "$LLVM_BIN/llvm-readelf" -l "$STAGED" | grep LOAD | grep -vq "0x4000"; then
    bad "a LOAD segment is not Align 0x4000 in staged .so"
  else
    note "OK alignment: all LOAD segments Align 0x4000"
  fi

  # --- 5. ABI consistency: Rust ABI_VERSION == Dart expectedAbi ------
  RUST_ABI=$(grep -o "ABI_VERSION: u32 = [0-9]*" "$ROOT/rich_gang_ai_core/src/ffi.rs" | grep -o "[0-9]*$")
  DART_ABI=$(grep -o "expectedAbi = [0-9]*" "$ROOT/flutter_app/lib/core/native_bridge.dart" | grep -o "[0-9]*$")
  if [ "$RUST_ABI" = "$DART_ABI" ]; then
    note "OK abi: Rust $RUST_ABI == Dart $DART_ABI"
  else
    bad "ABI mismatch: Rust=$RUST_ABI Dart=$DART_ABI"
  fi
fi

# --- 6. Optional: full suites -----------------------------------------
if [ "${1:-}" = "--suites" ]; then
  # shellcheck disable=SC1091
  source "$HOME/workspace/flutter_env.sh"
  ( cd "$ROOT/rich_gang_ai_core" && cargo test >/tmp/gate_cargo.log 2>&1 ) \
    && note "OK cargo: $(grep -o '[0-9]* passed' /tmp/gate_cargo.log | head -1)" \
    || bad "cargo test failed (see /tmp/gate_cargo.log)"
  ( cd "$ROOT/flutter_app" && flutter analyze >/tmp/gate_analyze.log 2>&1 ) \
    && note "OK analyze: clean" || bad "flutter analyze failed (see /tmp/gate_analyze.log)"
  ( cd "$ROOT/flutter_app" && flutter test >/tmp/gate_flutter.log 2>&1 ) \
    && note "OK flutter test: $(grep -o 'All tests passed' /tmp/gate_flutter.log | head -1)" \
    || bad "flutter test failed (see /tmp/gate_flutter.log)"
fi

if [ "$FAIL" = 0 ]; then
  echo "[gate] PASS — all checks green"
else
  echo "[gate] FAIL — do not call this build integrated/staged/ready until fixed"
fi
exit $FAIL
