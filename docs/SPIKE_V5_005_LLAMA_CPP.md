# SPIKE V5-005 — llama-cpp-2 (v5 claim: local GGUF inference + Vulkan/Adreno)

Date: 2026-10-23. Authorised by Richard: "move to the hard spikes" (2026-10-23).
Location: `spikes/v5_005_llama_cpp/` — isolated crate, NOT a dependency of `rich_gang_ai_core`. Core/flutter/staged .so untouched.
STATUS: **COMPLETE — verdict below.**

## Verified before coding
- The v5 spec names `llama-cpp-rs`. On docs.rs/crates.io that project (utilityai/llama-cpp-rs) ships as crate **`llama-cpp-2`**; a different crate `llama_cpp` 0.3.2 (edgenai) and a fork line `llama-cpp-4` also exist — neither is the named project.
- docs.rs llama-cpp-2 lib.rs source verified: real APIs `llama_cpp_2::llama_backend::LlamaBackend::init()`, `llama_time_us()`, `max_devices()`, `mmap_supported()` (its own doctests use init + time). Underlying sys crate `llama-cpp-sys-2` generates bindings with bindgen and compiles llama.cpp C++ via cmake.
- Cargo.lock (this spike): **llama-cpp-2 0.1.160 + llama-cpp-sys-2 0.1.160** (newer patch than the 0.1.125 docs snapshot — lock is the build's truth).
- Environment (checked 2026-10-23, main-agent preflight + own checks): cmake 3.28.3, gcc, g++, make, pkg-config present. **Host clang/clang++ MISSING, ninja MISSING, glslc MISSING, Vulkan headers MISSING** (no /usr/include/vulkan; no NDK vulkan sources). No system libclang (bindgen blocker, see attempts). NDK r27 ships libclang.so + clang 18 builtin headers under its LLVM tree. VM: 2 cores, ~7.7 GiB RAM total — heavy builds run at CARGO_BUILD_JOBS=1 / CMAKE_BUILD_PARALLEL_LEVEL=1 per preflight.
- NO model file exists in this environment and none may be downloaded: **inference is out of scope for this spike**. Only compile/link/backend-init are tested.

## What was built in the spike
Minimal lib: `backend_probe()` = LlamaBackend::init() then (llama_time_us, max_devices, mmap_supported); one test asserting init succeeds and time > 0 (second init accepts Ok or the crate's documented-benign BackendAlreadyInitialized).

## Results so far (exact)
- Attempt 1 (host `cargo test`, no env): **FAIL in sys build script** — bindgen 0.72.1 panicked: `Unable to find libclang: "couldn't find any valid shared libraries matching: ['libclang.so', ...], set the LIBCLANG_PATH environment variable..."`. Environment finding, not a crate defect.
- Attempt 2 (LIBCLANG_PATH = NDK musl/lib): bindgen loaded libclang, then **FAIL** — `ggml.h:211:10: fatal error: 'stdbool.h' file not found` (libclang could not locate clang builtin headers from the musl lib path).
- Attempt 3 (+ BINDGEN_EXTRA_CLANG_ARGS=-I<NDK>/lib/clang/18/include): bindgen **SUCCEEDED** (out/bindings.rs generated — verified on disk), cmake C++ compile started (wrapper_common.o produced — verified on disk), then the **service restarted mid-build and killed it**. Incomplete — not a pass, not a crate failure.
- Attempt 4 (post-preflight restart, CARGO_BUILD_JOBS=1 / CMAKE_BUILD_PARALLEL_LEVEL=1, same LIBCLANG_PATH + BINDGEN_EXTRA_CLANG_ARGS): **HOST PASS.** `cargo test` — **1 passed, 0 failed** (`backend_initializes_and_time_advances`), test profile finished in 11m 15s.
  - Same-run artifact verification (exact output): test binary `target/debug/deps/v5_005_llama_cpp_spike-e62556bde237709e` = `ELF 64-bit LSB pie executable, x86-64`, 85M debug; `nm` shows `T llama_backend_init`, `T llama_time_us`, `T ggml_time_us` linked in; cmake-produced `libllama.a` = 140M debug, `libggml.a` = 1.7M debug. (Debug sizes — no release/size claim; but a 140M debug static lib is a loud warning about the size cost of this dependency.)

## Android target — PASS (build level)
Env per the rusqlite-proven pattern plus what this crate's build script demanded, discovered from its exact errors: `ANDROID_NDK` (attempt 1 failed in 68s with build.rs panic: `Android NDK not found. Please set one of: ANDROID_NDK, NDK_ROOT, ANDROID_NDK_ROOT`), NDK API-24 clang as linker/CC/CXX, llvm-ar, `CMAKE_TOOLCHAIN_FILE=<NDK>/build/cmake/android.toolchain.cmake`, `ANDROID_ABI=arm64-v8a`, `ANDROID_PLATFORM=android-24`, bindgen args `--target=aarch64-linux-android24 --sysroot=<NDK sysroot>` + clang-18 builtin headers, jobs=1.
- Result: `cargo build --target aarch64-linux-android` — **Finished in 10m 39s, exit 0** (llama-cpp-sys-2 C++ compiled with `--target=aarch64-none-linux-android24`).
- Same-run artifact verification (exact): spike rlib `target/aarch64-linux-android/debug/libv5_005_llama_cpp_spike.rlib` exists (101K debug); Android `libllama.a` exists (74M debug); object extracted from it (`llama.cpp.o`) = `ELF 64-bit LSB relocatable, ARM aarch64` per `file`, and llvm-readelf header `Class: ELF64 / Machine: AArch64`. Compile-level only — nothing executed on Android.

## Vulkan probe (separately labelled, per preflight) — ENVIRONMENT FAILURE, as predicted
One short host probe, `cargo check --features llama-cpp-2/vulkan` (feature verified present in both crates' Cargo.toml): cmake configure with `-DGGML_VULKAN=ON` failed immediately:
`CMake Error ... Could NOT find Vulkan (missing: Vulkan_LIBRARY Vulkan_INCLUDE_DIR glslc)` at `ggml/src/ggml-vulkan/CMakeLists.txt:9 (find_package)`.
This VM has no Vulkan SDK (no headers, no glslc, no loader lib), so the Vulkan backend **cannot even configure here**. Recorded as an environment finding, NOT a crate verdict: it says nothing about whether ggml-vulkan would work on Richard's Adreno device with a proper SDK/toolchain — that question needs the Android Vulkan path (NDK + shader toolchain) tested separately, and ultimately a device run.

## Verdict
**PASS — spike level only, CPU backend, compile/link/init level.**
llama-cpp-2 0.1.160 compiles from C++ source and links in this VM (host test 1/1 with real backend init) and cross-builds fully for aarch64-linux-android with the NDK toolchain env above. The three environment traps (libclang, clang builtin headers, ANDROID_NDK) are each documented with their exact errors and fixes. **Vulkan/Adreno: UNPROVEN — blocked in this environment at cmake configure (no Vulkan SDK).**

## What this does NOT prove (regardless of outcome)
- No model loaded, no token generated — local GGUF inference itself is unproven until a real model file exists and a session decodes.
- CPU-default build says nothing about Adreno/Vulkan GPU acceleration on Richard's A16.
- Not integrated, not device-verified; size/startup cost of the static llama.cpp library in libdaemon.so is unmeasured.
