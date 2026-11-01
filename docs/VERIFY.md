# Rich Gang AI — Section 8 Verification Log

Checked: 2026-10-20 (America/Chicago), from live pub.dev / docs.rs / vendor docs.
Rule from the master prompt: if an item cannot be verified here, it is marked
UNVERIFIED — do not write code against it.

## Verified

### flutter_secure_storage — USE THIS
- Exists on pub.dev, actively maintained (updated ~35 days before this check;
  current major line is newer than the `^9.0.0` pin in pubspec.yaml — the pin
  is valid, upgrading is a separate decision).
- Android storage is Keystore-backed (RSA + AES), as the spec requires.
- Source: https://pub.dev/packages/flutter_secure_storage
- Code status: `SecureKeys.dart` already uses it correctly. Never
  SharedPreferences, never hardcoded.

### native_encrypted_storage — exists, do NOT switch to it
- It DOES exist on pub.dev: `native_encrypted_storage: ^0.1.0`.
- But: last updated ~313 days before this check, v0.1.0, Android-only,
  single small package. The spec's instinct was wrong about existence and
  right about the conclusion: stay on flutter_secure_storage for an API key.
- Source: https://pub.dev/packages/native_encrypted_storage

### Refresh-rate API — spec's original name was hallucinated, replacement is real
- There is NO `RefreshRate.setPreferredRate`.
- Real package: `flutter_displaymode` (`^0.6.0`, already in pubspec.yaml).
- Real API, confirmed in its Dart API docs:
  - `FlutterDisplayMode.supported` → `Future<List<DisplayMode>>`
  - `FlutterDisplayMode.setPreferredMode(DisplayMode)`
  - `FlutterDisplayMode.setLowRefreshRate()` / `setHighRefreshRate()`
  - Docs state the system may ignore the preferred mode — advisory, as spec says.
- Source: https://pub.dev/documentation/flutter_displaymode/latest/flutter_displaymode/FlutterDisplayMode-class.html
- Code status: `RoomRateController.dart` already uses this API correctly.

### Ollama OpenAI-compatible endpoint — verified
- Base `http://<host>:11434/v1` is correct.
- `POST /v1/chat/completions` and `GET /v1/models` are documented, with
  OpenAI-shaped responses (`choices[0].message.content`).
- Source: https://docs.ollama.com/api/openai-compatibility
- Caveat (from spec, still true): on Android, `127.0.0.1` is the phone itself.
  The user must set a laptop IP or run Ollama in Termux.
- Code status: `OllamaProvider.dart` uses `/models` probe and
  `/chat/completions` correctly. One open note: the `grammar` field it forwards
  is an Ollama-native request field; GBNF-via-OpenAI-compat behaviour for
  interrogation mode (Milestone 9) is NOT yet verified.

### WorkManager — version in code comments is stale
- Code comments pin `androidx.work:work-runtime-ktx:2.9.0`. That version
  exists and works, but the latest stable is 2.12.0 (2026-09-23).
- There is currently NO Gradle file in flutter_app at all (see STATUS), so no
  version is actually in effect yet. When Gradle files are created, use 2.12.0
  unless a Flutter/Gradle compatibility issue forces a pin.
- Source: https://developer.android.com/jetpack/androidx/releases/work

### Android 15 BOOT_COMPLETED / FGS — spec is safe, slightly overstated
- Official Android 15 behaviour changes: BOOT_COMPLETED receivers may not
  launch FGS of types dataSync, camera, mediaPlayback, phoneCall,
  mediaProjection. `specialUse` is NOT in that prohibited list.
- So a direct start of THIS service might not be blocked on that specific
  ground — but background-start restrictions still apply generally, and the
  spec's two-stage path (BootReceiver → expedited WorkManager →
  DreamArmWorker → startForegroundService) remains the safer, correct design.
  Keep it. Do not "simplify" it back to a direct start without device tests.
- Source: https://developer.android.com/about/versions/15/behavior-changes-15?authuser=0

## Contradiction found — jni 0.21 — RESOLVED BY COMPILATION 2026-10-20

- The master prompt states as fact: "`JavaStr` does not implement
  `From<JavaStr> for String` in jni 0.21 and `.into()` will not compile."
- docs.rs for jni 0.21.1 contradicts that: its JNIEnv docs say the returned
  `JavaStr` can be converted with `.into()`, and the crate's own hello-world
  example uses `env.get_string(&input).expect(...).into()` for a String.
- Source: https://docs.rs/jni/0.21.1/jni/
- Resolution: the code in `jni_bridge.rs` uses
  `.map(|j| j.to_string_lossy().into_owned())`, which is safe under either
  reading. KEEP that code.
- UPDATE (later the same day): a Rust toolchain (1.99.1) was installed in
  this VM and the question is now settled by the compiler, not by docs:
  `cargo check --target aarch64-linux-android` PASSES on `jni_bridge.rs`
  exactly as written, and `cargo test` on the host passes (17 tests).
  The spec's `.into()` prohibition remains unproven (docs.rs says it
  works) — but our conversion no longer depends on either claim.

## Changed since the spec was written — NVIDIA

- Spec assumes: 1,000–5,000 trial credits, 40 RPM, and a `402` =
  credits-exhausted path with a 24-hour cooldown.
- Reporting as of Oct 2026 says the credit system has been replaced by
  rate limits: staff quoted in Sept 2025 said the old credit system "has been
  replaced by rate limits for trial usage," limits "vary by model and are not
  published," and a first-hand Oct 1, 2026 account check reported
  "Unlimited API requests without daily limits" with ~40 RPM per key.
- Sources (secondary — NOT NVIDIA's dashboard):
  https://dev.to/klukyanov/kimi-k3-deepseek-and-glm-free-from-nvidia-i-tested-the-claim-and-here-is-the-catch-2m9b
- Practical impact:
  - The 38 RPM client cap in `InferenceRouter` / `RpmLimiter` is still prudent.
  - Endpoint itself is OpenAI-compatible: `https://integrate.api.nvidia.com/v1`
  - FIX APPLIED 2026-10-20 (actual solution, in code): the misleading
    "credits exhausted → 24h lockout until top-up" branch is gone.
    `NvidiaProvider` now throws `NvidiaAccountBlocked(statusCode)` for
    402 / account-level 403 — a name that says only what the wire says.
    `InferenceRouter` falls back to Ollama immediately and backs off for
    a bounded 1 hour, then re-probes; entering a new key in Settings
    clears the back-off via `clearNvidiaCooldown()`. Richard's own
    dashboard check is still the only way to learn his account's real
    terms — that remains UNVERIFIED here, and no code now depends on it.

## Corrections applied 2026-10-20 — "fix where I was misled"

| Item that misled | What is actually true | Actual solution now in code |
|---|---|---|
| `RefreshRate.setPreferredRate()` | No such method in any package. Real API: `flutter_displaymode` — `FlutterDisplayMode.supported / active / setPreferredMode(DisplayMode) / setLowRefreshRate()` | `RoomRateController` rewritten on flutter_displaymode; mode choice prefers the active resolution (rate-only matching could switch resolution), never selects >60 Hz, thermal state is recorded so shader suspension reads the same source |
| `native_encrypted_storage` "does it exist?" | It exists (^0.1.0) but is small, ~313 days stale, Android-only | Stay on `flutter_secure_storage` (verified, Keystore-backed) — `SecureKeys` unchanged |
| NVIDIA trial credits (1,000–5,000) + `402` = credits exhausted + 24h cooldown | Credits appear replaced by unpublished per-model rate limits (~40 RPM); a 402 does not prove a credit balance | `NvidiaAccountBlocked` + bounded 1h back-off + re-probe + key-change clears it (above) |
| jni 0.21 "`.into()` will not compile" | docs.rs 0.21.1 shows `.into()` used for exactly this conversion; claim unproven either way from docs alone | Settled by compiler: `cargo check --target aarch64-linux-android` passes on the `to_string_lossy().into_owned()` code as written |
| GBNF `grammar` field silently forwarded to NVIDIA/Ollama `/v1` | Neither OpenAI-compatible endpoint documents a `grammar` field; forwarding it was a guess | Both providers now throw `UnsupportedError` when a grammar is requested — loud failure at the Milestone 9 gate instead of a guessed field on the wire |
| WorkManager `2.9.0` in code comments | Exists and works, but latest stable is 2.12.0 (2026-09-23) | Comments updated to 2.12.0 (no Gradle file exists yet to pin it in) |
| Audit claim: "DreamCycleService sleeps 15 min before its first tick" | Wrong — the loop ticks first, then sleeps. `tick=1` logs at service start | STATUS doc corrected; no code change needed. `tick=2` still takes 15 min by design |
| Audit claim: "no Rust toolchain in this VM / nothing compiled" | Was true when written; superseded the same day | Rust 1.99.1 + aarch64-linux-android target installed in this VM; `cargo test` 17/17 on host, `cargo check --target aarch64-linux-android` clean. Flutter/Java/NDK are still absent, so Dart/Kotlin remain uncompiled and nothing is device-verified |

## Verified since the first pass — background items (still no code against them)

### Kokoro TTS — packages exist, all immature; one serious candidate
- `flutter_kokoro_tts` ^0.0.1 — real (ONNX Runtime + espeak-ng, on-device),
  but v0.0.1, downloads a ~50 MB model on first use, needs NDK/CMake and a
  hand-built espeak-ng-data bundle. Experimental.
- `kokoro_tts_flutter` ^0.1.0 — real but ~471 days stale; manual model/voice
  assets and a phonemize-then-synthesise flow.
- `sherpa_onnx` — actively maintained (updated ~40 days before this check)
  and supports Kokoro-82M models on Android among its TTS engines. This is
  the credible evaluation path when audio arrives AFTER Milestone 10.
- Verdict: the honest answer to "does a Kokoro Flutter package exist" is
  yes — several — none mature. Do not pick one until the audio milestone.

### Rive Data Binding — real, but the spec's shorthand is the WEB runtime's
- Rive's own docs confirm data binding: on the web runtime,
  `rive.viewModelInstance.number(path)` / `.trigger(path)` are current API.
- The spec's `viewModel.number(...)` conflates the ViewModel with its
  instance, and the FLUTTER runtime's shape was not verified here.
- Verdict: concept verified, Flutter API UNVERIFIED. No code until the
  Rive UI work is scheduled.

## Unverified — do not code against these yet

| Item | Status |
|---|---|
| llama.cpp Android NDK build / `+fp16` flag | UNVERIFIED and currently unnecessary: no milestone requires llama.cpp (Ollama is the local path). Verify only if that changes. |
| NVIDIA dashboard terms for Richard's own key | UNVERIFIED. Requires his account. No code depends on it anymore. |
| Rive Flutter data-binding API shape | UNVERIFIED (web runtime verified, above). |
| Ollama/NVIDIA GBNF grammar via OpenAI-compat endpoint | UNVERIFIED. Providers now fail loudly if asked (Milestone 9 gate). |
