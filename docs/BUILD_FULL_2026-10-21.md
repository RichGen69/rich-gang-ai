# Rich Gang AI — Full Build Report (2026-10-21)

Scope authorized by Richard: "Build everything" (Milestones 1–10), superseding
the spec's original Milestones 1–3 stopping point.

## Verified complete

### Rust core (`rust/`, cargo 1.99.1)
- `cargo test`: **17/17 passed** (host build).
- ABI **v2**, 14 `rga_*` exports: abi_version, version, daemon_start/stop,
  agent_query, scene_apply, dream_cycle_tick, string_free, personas,
  remember, recall, witness_facts, witness_statement, dream_broadcast.
- Interrogation fact table in `src/facts.rs`: per-witness facts with an
  optional permitted lie (`lie_text` carried in the table but
  deliberately never exported by `rga_witness_facts`). Scene CONTENT
  is config-only — see the no-mock purge below; the assistant-authored
  sample scene that originally shipped here was removed 2026-10-21.
- Memory recall in `src/vector.rs` uses 64-dim FNV-1a **lexical hash
  vectors** — cosine over hashed token counts. That is token-overlap
  math, NOT semantic embeddings; there is no embedding model in this
  build, and code/UI/docs label it as lexical (corrected 2026-10-21,
  see the no-mock purge below). `dream_broadcast` reports real daemon
  state only (tick, stored count, actual stored texts).

### Native library (`libdaemon.so`, NDK r27, API 24 clang)
- Built for aarch64-linux-android, staged at
  `flutter_app/android/app/src/main/jniLibs/arm64-v8a/libdaemon.so`,
  SHA-256 `c26358e28b999d4b650e23bb3c013714c190eb201262ca9a1ea1bc44c719dd15`
  (current; rebuilt twice on 2026-10-21 during the no-mock purge below —
  earlier builds were `6cf4b195…` and `48a5a903…`).
- All 4 LOAD segments Align `0x4000` (16 KB page-size rule pass); all 14
  `rga_*` + 4 DreamCycleService JNI exports present; every Dart lookup and
  Kotlin external resolves. Details: `docs/BUILD_2026-10-20.md`.
- Rebuild path: `build_android.sh` (auto-detects the NDK, restages, verifies).

### Dart (Flutter 3.47.7)
- `flutter pub get`: 63 dependencies resolved. **`flutter analyze`: no
  issues found.**
- NativeBridge binds all 14 exports at `expectedAbi = 2`.
- Chat console uses `InferenceRouter.shared` (NVIDIA → Ollama → Rust FFI
  fallback), validates through Rust `sceneApply`, stores each exchange via
  `remember()`. Persona selector reads the Rust roster.
- Interrogation view is playable end-to-end against Rust statements only;
  Dream Broadcast view runs `dreamBroadcast()` and recall search; The Room
  applies `RoomRateController` on entry with 60/30 chips and the thermal
  severe test path (drop to 30 + dim); Settings frame-rate control applies
  immediately. NVIDIA cooldown clears from Settings.

### Kotlin / Android scaffolding
- Full Gradle scaffolding generated from the Flutter 3.47.7 template
  (AGP 9.1.0, Kotlin 2.4.0, Gradle 9.3.1), `applicationId`/`namespace`
  corrected to `com.richgang.ai`, `abiFilters += arm64-v8a`,
  `androidx.work:work-runtime-ktx:2.12.0` added.
- DreamCycleService JNI wiring, BootReceiver → expedited WorkManager →
  DreamArmWorker (FGS-start failure returns `Result.failure()`).
- Launcher icons (5 densities) and LaunchTheme/NormalTheme generated.
- **Correction to `docs/STATUS_M1-M3.md`:** DreamCycleService ticks
  *immediately* on start, then sleeps 15 min between ticks — the earlier
  claim that it sleeps before the first tick was wrong.

### Toolchain now installed in this VM
- JDK 17.0.20.1; Flutter 3.47.7 at `~/toolchains/flutter`; Android SDK at
  `~/toolchains/android-sdk` (platform 35, build-tools 35.0.0, adb 37.0.1,
  NDK 27 symlink); Rust 1.99.1. Build env: `~/workspace/flutter_env.sh`
  (unauthenticated egress proxy — the default authenticated proxy breaks
  Java tunneling and hangs pub; Gradle dist pre-seeded into
  `GRADLE_USER_HOME=/home/hatch/.gradle`; gradle.properties set to
  `-Xmx2G`, daemon off, after the template's 8G default OOM-starved
  builds on this 8 GB / 2 CPU box).

## No-mock purge (2026-10-21, on Richard's instruction)

Richard's standing rule — no mock data, no mock math, no hallucination —
triggered a full audit. Found and removed:

1. **Rust stub reply (worst offender).** `rga_agent_query` returned a
   canned `"{persona} heard you."` with `"stub": true`, and the Dart
   chat used it as the offline fallback, rendering it as the persona's
   answer and storing the fake exchange in memory. Now Rust returns an
   explicit `inference_unavailable` error and generates no text; the
   chat view shows "inference unavailable", stores nothing on failure,
   and the FFI test asserts no `reply`/`stub` fields exist.
2. **"Embeddings" mislabel.** The FNV-1a hashed vectors were described
   as embeddings in Dart comments and an earlier draft of this report.
   Renamed `embed_text` → `lexical_vector`, relabelled in Rust docs,
   Dart comments, the recall UI ("lexical match"), and this report.
3. **Invented AffectFrame numbers.** The chat view hardcoded valence /
   arousal / alignment / light values and fed them to the Rust scene
   validator as if model-produced. Removed: scene validation now
   engages only when a provider returns a real structured frame
   (Milestones 7–8 GBNF work).
4. **Dream broadcast flavour prose.** The empty-state sentence ("The
   room was quiet… the ledger stays as it was") was invented narration.
   Broadcasts are now factual-only: real tick, real count, real texts.

Re-verified after the purge: `cargo test` 17/17, `flutter analyze`
clean, `.so` rebuilt/restaged, alignment + exports re-checked.

**Scene decision (Richard, 2026-10-21): "I'll supply my own scene
data."** Acted on the same day:
- `FactTable::default_scene()` and the whole "Night Ledger" content
  deleted from Rust; a daemon without config facts now has an EMPTY
  table (regression tests assert this). Tests use minimal inline
  fixtures only.
- New additive FFI export `rga_witnesses` (ABI stays 2) so the UI can
  list witnesses from data. Total exports now 15 `rga_*` + 4 JNI = 19.
- The Dart interrogation view was rewritten fully data-driven: no
  hardcoded witnesses, questions, call-out buttons, or win condition.
  With no scene it shows an explicit empty state. The Room's button
  no longer names a scene.
- Delivery slot wired: the app loads its daemon config from the
  bundled asset `flutter_app/assets/daemon_config.json` (ships as
  `{}`), so Richard's scene drops into the `"facts"` key — format in
  `docs/SCENE_FORMAT.md`, blank form in `docs/scene_template.json`.
- Re-verified: `cargo test` 19/19, `flutter analyze` clean, `.so`
  rebuilt/restaged — SHA-256
  `c26358e28b999d4b650e23bb3c013714c190eb201262ca9a1ea1bc44c719dd15`,
  4 LOAD segments at 0x4000, 19 exports confirmed incl. rga_witnesses.

## The one blocker: APK packaging

`flutter build apk --release` reaches Gradle and fails with
**"Could not dispatch a message to the daemon"** — root cause proven, not
guessed: this VM's direct-network permission `other_tcp` is **Deny**, and
the sandbox severs the Gradle client's loopback TCP connection to its
(single-use) daemon. Evidence: daemon starts and listens on the exact
port, client write returns Broken pipe, daemon log shows no connection
ever arriving; same-session loopback tests pass, cross-session ones die.

**Fix (Richard, one setting):** Muse app → Settings → Permissions →
Direct network protocols → set `other_tcp` to **Ask**, then approve the
card on the next build attempt. After that, rerun:

```
source ~/workspace/flutter_env.sh
cd ~/workspace/rich_gang_ai/flutter_app
flutter build apk --release --target-platform android-arm64
```

Everything upstream of packaging is green, so the first build after the
permission change is expected to produce
`build/app/outputs/flutter-apk/app-release.apk` with
`lib/arm64-v8a/libdaemon.so` inside.

## Still not verified (needs hardware / Richard)

- Nothing is device-verified: no Android device exists in this VM.
  Milestones 1–3 logcat evidence (`[RICHARD] daemon online`, tick
  progression, reboot survival) remains unproven on hardware.
- Milestones 5–6 with a real NVIDIA key and a real on-device Ollama are
  unproven; Richard's build.nvidia.com dashboard check (post-trial terms)
  is still open.
- Only 3 of 7 personas are named (Leo, Capricorn, Aquarius). The other
  four names are Richard's call; the roster is overridable via the daemon
  config `personas` array.
- Design debt, flagged not fixed: Dart FFI and the Kotlin service each
  boot separate Rust Daemon instances in one process (separate scene /
  tick / memory). Must be unified before dream-cycle consolidation is
  expected to see UI-side memory.
- Unverified-and-unused (do not code against without evidence): Kokoro
  TTS Flutter package, Rive Data Binding API, llama.cpp Android flags,
  GBNF grammar via Ollama's OpenAI-compat endpoint.
