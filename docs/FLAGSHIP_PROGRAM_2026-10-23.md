# FLAGSHIP PROGRAM — Rich Gang AI / THE ROOM

Date: 2026-10-23.
Order: Richard — “Then make it a flagship product.”
Standard: Richard’s publish gate — elite, Hollywood-grade, cinematic,
flagship, enterprise, commercial level, **verified**, with Richard’s
explicit final approval of the exact build and exact copy before any
publish action.

## 0. Executive verdict

**The flagship is not done, and this program does not call it done.**
The current product has a substantial, real foundation:

- Flutter app + Rust daemon + FFI/JNI bridge;
- character system with affect, self-model, memory, Roundtable,
  voice routing, LiveAvatar client code, 3D-stage plumbing, and a
  cinematic Room surface;
- nine data-configured characters and fourteen registry-only entries;
- SQLite store, causal topology, and a memory-mapped ring integrated
  at code/FFI level;
- current staged native artifact passes the structural release gate.

The flagship is blocked by proof and product-completion gaps, not by
a missing feature list alone:

1. no APK has been built in this VM;
2. nothing in the current build has been verified on Richard’s A16;
3. no marketed provider has been proven by a live call from the app;
4. release signing no longer falls back to the Android debug key
   (Tranche 1 code fix: it fails fast with `signing_not_configured`
   when unconfigured), but Richard's production keystore does not
   exist yet and the Gradle-runtime proof is blocked by `other_tcp`;
5. several integrated components have no shipped consumer or shipped
   configuration decision;
6. the roster truth is 9 configured / 14 registry-only, while the
   current commercial artefacts were generated for the older
   22-entry registry;
7. verified age assurance and a formal security/privacy pass do not
   exist yet;
8. Richard has not approved a final, hash-identified build or final
   copy.

### Evidence rule for every phase

A phase passes only when its named evidence exists in an evidence
bundle: command output, test result, APK hash, device log, screenshot,
live-call record, signed roster/claims matrix, or Richard’s recorded
approval. Adjectives — “cinematic”, “fast”, “robust”, “flagship” —
are never acceptance evidence.

### Audit snapshot and moving-tree warning

This audit was performed while other builders were actively changing
the tree. The snapshot used below is the state after the ring CRC
addendum landed:

- `tools/release_gate.sh` run in this audit: **PASS**.
  - staged `libdaemon.so` SHA-256:
    `a8c4158137348a0304858b885978212fa4eda65cc27807889872fa8947ab5d76`;
  - staged .so byte-identical to the last aarch64 release build;
  - 30 dynamic `rga_*` / `Java_*` symbols;
  - all 26 Dart NativeBridge lookups resolve;
  - every LOAD segment Align `0x4000`;
  - Rust ABI 2 == Dart ABI 2.
- `docs/INTEGRATION_V5_MEMMAP_RING_2026-10-23.md`, CRC addendum:
  `tools/release_gate.sh --suites` **PASS**, cargo **78 passed**,
  Flutter analyze clean, Flutter test passed.
- `docs/BUILD_FINISH_2026-10-23.md`: Flutter analyze clean and
  Flutter test **43 passed** in its pass; its cargo divergence note
  was written while the ring CRC edit was mid-flight and is
  superseded for suite status by the later CRC addendum above. Its
  APK result is not superseded: the release APK attempt failed at
  the Gradle daemon step because `other_tcp` remains Deny.
- `docs/PUBLISH_GATE.md` still carries the transitional cargo note.
  That is an evidence-hygiene defect: P0 must freeze one candidate
  and re-run every suite against that exact tree before any status
  is treated as final.

---

# 1. Publish-gate audit

Status meanings:

- **Done** — qualifying evidence exists for the current snapshot.
- **Partial** — real work exists, but proof, disposition, or a final
  candidate is missing.
- **Blocked** — a named owner/input prevents progress.
- **Not started** — no qualifying implementation or evidence yet.

| ID | Publish-gate item | Status | Evidence read / run in this audit | Owner | Closed in |
|---|---|---:|---|---|---:|
| G01 | `cargo test` green, final counts recorded | Done (snapshot; repeat after freeze) | Ring CRC addendum records cargo **78 passed** and `release_gate.sh --suites` PASS. BUILD_FINISH records the earlier mid-flight divergence honestly. | Agent-buildable | P0 |
| G02 | `flutter analyze` green under strict options | Done (snapshot; repeat after freeze) | BUILD_FINISH + ring addendum: “No issues found”; strict options in force. | Agent-buildable | P0 |
| G03 | `flutter test` green | Done (snapshot; repeat after freeze) | BUILD_FINISH + ring addendum: **43 passed**. | Agent-buildable | P0 |
| G04 | No mock data, simulated responses, or hardcoded telemetry in shipped code | Partial | Code-level posture is unusually explicit: `edge_inference.rs` returns errors instead of canned output; providers fail visibly; HUD starts latency at null / “not measured yet”; registry-only entries are labelled. But there is no final, independent shipped-surface sweep/sign-off, and The Room still ships a user-facing **“Test thermal severe”** control that manually invokes a thermal state. Demo artefacts also need a final disposition. | Agent-buildable | P4/P8 |
| G05 | APK actually builds | Blocked | BUILD_FINISH records the genuine attempt: `flutter build apk --release --target-platform android-arm64` → “Could not dispatch a message to the daemon.” No APK exists in `flutter_app/build`. | Richard-only unblock; agent builds | P0 |
| G06 | APK installed and device-verified on Richard’s A16 | Blocked | No device run record exists. All current verification is VM-side. | Mixed: Richard device access + agent script | P1 |
| G07 | `libdaemon.so` rebuilt/restaged from current sources; exports verified | Partial | This audit’s structural gate PASS at SHA `a8c41581…` proves the current staged artifact. It is not yet a frozen release candidate, and later code phases will invalidate it until rebuilt/re-gated. | Agent-buildable | P0/P8 |
| G08 | Every marketed agent fully configured: portrait, confirmed voice, tuned affect | Partial | `characters.json`: 23 entries — first nine carry portrait/voice/baseline keys; fourteen are `registry_only_unconfigured`. The nine voice IDs are documented as sourced from a LiteLLM mapping and still require confirmation in Richard’s own ElevenLabs account. No device verification exists. | Mixed | P3 |
| G09 | Tammy / “The Oracle” overlap resolved before roster marketing | Done | PUBLISH_GATE records Richard’s 2026-10-22 resolution: Tammy keeps “The Oracle”; registry entry is “The Oracle of Nocturna”; roster tests lock display-name uniqueness. | Richard decision already made | P3 verifies |
| G10 | Every marketed provider key verified by a live call | Blocked | No provider keys or live-call records exist in this environment. Code is wired for NVIDIA/OpenAI/Gemini/Ollama/ElevenLabs/LiveAvatar; Deepgram has a client class but no app consumer (see §2). | Richard-only keys/choices; agent runs tests | P2 |
| G11 | Every marketed service exercised end-to-end in the shipped build | Blocked | No APK/device/live-provider evidence. Web search was verified from the workspace in 2026-10-21 docs, not from a shipped Android build. LiveAvatar is compile/unit verified only. | Mixed | P1/P2 |
| G12 | Real verified age assurance for 21+ | Not started | `AgeGate` in `character_ui.dart` is a confirmation dialog stored as a SharedPreferences boolean. PUBLISH_GATE explicitly says this does not satisfy the item. No vendor, token flow, or enforcement architecture exists. | Mixed: agent design/build + Richard vendor/policy decisions | P7 |
| G13 | Security/privacy review completed | Partial | Positive evidence: API credentials use `flutter_secure_storage` (`secure_keys.dart`); cleartext is loopback-only in `network_security_config.xml`; DreamCycleService is not exported. No completed review artefact exists, and §2 records open findings (on-device LiveKit secret, permission minimisation, backup/data controls, provider data flows). | Agent-buildable review + Richard policy decisions | P7 |
| G14 | Every prospectus claim verified or removed from copy | Partial | Known false/unproven claims are catalogued in PUBLISH_GATE and TIER10_BUILD. Current commercial artefacts still predate the 23-entry registry: HTML/store/Founder artefacts were generated 2026-10-22 for 22 entries; `html_build/store.html` still offers “future portrait drop for the extended 22-character registry.” No final claims ledger exists. | Agent-buildable sweep; Richard approves final wording | P8 |
| G15 | Valuation figures presented as Richard’s asking position, not verified value | Partial | TIER10_BUILD labels Richard’s figures as his asking position. No final listing/store package has been re-approved against the current product truth, so the item cannot close yet. | Richard-only final approval; agent prepares package | P8 |
| G16 | HTML website regenerated from final registry and honestly labelled | Not started (for the final registry) | Existing `html_build/rich-gang-ai.html` and Founder edition were generated from the 22-entry registry on 2026-10-22. Current registry is 23. A regeneration exists, but not from the flagship-final roster. | Agent-buildable after roster freeze | P8 |
| G17 | Richard’s explicit final approval of exact build + exact copy | Not started | No approval package, candidate hash set, or recorded final approval exists. | Richard-only | P8 |

## 2. Cross-cutting findings the checklist does not capture cleanly

These are flagship blockers or decision points found by reading the
current code, not marketing material.

### F-01 — Release signing is debug signing

`flutter_app/android/app/build.gradle.kts` still contains the
template TODO and:

```kotlin
signingConfig = signingConfigs.getByName("debug")
```

A debug-signed APK may be useful as an internal device-test artefact.
It is **not** a commercial flagship candidate. A production key,
controlled by Richard, is required before P8. Changing the signing
identity after device testing also changes install/update behaviour,
so the final signed candidate needs its own clean-install and
signed-to-signed upgrade proof.

**Tranche 1 update (2026-10-23):** the code half of this finding is
fixed — `build.gradle.kts` creates release signing only from
`flutter_app/android/keystore.properties` (git-ignored) or the
`RGAI_KEYSTORE_*` / `RGAI_KEY_*` environment variables, and a
release task requested without complete material is designed to
throw `signing_not_configured` naming the missing fields
(`docs/SIGNING.md`, `docs/FLAGSHIP_TRANCHE1_2026-10-23.md`). What
remains open is entirely Richard-side and proof-side: no production
keystore exists yet, and Gradle cannot evaluate the script in this
VM until the `other_tcp` block is lifted.

### F-02 — Two daemon handles, two configurations

- Dart `main.dart` boots `NativeBridge` with the bundled
  `assets/daemon_config.json` (personas only today).
- Kotlin `DreamCycleService.onCreate` boots its own daemon handle
  with `nativeBoot("{}")`.

Today that means the service’s daemon has default/empty config while
the UI’s daemon has the bundled config. If `store_path`,
`ring_path`, `causal_links`, or scene facts are later added only to
the bundled asset, the dream-service daemon will not share that
state. P6 must choose and prove one canonical owner/state model
before any store/ring/topology configuration is marketed as product
behaviour.

### F-03 — Credential fields exist for services with no app consumer

Repository search in this audit found:

- `DeepgramClient` is defined in `deepgram_client.dart` but has no
  caller in `flutter_app/lib` outside its own file;
- `HeyGenVideoClient` is defined in `heygen_video.dart` but has no
  caller in `flutter_app/lib` outside its own file;
- `LiveKitService` (Crew Link) is imported by a token test, but no
  production view calls `connect()`; the Settings toggle therefore
  cannot by itself produce a Crew Link session.

A flagship Settings screen must not present a key field or toggle as
a working product capability when no workflow consumes it. Each
orphan must be wired to a named workflow and live-tested, moved to a
clearly-labelled non-flagship/lab surface, or removed from the
flagship build/copy.

### F-04 — The Room contains developer/test artefacts

In `the_room.dart`:

- Room Controls exposes **“Test thermal severe”**, which calls the
  thermal handler manually. That is a test control, not a measured
  device thermal state, and it changes frame rate/opacity.
- The **NEXUS** strip is a static set of chips (`QUANTUM`, `MARKET`,
  `VIDEO•GEN`, …). They are not navigation and carry no live status;
  several names imply systems that are not shipped product surfaces.
- The cast heading says “THE SWARM — TAP AN AGENT TO TALK” while the
  grid renders all 23 registry entries, including fourteen
  registry-only entries that are not fully configured.
- The live strip says “N AGENTS IN THE ROOM” using
  `registry.all.length`; it does not distinguish ready from
  registry-only.

These are specific P4 fixes, not cosmetic preferences.

### F-05 — No per-character 3D models exist

`CHARACTER_AI.md` is explicit: no character GLBs exist. The Stage can
render a labelled demo robot (`stage_demo_robot.glb`) and per-device
override URLs, but a character opens in a no-model state. The Room
 nevertheless gives “3D Avatar Stage” a prominent full-width action.
Flagship disposition must be one of: source and verify real
per-character models, demote Stage to a labelled technical preview
outside the flagship path, or remove the prominent entry.

### F-06 — Interrogation has no shipped scene

`daemon_config.json` contains only `personas`. Richard’s standing
decision is that scene data is supplied by him, never invented. The
Interrogation view therefore has an honest empty state, but The Room
promotes it as a primary action. Flagship disposition: ship a real
Richard-supplied/licensed scene and verify it, label the surface as
a bring-your-own-scene tool, or demote it from the flagship action
row until content exists.

### F-07 — Commercial LiveKit token architecture is not acceptable as-is

`livekit_service.dart` states the security fact plainly: Crew Link
mints LiveKit JWTs on-device with the project API secret stored on
the device. The file itself says a shipped product must mint tokens
on a server instead. Therefore Crew Link cannot pass P7 as a
commercial feature in its current architecture. It must either move
token minting to a Richard-controlled server endpoint, use a vendor
token service, or be excluded from the flagship scope/copy.

### F-08 — Age-gate enforcement is not yet a system boundary

Current state:

- Crazy Kelly is the configured age-gated character; Shawna and Ruby
  are age-gated registry-only entries.
- `AgeGate` is a global confirmation boolean in SharedPreferences.
- Chat checks it asynchronously after the view is created; `_send`
  does not carry an explicit granted-state guard.
- Roundtable checks before starting a cast containing an age-gated
  character.
- `AvatarCallView` and `AvatarStageView` do not call `AgeGate`.

P7 must replace this with one authorization boundary used by every
surface that can expose a 21+ character — Room card, picker, chat,
Roundtable, call, stage, deep links/routes — with tests for direct
navigation and denial.

### F-09 — Stale statements inside code/docs weaken the evidence chain

Examples found in this audit:

- `tier10_hud.dart`’s header says the HUD is “Deliberately NOT wired
  into the_room.dart’s navigation in this build,” while
  `the_room.dart` imports and mounts `Tier10Hud`.
- PUBLISH_GATE’s cargo line records a transitional mid-flight state
  that the later ring CRC addendum superseded.
- GAP_AUDIT_V5’s summary still says several since-integrated items
  “are not in the code,” while its own tier rows and later
  integration documents record petgraph/rusqlite/memmap progress.

P0/P8 must treat evidence hygiene as a release task: one frozen
candidate, one current status record, no contradictory claims left
in shipped comments or customer-facing copy.

---

# 3. Program control rules

1. **Freeze before proof.** P0 creates a candidate manifest. Any
   source, asset, roster, signing, or native-library change after a
   test run creates a new candidate and invalidates downstream
   evidence for the changed surface.
2. **No phase skipping.** A later phase may prepare in parallel, but
   its evidence does not close until its dependencies pass. Example:
   provider screenshots taken on a debug-signed, pre-signing build
   may guide fixes, but P2 closes only on the release-candidate
   lineage specified in P0.
3. **One evidence bundle per run.** Proposed location:
   `docs/evidence/flagship/<candidate-id>/`. It contains the
   candidate manifest, command logs, test sheets, device logs,
   screenshots, live-call records, and approval record. Secrets and
   raw API keys are never stored in the bundle.
4. **Defect rule.** A crash, ANR, data-loss event, false status,
   wrong-character voice/avatar, age-gate bypass, or silent fallback
   in a marketed flow is a phase-blocking defect until fixed and
   re-run on a new candidate.
5. **Unknown metrics stay unknown until measured.** §11 defines how
   each metric is obtained. Proposed numeric budgets are labelled
   **TARGET (proposed)** and require Richard’s ratification; they are
   not current facts.
6. **No publish action in P0–P7.** Storefront/listing regeneration in
   P8 is preparation for Richard’s approval, not permission to
   publish.

---

# 4. P0 — Unblock, freeze, build, install

**Status: Blocked — Richard-only permission; no APK.**

## Objective

Turn the VM-verified source tree into one installable Android
candidate whose identity can be proven at every later phase.

## Work packages

### P0.1 — Candidate freeze (agent-buildable)

Create a candidate manifest recording:

- candidate ID and timestamp;
- SHA-256 of the staged `libdaemon.so`;
- SHA-256 of `characters.json`, `daemon_config.json`, `pubspec.yaml`,
  Android Gradle/Manifest files, and the HTML/commercial source set
  if already generated;
- a reproducible source-tree hash method (file list + per-file
  SHA-256), because this program must not assume a VCS state;
- exact verification commands to be re-run on the frozen tree:
  `cargo test`, `flutter analyze`, `flutter test`,
  `tools/release_gate.sh --suites`.

Acceptance:

- all four commands pass on the frozen tree in one recorded run;
- the structural gate reports the same `.so` SHA before and after
  the suites;
- any failure stops P0 and creates a defect record — no “green
  enough” language.

### P0.2 — Permission unblock (Richard-only)

Richard performs the blocker-list action for `other_tcp` and
approves the Gradle daemon card when the build prompts.

Acceptance:

- the Gradle daemon starts;
- the build proceeds past the historical failure string
  “Could not dispatch a message to the daemon.”

### P0.3 — Internal test APK (agent-buildable)

Build the release-configuration APK for `android-arm64` from the
frozen candidate.

Acceptance evidence:

- APK path, byte size, SHA-256;
- `apksigner verify --print-certs` output (certificate identity
  recorded; if it is the Android debug certificate, the artefact is
  labelled **internal-test only**);
- `aapt dump badging` output: package `com.richgang.ai`, version
  code/name, SDK levels, launchable activity;
- APK content listing proving `lib/arm64-v8a/libdaemon.so` is present;
- SHA-256 of the `.so` extracted from the APK equals the staged
  `.so` SHA in the candidate manifest;
- no missing-ABI claim: the current Gradle config filters to
  `arm64-v8a` only.

### P0.4 — Production signing decision (Richard-only + agent)

Before a commercial candidate is declared:

- Richard controls the production keystore and its password through
  a secure flow — never in chat, source, docs, or the evidence
  bundle;
- the approval package records only the key alias and certificate
  SHA-256 fingerprint;
- the keystore backup location is recorded in Richard’s own
  password/key management, not in this repository;
- Gradle release signing no longer references the debug key.

Acceptance:

- a production-signed APK verifies with the production certificate;
- install of production-signed build 1 followed by production-signed
  build 2 (same package, higher version code) succeeds without
  uninstall — proving update continuity;
- if a debug-signed build was installed first, the migration is done
  deliberately (export/reset state as designed, uninstall, install)
  and recorded; signature-mismatch failure is not treated as an app
  defect.

### P0.5 — Install on the A16 (mixed)

Acceptance evidence:

- `adb devices` shows Richard’s A16 as an authorised device;
- `adb shell getprop` records model and Android/API level actually
  present (no assumed version);
- `adb install` (or the approved install route) returns success;
- first launch reaches The Room without a fatal exception in
  `logcat`;
- package, version, signer, APK SHA, and `.so` SHA in the run sheet
  all match the candidate manifest.

**P0 exit decision:** PASS only when a hash-identified APK is
installed on the A16 and the signing lineage for the commercial
candidate is explicit. A debug-signed install passes P0’s *device
access* sub-gate only; it does not pass P8.

---

# 5. P1 — Device truth on the A16

**Status: Not started — no qualifying device evidence exists.**

## Objective

Prove the shipped flows work on Richard’s physical Galaxy A16, in
the real Android lifecycle, with the real daemon, service, and data.

## Required test environment record

For every run, record:

- candidate ID, APK SHA-256, signer fingerprint, app version;
- device model, Android version/API level, available storage;
- network state (Wi-Fi/mobile/airplane mode where relevant);
- selected provider/model and whether Ollama was reachable;
- start/end time and tester;
- raw artefacts: `logcat`, `dumpsys` excerpts, screenshots, and the
  completed run sheet.

## End-to-end script — every step is pass/fail

### P1.1 Cold open and first screen

1. Force-stop the app.
2. Clear only the test state specified by the run sheet (do not wipe
   production-like data unless the step calls for a clean install).
3. Launch from the launcher icon.
4. Record cold-open behaviour, daemon status line, arrival at The
   Room, and whether the cold open can be skipped by tap.
5. Repeat for the launch-count/Trust-Dial cases that are in scope:
   standard launches 1–3, a later launch with the cold open decayed
   off, Silent if selected, and reduced-motion enabled.

Acceptance: no crash/ANR; daemon status shown matches the actual
bridge state; The Room is interactive; screenshots show no clipped
or overlapping hero/live-strip content at default font scale and at
the largest system font scale.

### P1.2 Daemon and Room truth

- The Room live strip reports daemon online only when
  `NativeBridge().isUp` is true.
- Cast counts distinguish configured-ready from registry-only
  (after the P4 fix; before P4, record the current wording as a
  defect, not a pass).
- SETUP & HEALTH never labels a service “verified” for key presence
  alone (after P4 state-model fix).
- Tier-10 HUD latency is null/“not measured yet” before a routed
  call and changes only after a real routed call is measured by the
  router’s Stopwatch path.

### P1.3 Chat through a real provider

Using the provider selected and proven in P2:

1. Open Dan.
2. Send the fixed run-sheet prompt.
3. Record provider, model, response receipt, router-measured
   latency, and whether any fallback occurred.
4. Send a second prompt that depends on the first answer.
5. Force-stop, reopen, and verify the mind/memory behaviour that the
   product actually claims (affect/self-model restore; daemon recall
   where the workflow uses it).

Acceptance: a real provider response is received in the shipped UI;
no canned/system substitute is presented as a character reply; a
provider failure drill (invalid key or airplane mode) produces the
explicit unavailable state and stores no fake exchange.

### P1.4 Roundtable

- Start a table with Dan + Sally + Capricorn + Tammy (the existing
  default core four) on a fixed topic.
- Run the number of turns specified in the run sheet; interject once
  as Richard; pause; resume; stop.
- Copy the transcript and verify it matches the on-screen turns.
- Repeat the failure drill with the provider disabled: the table
  must stop with the reason shown, not invent lines.

Acceptance: turn order, speaker names, emotions, transcript, and
voice path (if voice is on) all correspond to real session state.

### P1.5 Voice and hands-free

- With ElevenLabs proven in P2, speak one line as Dan and verify the
  UI reports **voice: ElevenLabs**, not system TTS.
- Disable/remove the ElevenLabs key in a controlled test profile and
  verify the UI honestly reports **voice: system TTS** when the
  fallback speaks.
- Start hands-free, grant RECORD_AUDIO, speak a short phrase, verify
  a reply loop, then leave the screen and verify the microphone
  stops (Android mic indicator / log evidence).

Acceptance: no voice continues after leaving chat; no mic remains
live after hands-free is stopped or the view is disposed.

### P1.6 Dream cycle and foreground service

- Confirm MainActivity’s POST_NOTIFICATIONS flow:
  - granted → DreamCycleService starts;
  - denied → service does not start and the app does not pretend it
    did.
- Verify the foreground notification is present when the service is
  running.
- Observe at least one real 15-minute tick: logcat shows the
  service’s `tick=` value advancing, or a dream broadcast/memory
  artefact changes through the real workflow. A shortened debug
  interval may be used in a separate engineering build, but it does
  not replace the production-cadence observation for P1 closure.
- Background the app, swipe it from Recents, and record whether the
  service remains in the state Android actually gives it.

Acceptance: service state, notification state, tick evidence, and
UI claims agree. Any tick failure is logged as a defect with the
exact log excerpt.

### P1.7 Reboot and persistence

1. Create a recognisable in-app state through a real workflow
   (interaction count / reflection / stored memory, as applicable).
2. Reboot the A16.
3. Unlock the device and wait for the BOOT_COMPLETED →
   WorkManager → DreamArmWorker path.
4. Record whether the service re-arms without opening the app. If
   Android background-start rules prevent it, record that exact
   outcome and verify the MainActivity re-arm path on first open —
   do not claim unattended re-arm that did not happen.
5. Reopen the app and verify the state from step 1 is restored
   exactly as the product claims.

Acceptance: boot-path result is evidenced by WorkManager/service
logs; persistence claims match what is actually restored; the global
age-confirmation flag’s behaviour after reboot is recorded for P7
(it is not treated as age assurance).

### P1.8 Failure and accessibility drills

Run and record:

- airplane mode during chat and during a call attempt;
- daemon-offline state (engineering build or controlled failure);
- denied microphone permission for hands-free/call;
- denied notification permission for the service;
- largest font scale + TalkBack pass over Room, picker, chat,
  Roundtable setup, call preflight, and Settings;
- rotation/resizing where the manifest allows it.

**P1 exit decision:** PASS only when every required step passes or
has a fixed-and-rerun defect record on the same candidate lineage.
A step that was not run is a FAIL for phase closure, not a footnote.

---

# 6. P2 — Provider truth

**Status: Blocked — no live-call evidence; some credential surfaces
have no consuming workflow.**

## Rule

**No key, no claim. Key saved ≠ provider verified.** A provider is
verified only by the specified call made from the shipped app on
the A16, with the result recorded. A raw curl/API success may be a
useful diagnostic, but it does not close P2 by itself.

## Where credentials and IDs go

All in the installed app unless stated otherwise:

- **Settings tab → Brain & providers / Voice & video sections**
  (`flutter_app/lib/views/settings_view.dart`): provider API keys go
  into `SecureKeys` (`flutter_secure_storage`, Keystore-backed).
- **Avatar Call screen** (opened from a character’s chat):
  per-character HeyGen Interactive Avatar ID, LiveAvatar avatar ID,
  and optional LiveAvatar voice ID are entered there and stored as
  per-character preferences by the existing code.
- **Characters file** (`flutter_app/assets/characters.json`):
  ElevenLabs voice IDs for the configured cast are build-time
  casting data, not typed into Settings. Changing one is a roster
  change requiring tests + a new candidate.

## Provider matrix

| Provider / service | Richard supplies exactly | Where it goes | The one proving test call (from the app) | Pass evidence | If it fails / is absent |
|---|---|---|---|---|---|
| NVIDIA | NVIDIA API key (`nvapi-…`) | Settings → NVIDIA API key | Settings: select NVIDIA as cloud provider. Chat Dan with the fixed P1 prompt. | Non-empty Dan response in UI; run sheet records model from Settings (`nvidiaModel`, currently `meta/llama-3.3-70b-instruct` unless Richard changes it) and router state showing no silent Ollama substitution for the success claim. | NVIDIA is not marketed as a working brain. Ollama fallback may still be claimed only if separately proven. |
| OpenAI | OpenAI API key; confirmation that the configured model ID exists for his account | Settings → OpenAI key; model in Settings/AppSettings (`openAiModel`, code default `gpt-6-astra` — must be confirmed in Richard’s OpenAI dashboard before the test) | Select OpenAI. Chat Dan with the fixed prompt. | Real response in UI; model ID recorded exactly as configured; provider error, if any, is the API’s own error and is treated as failure. | OpenAI is removed from marketed providers until the exact model/key pair passes. |
| Gemini | Google AI API key; confirmation of configured model ID | Settings → Gemini key; model (`geminiModel`, code default `gemini-2.5-flash`) | Select Gemini. Chat Dan with the fixed prompt. | Real response in UI; exact model recorded. | Gemini is not marketed. |
| Ollama | A reachable Ollama server + an installed model; no API key | Settings → Ollama base URL; model name in Settings/AppSettings (code default `llama3.2:3b`) | From The Room, SETUP & HEALTH probe must report Ollama reachable; then chat Dan with cloud keys absent/disabled for the test profile. | Probe result + real response; run sheet records the exact base URL topology (on-device loopback vs LAN host) and model. | No “local/offline brain” claim. Note: Android `127.0.0.1` is the phone itself; a developer-machine server is not reachable by that address, and the current network-security config permits cleartext only for loopback/localhost/emulator host. Any LAN-HTTP topology needs a P7 decision, not a silent config widening. |
| ElevenLabs | ElevenLabs API key; account confirmation of every marketed character’s voice ID | Settings → ElevenLabs API key. Voice IDs stay in `characters.json`. | In Dan’s chat with Voice on, send a line and have Dan speak it. | UI reports **voice: ElevenLabs**; audio is Dan’s cast voice; run sheet records the voice name/ID used. P3 repeats for every marketed character. | Premium voice is not marketed for that character; system-TTS fallback must be labelled wherever it occurs. |
| Deepgram | Deepgram API key — **only if Richard elects to market a Deepgram workflow** | Settings → Deepgram key exists today | **No proving app call exists today:** `DeepgramClient` has no production caller. P6 must first wire it to a named workflow (e.g. a defined STT or Aura TTS action). Then: perform that workflow once on a fixed spoken phrase / fixed line. | For STT: transcript of the known phrase produced by the app workflow. For TTS: audible output produced by the app workflow, with the workflow named. | Deepgram is excluded from flagship claims and its Settings field is removed/hidden in P4/P6. A key alone proves nothing. |
| LiveAvatar | LiveAvatar API key (separate platform/plan from HeyGen); one LiveAvatar avatar ID per marketed character; optional LiveAvatar voice ID per character | Settings → LiveAvatar API key. Call screen → “LiveAvatar avatar id for this character” and optional voice ID. Context ID is created by the app from the character definition and stored by the app. | Start a LiveAvatar FULL call with Dan. Talk through the microphone; require the remote video track to arrive; end the call from the app. | Run sheet records session start success, context ID created, video-track arrival, two-way audio observed, and clean session end. “Session live” text without a track is an audio-only result and must be recorded as such. P3 repeats ID completeness for every marketed character. | LiveAvatar video calling is not marketed for any character whose ID/session/track test has not passed. |
| HeyGen (legacy streaming) | HeyGen API key + per-character Interactive Avatar ID — only if Richard insists on keeping the legacy path | Settings → HeyGen API key. Call screen → HeyGen Interactive Avatar ID. | Start one HeyGen call with Dan. | A live session + avatar speech/track from the shipped build. | Default disposition is **exclude**: current code/docs record the v1 `streaming.create_token` probe returning 404 and the UI itself calls this the legacy path. Do not market HeyGen realtime on a key or an ID alone. HeyGen *video generation* is a separate client (`heygen_video.dart`) with no production caller today; it follows the Deepgram rule. |
| LiveKit / Crew Link | LiveKit project URL + API key + API secret — only if Crew Link is in flagship scope | Settings → LiveKit project URL (non-secret), API key, API secret | **No production join flow exists today:** `LiveKitService.connect()` has no view caller. If P6 builds one: two devices join the same named room and pass audio both ways. | Two-device run sheet with join events and audio both ways. | Crew Link stays out of flagship scope/copy. Additionally, the current on-device-secret token minting fails the P7 commercial architecture gate; a P2 pass on a personal project does not override P7. |
| Web search (DuckDuckGo Instant Answer + Wikipedia) | No key | Built into CharacterAgent search path | Ask a search-triggering, current-information question in chat with search allowed. | Reply uses returned source material and the UI shows sources; an intentionally unanswerable/empty lookup is reported as empty in the drill. | Copy must not claim a full web index. The honest claim is limited to the two named sources actually wired. |

## Additional P2 acceptance rules

- The Room’s SETUP & HEALTH card may say “key saved” before P2. It
  may say “verified” for a provider only after that provider’s row
  above passes, and the verified state must be tied to the candidate
  + date in the run sheet (see P4 state model).
- Model IDs are recorded **as configured at test time**. Hosted
  model names rotate; a pass for one model ID is not a pass for a
  silently substituted model.
- Every provider error encountered is copied verbatim into the run
  sheet. A provider that returns an error has failed that attempt,
  even if another provider’s fallback produces a reply.

**P2 exit decision:** PASS for exactly the providers Richard chooses
to market and that pass their row. Unchosen or failed providers are
explicitly out of the flagship claim set.

---

# 7. P3 — Roster truth

**Status: Partial — nine are data-configured; none are
account-confirmed or device-verified; fourteen are registry-only.**

## Current roster truth (from `characters.json`)

- **Configured nine:** Dan, Rich, Crazy Kelly, Freddy, Tammy, Sally,
  Leo, Capricorn, Aquarius. Each carries portrait, voice casting,
  baseline, talkativeness, and volatility keys.
- **Registry-only fourteen:** Danny, Rich Rich, Richard, Mustang,
  WickOS, Shawna, Ruby, Iron Outlaw, Empress, Wildcard, Oracle of
  Nocturna, Archivist, Tom, Caesar. Each is
  `registry_only_unconfigured` with no portrait/voice/baseline keys.
- Registry total is **23**, and `daemon_config.json` personas match
  that registry. Any copy still saying 22 is stale.

## P3.1 — Verify the configured nine on device

For each of the nine, the run sheet must record:

1. Room/picker portrait is the character’s own shipped portrait;
2. display name, title, and zodiac match `characters.json`;
3. chat opens and answers through a P2-proven provider;
4. one spoken line reports the ElevenLabs path (if premium voice is
   marketed) and the voice heard is that character’s cast voice;
5. Richard confirms in his own ElevenLabs account that the voice ID
   in `characters.json` is present/valid for his account — or
   supplies the replacement ID as a roster change;
6. affect state changes / interaction count increments only from
   real interactions (no parser-default figures presented for
   registry-only entries);
7. Roundtable eligibility works with the real cast;
8. if LiveAvatar is marketed for the character, that character’s
   LiveAvatar avatar ID exists and the P2 session test passes for
   that character;
9. age-gated handling (Crazy Kelly) follows the P7 boundary — until
   P7 passes, Kelly’s 21+ status is a launch blocker for marketing
   her as a 21+ companion, regardless of chat function.

Acceptance: a 9-row roster matrix, one row per character, every cell
evidenced or marked “not marketed.” No row may be closed from asset
presence alone.

## P3.2 — Registry-only disposition: promote or exclude

Every registry-only entry gets exactly one disposition before P8:

### PROMOTE (all required)

- real portrait asset created/supplied and wired in
  `characters.json`;
- real voice ID confirmed in Richard’s ElevenLabs account (no
  invented or borrowed ID);
- authored baseline / talkativeness / volatility values entered as
  real configuration, not parser defaults;
- status changed from `registry_only_unconfigured` through the
  roster tests, which are updated to the new truth without weakening
  assertions;
- P3.1 device matrix completed for the character;
- if the character is age-gated (Shawna, Ruby), P7 passes first.

### EXCLUDE (all required)

- the character is not counted in any marketed cast number;
- the character does not appear in storefront/HTML “ready cast”
  presentations, Founder/Cast edition promises, or provider/avatar
  claims;
- in-app, the entry remains honestly labelled registry-only and is
  not presented as a finished character (P4 segmentation);
- the exclusion is recorded in the P8 claims ledger.

There is no third state. “In the registry” is not a marketing
category.

## P3.3 — Danny (separate line, Richard’s decision)

Current verified state:

- Danny, “The Better Twin”, Gemini, is fully authored as a character
  definition, including Richard’s hook and Southern-Texas written
  voice + persona-carried Easter eggs (all documented in
  `CHARACTER_AI.md`; none are deterministic trigger code).
- He is `registry_only_unconfigured`: no voice key, no baseline key,
  no portrait key in his entry.
- A reviewed portrait exists at
  `flutter_app/assets/images/portraits/danny.jpg` (JPEG, 1280×1920)
  but is deliberately **not wired** while he is registry-only.
- Proposed promotion baselines are recorded in `CHARACTER_AI.md`
  (talkativeness 0.8; PAD 0.25 / 0.35 / 0.7; volatility 0.2). They
  are **proposals, not shipped configuration**.

Danny promotion acceptance:

1. Richard chooses/confirms a real ElevenLabs voice for Danny in
   his own account and supplies that exact voice ID/name;
2. an agent wires voice + the approved baselines + the existing
   portrait, flips status, and updates the roster tests to the new
   truth;
3. full suites + release gate pass on the new candidate;
4. Danny completes the P3.1 device matrix.

If Richard does not choose a voice, Danny’s flagship disposition is
**EXCLUDE** — he remains an honestly-labelled registry entry, and
no copy may present him as a finished tenth character.

**P3 exit decision:** PASS only when the marketed cast list is
frozen, every marketed character has a complete matrix row, and
every non-marketed registry entry has a recorded EXCLUDE
disposition.

---

# 8. P4 — Cinematic product polish

**Status: Partial — a real cinematic base exists; the defects below
are open.**

## Method

P4 is judged from the actual screens in `flutter_app/lib/views/`,
not from concept art. Every fix below names the screen, the defect
visible in code, and the evidence that closes it. Final judgement
uses the A16 screenshot pack defined at the end of this phase, at
default font scale and largest font scale, reviewed by Richard.

## Fix list

### P4-01 — The Room: tell the truth about who is ready

- **Defect:** live strip counts all 23 as “AGENTS IN THE ROOM”;
  the cast grid mixes nine configured characters with fourteen
  registry-only entries under “THE SWARM — TAP AN AGENT TO TALK.”
- **Fix:** primary cast section shows the configured/marketed cast
  only, with a count in the form “9 READY” (exact wording Richard
  approves). Registry-only entries move to a separate, collapsed
  “Registry — not configured” section whose cards do not invite a
  finished-character chat.
- **Evidence:** Room screenshots + widget test asserting the ready
  count comes from configured status, not `registry.all.length`.

### P4-02 — The Room: portrait-forward ready cast

- **Defect:** ready characters are represented in the grid mainly by
  small circular avatar crops (`CharacterAvatar` radius 18 in the
  card header), which undersells the shipped cinematic portraits.
- **Fix:** ready-cast cards lead with the character’s own portrait
  in a portrait aspect, with name/title/affect overlaid or beneath;
  registry monograms remain monograms (never substitute a face).
- **Evidence:** screenshot pack for all marketed characters; asset
  test proving each card’s image path equals that character’s
  `characters.json` portrait.

### P4-03 — The Room: remove or make real the NEXUS strip

- **Defect:** static chips imply systems (`QUANTUM`, `MARKET`,
  `VIDEO•GEN`) with no destination or live status.
- **Fix:** each chip either navigates to a real surface or displays
  a real measured state — or the strip is removed.
- **Evidence:** UI test/screenshot showing every visible chip’s
  action/state; claims ledger entry for any surviving label.
- **Tranche 1 (2026-10-23):** the strip is **removed** from
  `the_room.dart`; source regression locks in
  `flutter_app/test/flagship_p4_test.dart` pass. Item stays open
  only for the device screenshot evidence in the P4 pack.

### P4-04 — The Room: remove the production “Test thermal severe” control

- **Defect:** a shipped control manually triggers the severe
  thermal presentation and changes the frame-rate setting; it is a
  simulation control in a flagship surface.
- **Fix:** remove it from release UI (or confine it to an explicit
  debug-only build). Real thermal behaviour is driven only by the
  platform/thermal path and is exercised in P1 by device conditions,
  not by a fake button.
- **Evidence:** release-build screenshot of Room Controls with no
  test-thermal control; code search result recorded in the evidence
  bundle.
- **Tranche 1 (2026-10-23):** the control, its manual `_thermal`
  handler, and the Room's manual thermal-dim state are **removed**
  from `the_room.dart`; code search is clean and the regression
  locks pass. Item stays open only for the release-build screenshot
  evidence, which needs P0/device access.

### P4-05 — SETUP & HEALTH: separate saved / configured / verified

- **Defect:** the card’s check icon is driven largely by key
  presence or by *either* video key being saved. “Saved” can read
  as “works.” The video row can look healthy with no per-character
  avatar ID and no live session.
- **Fix:** per-service state model with distinct labels:
  **Missing → Saved (unverified) → Configured (required IDs present)
  → Verified live (P2 run ID + date) → Blocked (exact error)**.
  System TTS is labelled as the active fallback, not as a failure
  icon and not as ElevenLabs.
- **Evidence:** screenshots for each state using a test profile;
  state-model unit/widget tests; P2 run IDs referenced, not copied
  metrics.

### P4-06 — Chat: flagship character presence and honest failure

- **Defects:** the chat header is a small avatar + “feeling
  loading” fallback; an inference failure is inserted as a system
  text line with no structured recovery action; the composer does
  not carry an explicit age-authorised state for gated characters.
- **Fix:** header shows the character’s portrait identity and real
  affect state (or a neutral “waking” state that resolves, never a
  permanent “loading” emotion). Failure becomes an error card with
  the provider’s real error and explicit actions: **Retry**,
  **Open Settings**, and — only if actually available — **Use Ollama
  fallback** as a user-chosen action, not a silent substitution.
  For age-gated characters, the composer stays disabled until the
  P7 authorisation state is granted for that character.
- **Evidence:** screenshots for ready / waking / provider-error /
  age-blocked states; widget tests for the error card actions and
  the gated-composer state.

### P4-07 — Roundtable: transcript-first on a phone

- **Defects:** the setup column (topic, presets, 23 cast chips,
  modes, switches, controls) remains above the transcript while a
  session runs, squeezing the actual show; “All” selects registry-
  only entries as if they were ready cast; failure is a small red
  line with no recovery path.
- **Fix:** once running, setup collapses to a compact session bar
  (topic, mode, status, pause/stop); cast selection defaults to
  configured characters and shows registry-only entries disabled
  with their reason; failure state offers Change provider / Open
  Settings / Restart with eligible cast.
- **Evidence:** running-state screenshot on the A16 showing the
  transcript as the dominant surface; widget tests for cast
  eligibility and collapsed state.

### P4-08 — Call screen: preflight, not a raw-ID form

- **Defects:** the default call surface is a scrolling form with raw
  avatar-ID fields, an exposed LiveAvatar context ID, provider
  exposition text, and a plain reversed log; “waiting for track”
  has no timeout/recovery state; the HeyGen legacy segment remains
  selectable even though the same screen says its endpoint fails
  pre-flight checks.
- **Fix:** flagship call flow = preflight checklist (key verified,
  this character’s avatar ID present, mic permission, network) →
  connecting state with elapsed time → live state with video track
  or an explicit **Audio only** badge → track-wait timeout with
  Retry / End actions → clean ended state. Raw IDs and logs move
  behind an **Advanced / Diagnostics** disclosure. The context ID is
  not displayed as ordinary UI. HeyGen legacy is hidden/disabled in
  the flagship build unless P2 passes it.
- **Evidence:** screenshots for preflight-blocked, connecting,
  live-video, audio-only, timeout, and ended states; P2 LiveAvatar
  run record for the live states.

### P4-09 — 3D Stage: stop promoting a demo as a flagship action

- **Defect:** The Room gives the Stage a full-width primary action,
  but no character has a GLB; the only real model is a demo robot.
- **Fix:** choose one disposition — (a) source real per-character
  models and verify them on device, (b) move Stage to a clearly
  labelled **Labs / Pipeline preview** area, or (c) remove the Room
  action. The demo robot’s label stays verbatim wherever it appears.
- **Evidence:** Room screenshot showing the chosen disposition;
  if (a), a per-character model inventory + device screenshots.

### P4-10 — Interrogation: no empty flagship feature

- **Defect:** a primary Room action leads to “No interrogation scene
  is loaded” because no scene ships and Richard has not supplied one.
- **Fix:** ship a real Richard-supplied/licensed scene and verify
  the full interrogation flow, or demote the action and label the
  surface as a bring-your-own-scene tool with the config format
  stated before entry.
- **Evidence:** either a complete device run of the shipped scene
  or Room screenshots showing the demoted/labelled entry.

### P4-11 — HUD: make diagnostics subordinate and current

- **Defects:** `tier10_hud.dart`’s header comment contradicts the
  code (it says not wired into The Room; it is mounted). The card
  says “Active agents (registry)” and shows only the last measured
  latency, which can be misread as a performance figure.
- **Fix:** correct the stale comment; label counts as ready vs
  registry; show route/provider and sample context for the last
  measurement (e.g. “last routed call”), never a bare latency as a
  headline claim; keep the card visually subordinate to cast and
  actions, or move full diagnostics behind SETUP & HEALTH details.
- **Evidence:** code-search record for the stale comment’s removal;
  screenshots before/after a real routed call showing the state
  change from “not measured yet.”
- **Tranche 1 (2026-10-23):** partial — the stale “not wired”
  header comment is corrected (the HUD is mounted by The Room)
  and the count now reads “Registry entries (total, not a ready
  count).” Ready-vs-registry counts and route/provider sample
  context remain open.

### P4-12 — Navigation, settings, accessibility, brand mark

- **Defects:** `AppScaffold` swaps `_pages[_index]` (tab state is
  not preserved by an IndexedStack pattern); The Room also pushes a
  second `SettingsView` route from SETUP & HEALTH, so Settings
  exists both as a tab and as a pushed page; the cold open’s brand
  mark is a “◆” text glyph; most icon actions rely on tooltips with
  little semantic labelling beyond that.
- **Fix:** preserve tab state; make Settings one destination with
  one return behaviour; replace the glyph with the approved brand
  asset; add semantic labels for icon-only actions and verify the
  primary flows with TalkBack and largest font scale.
- **Evidence:** tab-switch state test (scroll position / in-progress
  setup survives a tab round-trip, or the loss is an explicitly
  approved behaviour); TalkBack pass recorded in P1.8; cold-open
  screenshot with the real brand mark.

### P4-13 — Dead surfaces do not ship as flagship confusion

- **Defects:** `ChatConsoleView` exists but is not reachable from
  the scaffold; Deepgram/HeyGen-video/LiveKit-service orphans are
  covered in F-03.
- **Fix:** every shipped screen/client is reachable and owned by a
  named flow, or it is removed from the flagship build. No
  unreachable “second chat” remains to drift out of sync.
- **Evidence:** navigation inventory in the evidence bundle mapping
  every view under `lib/views/` to its entry route or its removal.

## P4 screenshot pack (acceptance artefact)

For Room, Picker, Chat, Roundtable, Call, Stage (if retained),
Settings, and Cold Open, capture on the A16:

- loading / waking;
- ready;
- empty (where the state can honestly occur);
- offline / provider-error;
- permission-denied (mic / notifications, where relevant);
- age-blocked (after P7);
- registry-only presentation;
- largest-font variant of each primary screen.

**P4 exit decision:** PASS only when every P4 item is fixed or has
a Richard-approved disposition recorded here, and Richard approves
the screenshot pack as the cinematic standard for this build.
Approval of screenshots does not substitute for P1/P2 functional
evidence.

---

# 9. P5 — Local frontier decision gates

**Status: In progress / undecided — llama-cpp-2 host spike passed;
Android and model gates are open; LanceDB has code but no recorded
verdict; local inference is not integrated.**

## Current evidence (do not over-read it)

### llama-cpp-2

From `docs/SPIKE_V5_005_LLAMA_CPP.md`:

- crate identity verified: the named project ships as
  `llama-cpp-2` (locked in the spike at 0.1.160);
- **host PASS:** one backend-initialisation test passed
  (`llama_backend_init`, `llama_time_us`, `ggml_time_us` linked);
- **Android target: PENDING**;
- **Vulkan probe: PENDING** — and the VM lacks Vulkan headers/glslc,
  so a VM Vulkan failure would be an environment finding, not a
  device verdict;
- **no model exists** in this environment and none was downloaded;
  no token has been generated;
- the debug static libraries are large (spike recorded a 140 MB
  debug `libllama.a`); release/APK size impact is unmeasured.

### LanceDB

From `spikes/v5_006_lancedb/`:

- spike code exists: connect → create fixture table → nearest-
  neighbour query over hand-planted fixture vectors, with tests for
  nearest-row and ordering;
- **no `docs/SPIKE_V5_006_LANCEDB.md` verdict exists yet**;
- `Cargo.toml` still declares `lancedb = "*"` and `arrow-* = "*"`
  in the spike; a lockfile-resolved, recorded version set is
  required before any integration judgement;
- fixture vectors are **not embeddings** and prove no semantic
  quality.

### Tokio

A design now exists (`docs/DESIGN_TOKIO_INTEGRATION_2026-10-23.md`)
and its honest finding is that **nothing in the current codebase
needs Tokio today**; the only named future consumer is the unbuilt
UDP mesh. Tokio is therefore not a flagship blocker and not a
marketing claim. It enters the program only if Richard approves
the mesh as a separate, security-designed feature.

## Gate L1 — llama Android proof

Required evidence:

- isolated spike `cargo check` + build for
  `aarch64-linux-android` completes, with the exact toolchain/env
  recorded (the host pass depended on NDK libclang paths — the
  Android recipe must be reproducible, not hand-waved);
- the resulting Android artefact’s architecture is verified from
  the artefact itself;
- the backend-init test equivalent runs against the Android build
  path that the integration would actually use (cross-compile alone
  is labelled compile-level evidence).

**Fail →** local GGUF inference is out of the flagship. No partial
credit, no “coming soon” claim in copy.

## Gate L2 — Model story (Richard decision + agent verification)

No integration begins until a model record exists with:

- model name and publisher/source;
- exact version and quantisation;
- licence/terms, including whether redistribution inside an APK or
  as a download is permitted;
- file SHA-256 and byte size, measured from the actual file;
- context length and tokenizer files required;
- delivery decision: bundled in APK, first-run download, or
  user-supplied file — with the storage/update/deletion behaviour
  for that choice;
- content/age policy fit for where the model will be used.

**No model record → no local-inference claim**, regardless of L1.

## Gate L3 — A16 inference proof

On the physical A16, with the L2 model:

1. load the model in the candidate app path (not only a spike
   binary);
2. generate from a fixed prompt with fixed generation settings;
3. record time-to-first-token, total generation time, generated
   token count, peak memory (`dumpsys meminfo`), thermal/battery
   snapshots before/after, and any crash/OOM;
4. repeat cold (fresh process) and warm (model already loaded);
5. if Vulkan/Adreno acceleration is to be claimed, the device log
   must show the GPU backend actually in use; a CPU pass proves CPU
   only.

Acceptance is the existence of these measurements plus Richard’s
ratification of the performance budget (§11). Invented speed
numbers are prohibited.

## Gate L4 — Integration discipline (only if L1–L3 pass)

- integration follows the established pattern: spike record →
  design → additive FFI behind the existing `edge_inference`
  boundary → suites → `.so` rebuild/restage →
  `tools/release_gate.sh --suites` PASS → P1 regression on device.
- APK size and cold-start deltas versus the P0 baseline are
  measured and recorded; Richard approves the delta explicitly.

## Gate D1 — LanceDB host + Android proof

Required evidence:

- spike doc with a verdict, locked dependency versions;
- host tests pass (nearest neighbour is the planted closest row;
  ordering; full-query control);
- Android `aarch64-linux-android` check/build/link result recorded
  with the exact failure point if it fails;
- final library/APK size impact measured if it links.

## Gate D2 — Real embeddings or no semantic claim

LanceDB stores vectors; it does not create meaning. Semantic memory
requires an embedding model record with the same fields as L2
(source, licence, size, SHA, delivery) **and** an evaluation set
approved by Richard: real memory texts with expected nearest
neighbours, run against the actual pipeline. Fixture vectors may
prove plumbing; they may never be presented as semantic quality.

## Gate D3 — Persistence, upgrade, corruption behaviour

Before integration: tests for reopening an existing database,
schema/version upgrade, a corrupted/truncated database returning an
explicit error (never invented rows), and deletion of a memory
actually removing it from results.

## P5 default outcome

If any gate fails or is not run, the flagship ships the honest
current architecture — **cloud providers proven in P2 + Ollama
where proven** — and:

- `edge_inference` continues to return explicit unavailable errors;
- memory recall remains the current lexical-hash recall, labelled
  lexical, never “semantic”;
- no copy claims local GGUF inference, Vulkan acceleration,
  LanceDB, semantic memory, or “100% offline” operation.

**P5 exit decision:** PASS means every frontier feature Richard
wants *marketed* has passed its gates, and every other frontier
feature has a recorded exclusion. An unrun gate is an exclusion,
not a pending claim.

---

# 10. P6 — Plumbing → product

**Status: Partial — store/topology/ring are integrated as plumbing;
none has a shipped product consumer or configuration.**

## Current truth

- Dart `NativeBridge` exposes `storeState/storePut/storeGet/
  storeDelete`, `ringState/ringSend/ringRecv`, and
  `topologyState/topologyReaches`. Repository search in this audit
  found **no caller** of any of them outside `native_bridge.dart`.
- Shipped `daemon_config.json` contains only `personas`: no
  `store_path` (store is therefore an in-memory session store
  reporting `persistent:false`), no `ring_path` (ring disabled,
  explicit `ring_disabled`), no `causal_links` (empty topology),
  no scene `facts`.
- The ring’s CRC addendum closed the torn-record detection gap at
  the current in-process boundary. The design audit’s production
  concerns remain for any cross-process/Kotlin-reader use:
  synchronization soundness, claim/commit delivery, lifecycle,
  ownership, and Android-path proof are not established by the
  in-process integration.

## P6.0 — Canonical daemon owner (prerequisite)

Decide and document one of:

- **Single owner:** one daemon handle owns store/ring/topology/
  scene state; the other boot path attaches to it or does not boot
  a second stateful daemon; or
- **Explicit split:** Dart-owned and service-owned daemons are
  separate by design, each with named state, and no workflow expects
  them to share store/ring/scene state.

Acceptance: an architecture record naming the owner of each state
store, plus a device test proving the dream service and the UI see
the state the design says they see. **No P6 configuration ships
before P6.0 passes.**

## P6.1 — SQLite store consumer

Candidate workloads (choose at most one first workload):

- durable daemon key-value state for a named existing dataset, with
  its current owner traced in code first; or
- no workload — store remains internal plumbing and is not marketed.

If a workload is chosen, acceptance requires:

- Kotlin/Dart supplies an **app-private** path at runtime (a bundled
  asset cannot know the Android files directory); the config source
  and path are recorded;
- `storeState` on device reports `persistent:true` and the actual
  journal mode read back from SQLite;
- write through the real product workflow → force-stop → reopen →
  value read back; repeat across reboot (with P1.7);
- unopenable-path drill still fails daemon start explicitly;
- backup/restore and app-data-clear behaviour for that dataset is
  documented (what survives, what is deleted).

If no workload is chosen: the store is recorded as **deferred
internal plumbing**; no copy claims persistent Rust-side KV storage
as a user feature.

## P6.2 — Memory-mapped ring consumer

The only plausible first workload named by the design audit is
Rust-daemon event/dream frames consumed by `DreamCycleService`.
That workload must first be justified against the existing direct
JNI tick path: what frame, what producer, what consumer, what
payload limit, what delivery requirement (at-least-once vs
at-most-once), and what happens on `ring_full`.

Acceptance for production use (all required):

- P6.0 owner decision names the single ring owner;
- app-private path under `noBackupFilesDir` supplied by Android,
  owner-only permissions verified on device;
- production protocol implements the audit delta that the chosen
  workload needs: validated framing before any slice, claim →
  copy/process → commit semantics with the delivery rule stated,
  generation/rotation behaviour, and corruption returning a named
  error (never a panic, never delivered bytes);
- Kotlin, if it reads, is a **read-only** `MappedByteBuffer` reader
  operating on Rust-claimed frames, proven on the A16 under
  concurrent load and service restart; Kotlin does not write shared
  counters in v1;
- JNI surface, if added, is limited to the state/claim/commit/
  abandon operations the workload uses;
- every Rust/JNI/Dart change is followed by `.so` rebuild/restage
  and `tools/release_gate.sh --suites` PASS on the exact artefact.

If the workload cannot be justified: **defer**. The ring stays
disabled in shipped config, remains unmarketed, and the existing
slot-locked ring + direct JNI path stay authoritative. Deferral is
a valid flagship outcome; an unused “zero-copy” claim is not.
(“Zero-copy” may be used only with the exact boundary named and the
remaining copies stated, per the design audit.)

## P6.3 — Topology consumer

- Shipped topology is empty because no `causal_links` ship.
- A flagship consumer requires Richard-supplied or authored causal
  data with a named use (e.g. a shipped interrogation scene whose
  facts/links the UI actually traverses).
- Acceptance: config ships the data; `topologyState` on device
  reports the shipped graph; a UI workflow uses `topologyReaches`
  to produce a visible, correct result; empty-data builds show the
  honest empty state.
- Otherwise: deferred, unmarketed.

## P6.4 — Orphan provider/service consumers

For each of Deepgram, HeyGen video generation, and LiveKit Crew
Link (see F-03/F-07):

- **Wire it:** name the user workflow, build the entry point, pass
  its P2 live test and P7 review; or
- **Defer it:** remove/hide its flagship Settings fields and claims;
  the code may remain in the tree only if it cannot be mistaken for
  a shipped capability.

Acceptance: a credential-field inventory mapping every Settings
secret field to a live workflow + P2 run ID, or to its removal.

## P6.5 — Scene/facts content

- Interrogation’s `facts` remain Richard-supplied only.
- If P4-10 chooses to ship a scene, the scene file becomes part of
  the candidate manifest, is validated through the real parser, and
  is exercised end-to-end on device.
- No scene → Interrogation is demoted/labelled per P4-10 and no
  copy implies built-in case content.

**P6 exit decision:** PASS only when every integrated plumbing
component is either (a) serving a named, device-proven workload
under a shipped configuration, or (b) explicitly deferred and
unmarketed. “Integrated” alone never passes P6.

---

# 11. Measurement protocol — how unknown numbers become facts

No current performance number for the Android product is known.
The following measurements are taken on the A16 during P1/P5.
Results are recorded with sample size, conditions, and raw tool
output. A single favourable run is not a product claim.

| Metric | Method (named tool/source) | Conditions recorded | Claim rule |
|---|---|---|---|
| Cold-start time | `adb shell am start -W` (TotalTime/WaitTime) after force-stop; plus the app’s own first-interactive timestamp if instrumented | Launch number, cold-open schedule state, device thermal state, battery saver on/off | Report median + range over the run sheet’s repeated launches. |
| Frame performance | `adb shell dumpsys gfxinfo com.richgang.ai framestats` after the scripted Room scroll + Roundtable run | Screen refresh setting (60/30), font scale | Report measured frame stats as recorded; no “smooth” claim without the data. |
| Chat latency | Existing router Stopwatch measurements surfaced through the Tier-10 controller, correlated with run-sheet send/receive times | Provider, model, network, prompt ID, fallback yes/no | Last-call latency is a sample, not a headline. Any published figure needs the sample set attached. |
| Voice start latency | Run-sheet timestamps: send tap → first audible ElevenLabs/system speech, observer-recorded on device | Provider path actually reported by UI, character, network | Report per-path samples separately; never merge ElevenLabs and system-TTS samples. |
| Call join time | Run-sheet timestamps: Start tap → session live; Start tap → first remote video frame | Provider (LiveAvatar), character/avatar ID, network | “Session live” and “video visible” are separate metrics. |
| Memory (RAM) | `adb shell dumpsys meminfo com.richgang.ai` at Room idle, during Roundtable, and during any P5 local-model run | Candidate, workflow step | Report the recorded PSS figures per step. |
| Storage | APK size from the artefact; installed app/data sizes from Android Settings / `dumpsys` on device | Clean install vs upgraded install | Report both; model files (P5) counted separately from the APK. |
| Battery / thermal | `dumpsys batterystats` + `dumpsys thermalservice` snapshots before/after the P1 script and any P5 inference run | Script duration, screen state, charging state | Report deltas/snapshots as measured; no endurance claim from one script run. |
| Dream-cycle cadence | Service logcat `tick=` timestamps across at least one full production interval | Notification permission state, app foreground/background, Recents-swipe state | Cadence is claimed only for the states actually observed. |

### Proposed targets — **TARGET (proposed), not facts**

Richard ratifies numeric budgets after the first P1 baseline run.
Until then, the only hard targets are functional:

- zero crashes/ANRs in the P1 script;
- zero false status displays in the P1/P2/P4 evidence;
- 100% of *marketed* flows pass their run sheets;
- zero age-gate bypasses in the P7 test matrix.

Proposed numeric budgets to ratify at that point (labelled targets,
to be replaced by Richard’s approved values): cold-start median,
chat first-response, voice start, call join, peak RAM during the
heaviest marketed flow, and maximum APK + bundled-asset size.
**P8 cannot pass with unratified budgets if any numeric performance
or size claim appears in copy.**

---

# 12. P7 — Safety & trust

**Status: In progress (formal pass started in Tranche 1,
2026-10-23) — the written security review
(`docs/SECURITY_REVIEW_2026-10-23.md`) and the vendor-neutral age
design (`docs/AGE_ASSURANCE_DESIGN_2026-10-23.md`) now exist, but
every finding in the review is open, the confirmation-only age
gate is still explicitly insufficient, and no verified age
assurance exists.**

## P7.1 — Verified age assurance for 21+

### Scope

Age-gated today: **Crazy Kelly** (configured) plus **Shawna** and
**Ruby** (registry-only; they cannot be promoted or marketed before
this phase passes).

### Design requirements

The replacement for `AgeGate` must:

1. use a real verification method from a named provider or platform
   mechanism, selected by Richard (account, cost, and data terms
   are his decisions);
2. collect the minimum data the method requires; the design states
   exactly what the vendor receives, what the app receives (a
   verification result/token, not a DOB copy unless the method
   truly requires it), what is stored, where, and for how long;
3. bind the verified state so that clearing ordinary preferences
   does not silently mint a verified adult, and so reinstall /
   app-data-clear behaviour is explicit and tested;
4. gate **before exposure** on every surface: Room card, picker,
   chat (composer disabled until granted), Roundtable cast,
   LiveAvatar/HeyGen call, Stage, and any future route/deep link;
5. handle denial, vendor outage, offline state, and retry with
   explicit states — outage never fails open;
6. record verification events without logging identity documents or
   secrets.

### Acceptance test matrix (all on the A16)

- unverified user: every surface above blocks the gated character
  before any gated interaction;
- denied verification: still blocked, with the denial state shown;
- verified user: gated character unlocks on every in-scope surface;
- vendor unreachable: still blocked (fail closed);
- app-data clear / reinstall: behaviour matches the design record
  exactly;
- registry-only gated entries remain unpromoted and unmarketed
  regardless of the confirmation state.

**Alternative disposition:** if Richard does not adopt a verified
method, the flagship either excludes all 21+ characters from
marketing and access, or does not ship. The confirmation dialog may
remain only as an *additional* notice, never as the assurance
mechanism.

## P7.2 — Security & privacy review

A written review artefact is required. It must cover, with a
finding and disposition for each:

### Keys and secrets

- Inventory: NVIDIA, OpenAI, Gemini, ElevenLabs, HeyGen,
  LiveAvatar, Deepgram, LiveKit API key + secret — each mapped to
  storage (`SecureKeys` / Keystore-backed), the workflow that reads
  it, and whether it may remain on-device in a commercial build.
- **Hard finding already open:** LiveKit API secret on-device for
  Crew Link token minting (F-07). Disposition must be server-side
  minting or Crew Link exclusion.
- Log sweep: no key, token, prompt, or config secret appears in
  `debugPrint`/Logcat paths; the one existing startup print records
  daemon version only.
- Settings must offer per-key removal that actually deletes the
  stored secret (the `SecureKeys.clear*` methods exist; the UI path
  for each marketed key is verified on device).

### IPC / FFI / JNI surface

- Every `rga_*` export and JNI entry is inventoried with its input
  trust assumptions; panic/error behaviour at the boundary is the
  tested behaviour (release profile keeps `panic = "unwind"` so an
  FFI panic must not kill the process — verify the boundary tests
  on the final candidate).
- The two-daemon-handle state model from P6.0 is restated here as a
  security/integrity fact: which handle can write which store.
- Ring file (if P6.2 ships it): app-private path, owner-only
  permissions verified on device, no secrets as payloads, CRC is
  integrity-only (not authentication) in all wording.

### Provider data flows (privacy map)

For each marketed provider, the review records what leaves the
device:

- cloud brains (NVIDIA/OpenAI/Gemini): prompt + persona/memory
  context the app actually sends;
- Ollama: the exact topology (on-device vs named host) and what
  that host receives;
- ElevenLabs: text sent for synthesis + voice ID;
- LiveAvatar (FULL mode): persona context created from the
  character definition, microphone audio, and the fact — already
  disclosed in the call UI — that LiveAvatar runs the conversation
  pipeline on its side;
- web search: the query sent to DuckDuckGo Instant Answer and
  Wikipedia;
- Deepgram / HeyGen / LiveKit: only if wired and marketed, with
  their actual payloads.

The in-app privacy surface must match this map in plain language,
and any provider whose data flow Richard does not accept is removed
from the marketed set.

### Permissions minimisation

Map every Manifest permission to a marketed workflow that needs it
on the final candidate. Permissions tied only to unbuilt features
(e.g. multicast/Bluetooth items inherited for LiveKit/mesh) are
removed or justified in writing. Camera, microphone, notifications,
foreground-service, wake-lock, and boot-receiver each get a named
workflow + the denied-permission device result from P1.

### Local data, backup, deletion

- Inventory local stores: SharedPreferences mind store, age/
  verification state, per-character avatar/context IDs, stage
  overrides, launch counter; Rust store/ring if shipped.
- State Android backup behaviour for each (what Auto Backup would
  carry) and set an explicit policy; a restored stale ring or
  verification state must fail safe.
- Provide and device-test: **reset my data** (mind + preferences),
  **remove all API keys**, and the effect of app-data clear /
  uninstall, in words that match the observed behaviour.

### Release hygiene

- Release build does not expose the P4 test controls or diagnostics
  by default.
- Network security config remains HTTPS for providers; any Ollama
  LAN exception is a named, Richard-approved domain/IP decision —
  never a wildcard cleartext opening.
- Dependency/toolchain versions for the candidate are recorded in
  the manifest (Flutter, Rust, NDK, Gradle/AGP as built).

**P7 exit decision:** PASS only when the age-assurance matrix
passes (or the 21+ exclusion disposition is in force), the written
review has no open high-severity finding, and every open medium
finding has a Richard-accepted disposition recorded.

---

# 13. P8 — Commercial finish

**Status: Not started for a final candidate — current commercial
artefacts are stale against the 23-entry registry, and no approval
package exists.**

## P8.1 — Freeze the commercial truth set

Inputs, all from closed phases:

- marketed cast list (P3) — names, titles, portraits, voices;
- marketed provider/service list (P2) with run IDs;
- marketed feature list (P5 exclusions + P6 dispositions);
- age/safety posture (P7);
- final candidate hashes (P0) and device evidence (P1);
- ratified performance budgets, if any numeric claim will be made
  (§11).

Anything not in these inputs does not appear in commercial copy.

## P8.2 — Regenerate the commercial artefacts

- Regenerate the HTML companion from the **final** `characters.json`
  using the existing builder (`html_build/build_html.py` lineage),
  and verify programmatically: tag balance, embedded-asset magic,
  roster count and statuses matching the frozen registry,
  registry-only entries labelled and faceless where they have no
  portrait, demo model labelled as a demo, and the honest statement
  that live conversation runs in the Android app.
- Regenerate the storefront from the same truth set (`site/` source
  and its mirror), including edition contents and prices **as
  Richard’s current commercial decisions**, with every checkout
  link re-tested at freeze time (live HTTP result + correct product
  mapping recorded).
- Rebuild the Founder/Cast edition bundles and ZIP from the final
  artefacts; record ZIP SHA-256 and a contents listing; prove the
  ZIP’s HTML hash equals the regenerated HTML hash.
- Retire or correct every stale artefact: any surface still saying
  **22** characters/registry, promising portrait drops for registry
  entries that are EXCLUDED, or describing the pre-Danny roster is
  a P8-blocking defect.

## P8.3 — Claims sweep (ledger, not vibes)

Create a claims ledger with one row per externally visible claim in:

- `site/index.html`, `site/store.html` and mirrors;
- `html_build/rich-gang-ai.html` and `html_build/store.html`;
- `docs/SALES_LISTING_DRAFT.md`, `docs/SALES_ONEPAGER.md`;
- `release/listing_kits/*`;
- the app’s own store-facing text, if a channel listing is prepared.

Each row records: exact claim text, surface, claim type
(feature / count / price / performance / availability / privacy /
local-offline / valuation), evidence pointer (phase + run ID or
artefact hash), disposition (**keep / reword / remove**), and
Richard’s approval.

Mandatory dispositions already known:

- roster counts: **23 registry / 9 configured** today; marketed
  count is whatever P3 froze — never “23 fully-configured agents”;
- “sub-5 ms failover”, “99.9999% availability”, “hardware JWT age
  assurance”, memory-mapped GGML/ONNX/WebGPU weights, “zero-copy”
  performance, TRAIGA/compliance claims: **remove** unless a phase
  in this program produced qualifying evidence (none has);
- Deepgram naming: the built client is **Nova-3 STT + Aura-2 TTS**
  shapes — and Deepgram is claimable only if P2/P6 wired and proved
  a workflow;
- “local / on-device”: true for the Rust daemon, memory, and app
  logic as built; **not** a claim that LLM inference runs locally
  unless P5 L1–L3 passed; Ollama wording must name its actual
  topology;
- valuation and prices: presented as Richard’s asking prices /
  position, never as appraised or market-verified value;
- availability/support claims: only what Richard will actually
  operate (delivery method per sale, update policy tied to the
  production signing identity).

## P8.4 — Channel readiness (no channel is assumed)

- Direct APK distribution: production-signed APK + install/update
  instructions proven on the A16 + the support/reset wording from
  P7.
- Any app-store channel: a separate channel-policy check is
  recorded before submission (account, content/age policy,
  data-safety declarations matching the P7 privacy map). This
  program does not assert any store will accept the product.
- Any marketplace/listing channel: the listing uses only the
  approved claims ledger; channel-specific identity/verification
  gates are Richard’s to complete personally.

## P8.5 — Final approval package (Richard-only decision)

The package presented to Richard contains exactly:

1. candidate manifest (P0) with APK SHA-256, signer fingerprint,
   `.so` SHA-256, roster/config hashes;
2. suite + release-gate outputs for that candidate;
3. P1 device run sheet + screenshot pack (P4);
4. P2 provider matrix with run IDs for the marketed set;
5. P3 roster matrix + Danny disposition;
6. P5/P6 exclusion list (what the flagship deliberately does **not**
   claim);
7. P7 age + security/privacy records;
8. claims ledger with the exact final copy;
9. known limitations, in plain language, that will ship with the
   product;
10. rollback/withdrawal plan: how a bad build or bad listing is
    pulled, and which artefact hash replaces it.

**Invalidation rule:** any change to the APK, native library,
roster, provider set, or approved copy after Richard’s approval
voids the approval for the changed surface and requires a delta
approval naming the change and its new evidence.

**P8 exit decision:** PASS only with Richard’s recorded approval of
the package above. Until then, the publish gate remains **CLOSED**,
even if P0–P7 all pass.

---

# 14. Phase map (one-line status)

| Phase | Status today | Closes when |
|---|---|---|
| P0 Unblock | **Blocked** — `other_tcp` is Richard’s switch; no APK exists | Hash-identified APK installed on the A16; signing lineage explicit |
| P1 Device truth | **Not started** | Full A16 run sheet passes on one candidate |
| P2 Provider truth | **Blocked** | Every marketed provider passes its one app-level proving call |
| P3 Roster truth | **Partial** — disposition for all 23 recorded in `docs/ROSTER_DISPOSITION_2026-10-23.md` (10 configured incl. Danny voice-uncast; 13 registry-only excluded); Danny + 21+ decisions are Richard's | Marketed cast frozen; nine verified on device; 14 each promoted or excluded; Danny decided |
| P4 Cinematic polish | **Partial** — sweep 2026-10-23 landed P4-01/02/07/13 and parts of 05/08/11/12 (`docs/FLAGSHIP_SWEEP_2026-10-23.md`); open: P4-06 error card, P4-09/P4-10 dispositions (Richard), P4-12 remainder | P4-01…P4-13 fixed/disposed; Richard approves the A16 screenshot pack |
| P5 Local frontier | **Decided** — `docs/P5_DECISION_2026-10-23.md`: LanceDB rejected, tokio parked, llama-cpp-2 design-only gated on Richard's model pick; nothing local-frontier is marketed | llama/LanceDB gates pass for marketed claims; everything else recorded as excluded |
| P6 Plumbing → product | **Partial** — store now serves a named workload (runtime provenance) under the shipped runtime config, VM-verified; ring + topology deferred/unmarketed by record; two-daemon canonical-owner decision recorded (shared config source, Dart handle owns file-backed state) | Each component serves a proven workload under shipped config, or is deferred/unmarketed |
| P7 Safety & trust | **In progress** — sweep 2026-10-23: fail-closed AgeAssurance boundary implemented (21+ locked at every enforcement point; no vendor configured); SEC-02/04/06/07 remediated in code, SEC-05 wording corrected, SEC-01 token-source abstraction built (server-endpoint decision is Richard's; SEC-01 remains the open high finding until he decides) | Verified age assurance passes its matrix (or 21+ excluded); security review has no open high finding |
| P8 Commercial finish | **Not started (final candidate)** — preparation done in the sweep: claims ledger complete, roster disposition written, HTML regenerated from the current registry, PROPOSED corrected sales draft awaiting Richard | Artefacts regenerated from truth set; claims ledger complete; Richard approves the exact package |

---

# 15. Richard-only blockers (shortest list, in unblock order)

1. **APK permission:** In the Muse **web app** — muse.ai →
   Settings → Permissions → Direct network protocols — set
   **other_tcp** from **Deny** to **Ask**; then approve the Gradle
   daemon card when the next build prompts. (The Android-app toggle
   does not govern this VM.)
2. **A16 access:** Connect/unlock the Galaxy A16 for the build and
   P1 sessions, accept the USB-debugging prompt if Android shows
   one, and make the permission choices the run sheet calls for
   (notifications, microphone) when the device asks.
3. **Production signing identity:** Create/control the Android
   release keystore and enter its password only through a secure
   flow (never chat or docs); the package records only the alias +
   certificate fingerprint. Without this, only debug-signed internal
   test builds can exist. (Step-by-step: `docs/SIGNING.md`. Since
   Tranche 1, release builds fail fast with `signing_not_configured`
   instead of falling back to the debug key.)
4. **Provider scope + credentials:** Choose which providers will be
   marketed, then enter each chosen provider’s key **on the A16**
   in Settings (NVIDIA / OpenAI / Gemini / ElevenLabs / LiveAvatar,
   and Deepgram only if a Deepgram workflow is wired in P6), supply
   the Ollama server + model if Ollama will be marketed, and
   confirm the nine ElevenLabs voice IDs in your own ElevenLabs
   account (or supply replacements).
5. **Avatar IDs:** For every character who will be marketed for
   video calls, supply that character’s **LiveAvatar avatar ID**
   from your LiveAvatar account (HeyGen IDs do not carry over);
   HeyGen legacy IDs are needed only if you override its default
   exclusion.
6. **Danny’s voice:** Pick Danny’s real ElevenLabs voice in your
   account and supply its exact name/ID — or approve Danny as
   EXCLUDED from flagship marketing. No voice, no promotion.
7. **21+ method:** Choose the verified age-assurance provider/
   method and open its account — or approve excluding all 21+
   characters (Crazy Kelly; Shawna; Ruby) from flagship access and
   marketing.
8. **Final approval:** Review the P8 package and record approval of
   the **exact** APK hash, signer, roster, provider set, and copy.
   Any later change to those needs a delta approval.

Conditional (only if you want the claim): to market **local
inference** or **semantic memory**, choose the licensed model in
the P5 model record (source, quant, delivery, size) — otherwise
the flagship ships cloud + Ollama and needs nothing from you here.
To market a **shipped interrogation scene**, supply the scene data
— otherwise Interrogation is demoted/labelled and needs nothing.

---

# 16. Highest-leverage next action

**Richard sets `other_tcp` to Ask in the Muse web app (blocker 1),
and the P0 build/install runs immediately after.**

It is the single action that converts every VM-side claim in this
program into testable device truth: it unblocks the APK, the A16
run sheet, provider live calls in the shipped UI, roster device
verification, real performance measurement, and the final signed
candidate. Every other phase’s evidence depends on it or is worth
less without it.
