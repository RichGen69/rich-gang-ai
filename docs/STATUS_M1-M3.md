# Rich Gang AI — Milestones 1–3 Status Report

Date: 2026-10-20 (updated later the same day). Reporting format follows
master prompt Section 9.
Honest headline: **source for Milestones 1–3 exists; the Rust core is now
compiled and unit-tested in this VM (17/17 host tests, clean
`cargo check --target aarch64-linux-android`); Dart/Kotlin are still
uncompiled (no Flutter SDK or Android NDK here), the Flutter project
cannot build as-is yet, and nothing is device-verified.**

## What was built (already present in the workspace — audited, not rewritten)

Rust core (`rich_gang_ai_core/`):
- `Cargo.toml` exactly per spec: cdylib `daemon`, panic=unwind, LTO,
  strip=debuginfo, jni 0.21, cbindgen build-dep, env_logger off-Android.
- `.cargo/config.toml` with 16 KB page alignment flags; `rust-toolchain.toml`
  pinning aarch64-linux-android; `build.rs` generating `include/daemon.h`.
- `handle.rs`: live-handle registry (register / is_live / unregister).
- `ffi.rs`: all seven required `rga_*` functions, serde_json-only JSON,
  catch_unwind everywhere, ownership contract documented, unit tests for
  ABI/version, query round-trip, unknown persona, invalid handle, tick
  counting, idempotent stop. Logs `[RICHARD] daemon online` on start.
- `jni_bridge.rs`: four static JNI methods for DreamCycleService, JClass
  signatures, catch_unwind returning -1/null.
- `scene.rs` (validator + clamping), `facts.rs` (per-witness FactTable),
  `vector.rs` (in-memory vector store abstraction), `logging.rs`.

Kotlin (`flutter_app/android/.../com/richgang/ai/`):
- `DreamCycleService.kt`: startForeground BEFORE nativeBoot, specialUse type,
  15-min tick loop logging `tick=N`, nativeStop in onDestroy.
- `MainActivity.kt`: POST_NOTIFICATIONS gate on API 33+ before starting the
  service; no start on denial.
- `BootReceiver.kt` + `DreamArmWorker.kt`: two-stage boot re-arm via
  expedited WorkManager. Manifest declares BOOT_COMPLETED only.
- `AndroidManifest.xml`: all nine required permissions, networkSecurityConfig
  set, specialUse service with the required subtype property.
- `network_security_config.xml`: cleartext only for 127.0.0.1 / localhost /
  10.0.2.2.

Dart (`flutter_app/lib/`):
- `NativeBridge.dart`: ABI check against expectedAbi=1, idempotent
  boot/shutdown, all FFI pointers freed in finally blocks (malloc.free for
  Dart allocations, rga_string_free for Rust returns).
- Plus the later-milestone surface already drafted: InferenceRouter with the
  spec's task table, 30 s health-cache, backoff and 38 RPM limiter;
  SecureKeys on flutter_secure_storage; RoomRateController on
  flutter_displaymode; Settings with trust dial / quiet hours / kill switch;
  Room / Chat / Interrogation / Dream Broadcast / Settings views.

## What was verified

- Section 8 verification pass — see `docs/VERIFY.md`. Headlines:
  flutter_secure_storage is the right store; flutter_displaymode is the real
  refresh-rate API (`RefreshRate.setPreferredRate` does not exist);
  Ollama `/v1` is real; NVIDIA's credit system appears replaced by
  rate-limit-only trial access (~40 RPM), so the 402/cooldown branch needs a
  dashboard check; the spec's jni `.into()` claim is contradicted by
  docs.rs 0.21.1 (code is safe either way).
- Static audit of every Rust / Kotlin / Dart file named above against the
  spec, line by line.

## What was NOT verified (explicit)

- PARTIALLY compiled (corrected 2026-10-20): Rust 1.99.1 was installed in
  this VM after the first audit. `cargo test` passes on the host (17/17)
  and `cargo check --target aarch64-linux-android` is clean, which settles
  the jni_bridge compile question. Still never run: a full Android link
  (needs the NDK), `flutter build apk` (no Flutter/Dart/Java in this VM).
- NOT run on a device. Milestones 1, 2 and 3 have zero on-device evidence:
  no logcat showing `[RICHARD] daemon online`, no `tick=1 / tick=2`, no
  reboot-survival test. Per Section 9, none of them can be called complete.
- 16 KB LOAD alignment and `rga_` / `Java_com_richgang` symbol exports are
  unchecked (no .so exists; jniLibs/arm64-v8a is empty).

## Blockers and gaps found in audit

1. **Flutter project is source-only.** Missing: all Gradle files
   (settings/build/gradle.properties/wrapper), `android/app/build.gradle(.kts)`
   (so the WorkManager dependency exists only in comments), `styles.xml`
   (manifest references `@style/LaunchTheme` / NormalTheme), launcher icons
   (`@mipmap/ic_launcher`), `analysis_options.yaml`. Fix on a machine with
   Flutter: run `flutter create .` inside flutter_app to regenerate the
   scaffolding, then re-apply the manifest/Kotlin files and add
   `implementation("androidx.work:work-runtime-ktx:2.12.0")`.
2. **Milestone 2 timing (audit correction):** an earlier version of this
   report claimed the DreamCycleService loop sleeps 15 minutes BEFORE its
   first tick. That was a misread — the loop ticks first, then sleeps, so
   `tick=1` will appear at service start. `tick=2` legitimately takes
   15 minutes; for a faster M2 device check, temporarily shorten TICK_MS
   and restore it afterwards.
3. **DreamArmWorker fragility — FIXED 2026-10-20:** `doWork()` now wraps
   `startForegroundService` in try/catch, logs
   ForegroundServiceStartNotAllowedException / other failures loudly, and
   returns `Result.failure()` instead of crashing the worker.
4. **Two daemon handles, one process:** NativeBridge (Dart FFI) and
   DreamCycleService (JNI) each call daemon_start and get separate Daemon
   instances — separate scene, tick counter and vector store — because the
   service runs in the app process by default. Fine for M1–M3 evidence, but
   dream-cycle consolidation would not see UI-side memory. Design decision
   needed before Milestone 10, not before M1.
5. **Only 3 of 7 personas are named anywhere.** Code defaults to Leo,
   Capricorn, Aquarius (from the Room material) and accepts the rest via the
   config JSON `personas` array. Richard: supply the other four names.
6. **NVIDIA terms drift — code FIXED 2026-10-20, dashboard check still
   open.** The misleading credits/24h-lockout branch was replaced with
   `NvidiaAccountBlocked` + a bounded 1-hour back-off that a key change
   clears (see VERIFY.md). No code now depends on the credit story; still
   check the real dashboard before Milestone 5 for your account's terms.

## Corrections applied 2026-10-20 (the "misled" fixes)

Full table in `docs/VERIFY.md`. In code: `RoomRateController` rebuilt on
the real flutter_displaymode API with same-resolution mode selection and
recorded thermal state; NVIDIA 402/403 handling replaced (gap 6);
`DreamArmWorker` failure handling (gap 3); both inference providers now
throw `UnsupportedError` on a GBNF grammar request instead of forwarding
a guessed `grammar` field to an OpenAI-compatible endpoint; WorkManager
comment pin updated 2.9.0 → 2.12.0. Rust: `cargo test` 17/17 and
`cargo check --target aarch64-linux-android` clean after all edits.

## Next milestone

Milestone 1 only, on Richard's dev machine + a real Android device:
install Rust + Flutter + Android SDK/NDK, regenerate Flutter scaffolding
(gap 1), run `build_android.sh`, run the Section 6 readelf/nm checks, install
the APK, and capture `adb logcat -s RGA.Rust` showing the daemon online line.
Report that logcat output before touching Milestone 2's reboot test.
