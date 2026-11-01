# SECURITY & PRIVACY REVIEW — Rich Gang AI

Date: 2026-10-23 (Flagship Tranche 1, P7 preparation).
Scope: source-level review of the Flutter app, Android shell, and
Rust daemon in `~/workspace/rich_gang_ai`. This is a written review
artefact, **not** a P7 pass: there is no APK/device evidence yet,
no live provider account was exercised, and several findings below
are open.

Method: read the actual storage, network, FFI/JNI, manifest,
provider, and settings code named in each finding. A parallel
Danny flagship workstream was landing core files during the review
window; Danny-specific stores are inventoried from the files as
reviewed, and the whole review must be re-run against the frozen
P0 candidate before P7 can close.

## Executive verdict

**P7 security/privacy: NOT PASSED.**

Positive foundations are real: provider keys are held in
Keystore-backed secure storage, provider traffic is HTTPS, the
network-security config permits cleartext only on loopback /
localhost / the emulator host, the dream service is not exported,
and the Rust FFI boundary is panic-wrapped with an explicit
ownership contract.

Blocking posture: one **high** finding is already architectural
(LiveKit API secret on-device), verified age assurance is absent
(see `docs/AGE_ASSURANCE_DESIGN_2026-10-23.md`), backup/deletion
behaviour is unspecified in code, and Settings offers no in-app
per-key removal path even though deletion methods exist.

## Severity key

- **High** — must be fixed or the affected feature excluded before
  a flagship/commercial build ships.
- **Medium** — must be fixed or explicitly accepted by Richard with
  a recorded disposition before P7 closes.
- **Low / Info** — hygiene, evidence, or defence-in-depth items.

---

## 1. Keys and secrets inventory

All rows below are stored through `SecureKeys`
(`flutter_app/lib/core/secure_keys.dart`) in
`flutter_secure_storage` with Android Keystore-backed options.
None is stored in SharedPreferences or source.

| Secret | Storage key | Read by | On-device commercial disposition |
|---|---|---|---|
| NVIDIA API key | `nvidia_api_key` | `NvidiaProvider` via router | User's own key on user's device: acceptable pattern; prove live in P2 |
| OpenAI API key | `openai_api_key` | `OpenAiProvider` | Same |
| Gemini API key | `gemini_api_key` | `GeminiProvider` | Same |
| ElevenLabs API key | `elevenlabs_api_key` | `VoiceEngine` | Same |
| HeyGen API key | `heygen_api_key` | `HeyGenClient` / legacy streaming + video client | Legacy path is pre-flight-failing per program; disposition in P2/P6 |
| LiveAvatar API key | `liveavatar_api_key` | `LiveAvatarService` | Same, plus per-character IDs in prefs (not secrets) |
| Deepgram API key | `deepgram_api_key` | `DeepgramClient` — **no production caller found** | See SEC-06 |
| LiveKit API key | `livekit_api_key` | `LiveKitService.connect` | Key alone would be low-risk; the pair below is not |
| **LiveKit API secret** | `livekit_api_secret` | `LiveKitService` → `mintLiveKitToken` (on-device HS256) | **SEC-01 — High** |

Non-secret configuration held in the session-only `AppSettings`
singleton (`flutter_app/lib/core/settings.dart`): provider/model
choices, Ollama base URL/model, LiveKit project URL, HeyGen
avatar/voice IDs, Crew Link flag. Per-character LiveAvatar IDs and
stage overrides are in SharedPreferences (see §4).

### SEC-01 — HIGH — LiveKit API secret lives on-device and mints broad tokens

- Evidence: `flutter_app/lib/core/livekit_service.dart` states the
  fact in its own header and implements it: `mintLiveKitToken`
  signs HS256 JWTs with the API secret from secure storage.
  Default TTL is **6 hours**; grants are `roomJoin`, `canPublish`,
  `canSubscribe`, and `canPublishData` for the requested room.
- Why it matters: anyone who extracts the secret from a shipped
  device/build can mint equivalent tokens until the secret is
  rotated. Secure storage raises the extraction cost; it does not
  change the fact that a server-class credential ships to clients.
- Current exposure note: no production view calls
  `LiveKitService.connect()` in the reviewed tree (Crew Link has a
  Settings surface and a token test, but no shipped join flow).
  The risk activates the moment Crew Link is wired or marketed.
- Remediation (choose one, record it):
  1. mint tokens on a Richard-controlled server endpoint with a
     short TTL and room/identity-scoped grants; the app never sees
     the secret; **or**
  2. exclude Crew Link from the flagship build and remove the
     secret field from flagship Settings.
- Status: **OPEN — blocks Crew Link, not the rest of the app.**

### SEC-02 — MEDIUM — Key deletion exists in code but not in the UI

- Evidence: `SecureKeys` has `clearNvidiaKey`, `clearElevenLabsKey`,
  `clearHeyGenKey`, `clearOpenAiKey`, `clearGeminiKey`,
  `clearDeepgramKey`, `clearLiveAvatarKey`, and `clearLiveKit`.
  `flutter_app/lib/views/settings_view.dart` renders save-only key
  fields; a source search found **no call to any `clear*` method
  from the UI**.
- Impact: a user cannot revoke a provider key from inside the app;
  the only routes are clearing app storage or uninstalling, which
  also destroys local minds/preferences.
- Remediation: add a per-key Remove control wired to the existing
  `clear*` methods, show the resulting “no key saved” state, and
  device-test that the provider then fails explicitly.
- Status: **OPEN.**

### Log sweep (this review)

- Dart `debugPrint` sites are in `main.dart` only: launch-counter,
  config-load, mind-boot errors, and the daemon version line. No
  key, token, prompt, or config value is printed there.
- Kotlin logs record notification-permission denial, daemon
  start/stop, tick counts, and exceptions — no secrets or prompts.
- Rust FFI error logs can include filesystem paths from daemon
  config errors (for example an unopenable store/ring path). Paths
  are not credentials, but the final candidate needs a device
  Logcat sweep before P7 closes.
- Status: **no secret-logging defect found in source; device
  evidence still required.**

---

## 2. IPC / FFI / JNI surface

### Inventory

- Dart↔Rust: 26 `rga_*` exports (ABI 2), declared in
  `rich_gang_ai_core/include/daemon.h` and implemented in
  `rich_gang_ai_core/src/ffi.rs`: lifecycle, agent query, dream
  tick, scene apply/state, affect grammar, personas,
  remember/recall, witness facts/statements, dream broadcast,
  topology state/reachability, SQLite store state/put/get/delete,
  ring state/send/recv, and `rga_string_free`.
- Kotlin↔Rust JNI: four entries on `DreamCycleService`
  (`nativeBoot`, `nativeTick`, `nativeQuery`, `nativeStop`) in
  `rich_gang_ai_core/src/jni_bridge.rs`.

### Trust model and evidence

- These are **in-process** boundaries: the library is loaded by
  the app itself; the exports are not an Android IPC surface other
  apps can call. The realistic attacker is malformed local data /
  config, not a remote caller.
- Boundary discipline is explicit and tested in source:
  `ffi.rs` documents the string-ownership contract, validates
  handles via `handle::is_live`, builds JSON only via serde, and
  wraps bodies in `catch_unwind`; `Cargo.toml` keeps release
  `panic = "unwind"` with the comment that an FFI panic must not
  kill the process. JNI mirrors the same catch-and-sentinel rule.
- Config trust assumption to keep explicit: `rga_daemon_start`
  accepts a JSON config that may name filesystem paths
  (`store_path`, `ring_path`). Today the shipped
  `daemon_config.json` contains **only `personas`** (verified in
  this review), so no file-backed store/ring is opened by the
  shipped config. Any future shipped path becomes a P6 decision
  with app-private storage only.
- Two-handle integrity fact (Flagship F-02): the Dart handle boots
  with the bundled config; the Kotlin dream-service handle boots
  with `"{}"`. Until P6 chooses one canonical owner, no claim may
  be made that both handles share store/ring/topology state.
- Ring integrity wording: the ring's CRC-32 detects corruption /
  torn records. It is **not** authentication and must never be
  described as tamper-proofing.

### SEC-03 — MEDIUM — FFI surface is safe in-process today; the shipped-config rule must be locked

- Remediation: add a release-checklist rule (P0/P8) that any
  change to shipped `daemon_config.json` keys — especially
  `store_path` / `ring_path` — requires a security note naming the
  exact app-private path, the owning handle, and the failure mode.
- Status: **OPEN as a process control; no code defect found.**

---

## 3. Provider data flows (privacy map)

What actually leaves the device, from the call sites:

| Flow | Destination | Payload that leaves | Evidence |
|---|---|---|---|
| Cloud chat / Roundtable / dream text | Selected provider: NVIDIA `integrate.api.nvidia.com`, OpenAI `api.openai.com`, or Google `generativelanguage.googleapis.com` | The full composed prompt: character system prompt (persona definition), recalled on-device memories block when present, web-search block when a search ran, and the user's message / table transcript | `character_agent.dart` (`reply`, `roundtablePrompt`), `inference_router.dart` |
| Ollama fallback / local-only tasks | The user-configured Ollama base URL (default `http://127.0.0.1:11434/v1` — the phone itself) | Same composed prompt, sent to that endpoint instead | `ollama_provider.dart`, `settings.dart` |
| ElevenLabs voice | `api.elevenlabs.io` | The reply text to synthesise + the character's voice ID + prosody settings | `voice_engine.dart` |
| LiveAvatar calls (FULL mode) | `api.liveavatar.com` + LiveKit media path returned by the service | A server-side Context built from the character definition (name, prompt from core/personality/speech style/interests, opening line); session requests carry avatar/context/voice IDs; microphone audio and conversation are then handled on LiveAvatar's side, as the call UI discloses | `liveavatar.dart` (`contextPromptFor`, `createContext`, `createSessionToken`) |
| Legacy HeyGen | `api.heygen.com` | API key, avatar/voice IDs, speak-task text on the legacy path; video-generation client exists separately | `heygen.dart`, `heygen_video.dart` |
| Web search | DuckDuckGo Instant Answer (`api.duckduckgo.com`) and Wikipedia (`en.wikipedia.org`) | The user's query text that triggered the search heuristic | `web_search.dart`, `character_agent.dart` |
| Deepgram | `api.deepgram.com` | **Nothing today** — the client (Nova-3 STT / Aura TTS shapes) has no production caller | `deepgram_client.dart`; see SEC-06 |

### SEC-04 — MEDIUM — No in-app privacy surface states these flows

- Evidence: a source search of `flutter_app/lib` found no privacy
  disclosure screen or plain-language statement of the table above.
  The LiveAvatar call UI does disclose that LiveAvatar runs the
  conversation pipeline; nothing equivalent exists for cloud chat
  prompts (which include recalled memories) or search queries.
- Remediation: add a Settings-reachable privacy panel whose text
  is generated from / checked against this map at P8 freeze, and
  remove from the marketed set any provider Richard does not
  accept on these terms.
- Status: **OPEN.**

### SEC-05 — MEDIUM — Ollama endpoint is user-configured; keep the cleartext wall exactly as-is

- Evidence: `network_security_config.xml` permits cleartext only
  for `127.0.0.1`, `localhost`, and `10.0.2.2`. The Settings helper
  text suggests using a laptop IP for Ollama, but an `http://` LAN
  address is **not** inside the cleartext exception, so Android
  should refuse it rather than silently send prompts in cleartext.
  That is the safe behaviour — and it makes the helper text
  misleading until the topology is decided.
- Remediation: decide the marketed Ollama topology in P2/P6
  (on-device/Termux, emulator host, or a named LAN host over
  HTTPS). If a LAN exception is ever approved, it names one exact
  host — never a wildcard or subnet. Update the helper text to
  match the decided topology.
- Status: **OPEN (decision + wording).**

### SEC-06 — MEDIUM — Credential fields exist for workflows with no consumer

- Evidence: `DeepgramClient` has no caller outside its own file;
  `HeyGenVideoClient` has no caller outside its own file;
  `LiveKitService.connect` has no production caller. Settings still
  presents Deepgram and LiveKit key fields as product settings.
- Impact: users are asked to hand credentials to surfaces that
  cannot use them, expanding secret-handling scope for no product
  function and weakening the flagship's truth-in-UI standard.
- Remediation (per service, in P6): wire it to a named workflow
  and live-test it, move it behind a clearly-labelled non-flagship
  surface, or remove its Settings field from the flagship build.
- Status: **OPEN.**

---

## 4. Local data, backup, deletion

### Inventory (SharedPreferences unless noted)

| Data | Key / location | Sensitivity |
|---|---|---|
| Mind store: affect snapshots + self-models (interactions, affinities, learned interests, reflections, open loops) | `mind_store_v1` (`persistent_mind.dart`) | Personal behavioural state |
| Launch counter | `launch_count` (`main.dart`) | Low |
| Age confirmation (current gate) | `age_21_confirmed` (`character_ui.dart` `AgeGate`) | Must never be treated as verified age — see age design doc |
| LiveAvatar per-character avatar/voice/context IDs | `liveavatar_avatar_*`, `liveavatar_voice_*`, `liveavatar_context_*` | Config IDs, not secrets |
| HeyGen per-character avatar IDs | SharedPreferences (`heygen.dart`) | Config IDs |
| Stage model overrides | `avatar3d_src_<characterId>` | User-supplied URL/path — see SEC-08 |
| Danny ledger + upgrade state (parallel workstream files) | SharedPreferences (`danny_ledger.dart`, `danny_upgrades.dart`) | Behavioural record; re-verify at freeze |
| Provider keys | Secure storage (§1) | Secrets |
| Rust store / ring files | Only if a future config names `store_path` / `ring_path`; shipped config names neither | Content-dependent |

### SEC-07 — MEDIUM — Backup behaviour is unspecified in code; no reset / remove-all exists in the UI

- Evidence: the manifest sets no `android:allowBackup`, no
  `fullBackupContent`, and no `dataExtractionRules`; no backup
  rules XML exists in the app. A source search found **no**
  reset-my-data, remove-all-keys, or delete-local-state UI
  anywhere in `flutter_app/lib`.
- Impact: what Android Auto Backup / device transfer would carry
  (preferences, and therefore mind state and the age-confirmation
  flag) is currently decided by platform defaults, not by a
  recorded product decision. A restored age *confirmation* must in
  any case never become a restored age *verification* (age design
  doc §4).
- Remediation:
  1. record an explicit backup policy and implement it
     (allow/exclude per data class, with verification state always
     excluded or re-proven after restore);
  2. add and device-test **Reset my data** (mind + preferences +
     Danny stores) and **Remove all API keys** (secure storage),
     with wording that matches observed behaviour;
  3. document app-data-clear / uninstall effects from a real A16
     run in P1/P7 evidence.
- Status: **OPEN.**

### SEC-08 — LOW — Stage accepts user-supplied model URLs

- Evidence: `avatar_stage_view.dart` stores a per-character source
  string accepting an `https://…/model.glb` URL or an asset path.
- Impact: a user can point their own build at arbitrary remote
  model content. That is a deliberate power-user feature on a
  personal build; for a commercial build it needs a stated policy
  (own-device choice vs shipped surface).
- Remediation: record the disposition in P4-09/P6; if retained,
  label it as user-supplied content in the UI.
- Status: **OPEN (disposition only).**

---

## 5. Permissions minimisation

Manifest (`flutter_app/android/app/src/main/AndroidManifest.xml`):

| Permission | Named workflow today | Disposition |
|---|---|---|
| INTERNET, ACCESS_NETWORK_STATE | All provider/search calls | Keep |
| RECORD_AUDIO | Hands-free chat; LiveAvatar/LiveKit calls | Keep |
| CAMERA | Video-call surfaces | Keep only if a marketed call flow uses it; verify in P1 |
| POST_NOTIFICATIONS | Dream-cycle foreground service | Keep |
| FOREGROUND_SERVICE + FOREGROUND_SERVICE_SPECIAL_USE | DreamCycleService | Keep |
| RECEIVE_BOOT_COMPLETED | BootReceiver → WorkManager re-arm | Keep; receiver is `exported=true` but its only filter is the system-protected BOOT_COMPLETED broadcast — verify on device |
| WAKE_LOCK | Foreground/dream work (WorkManager/Flutter) | Justify at freeze or remove |
| ACCESS_WIFI_STATE, CHANGE_NETWORK_STATE, CHANGE_WIFI_MULTICAST_STATE | Inherited for LiveKit / future mesh; **no shipped consumer named** | Remove or justify in writing at freeze |
| BLUETOOTH, BLUETOOTH_ADMIN (≤30), BLUETOOTH_CONNECT | LiveKit device list heritage; **no shipped Bluetooth workflow** | Remove or justify in writing at freeze |
| MODIFY_AUDIO_SETTINGS | Call/hands-free audio routing | Justify at freeze |

### SEC-09 — MEDIUM — Permission set is broader than the shipped workflows

- Remediation: at the P0/P8 freeze, every permission in the final
  manifest maps to a marketed workflow with a denied-permission
  device result, or it is removed. The Bluetooth/multicast/Wi-Fi
  group above is the first removal candidate list.
- Status: **OPEN.**

Component exposure (positive): `DreamCycleService` is
`exported=false`; `MainActivity` is `exported=true` as the launcher
entry (normal); no custom exported intent filters were found
beyond BOOT_COMPLETED.

---

## 6. Release hygiene

- **Fixed in Tranche 1:** release builds no longer sign with the
  Android debug key; production signing fails fast with
  `signing_not_configured` when unconfigured
  (`docs/SIGNING.md`). Gradle-runtime proof is still blocked by
  the `other_tcp` daemon permission.
- **Fixed in Tranche 1 (P4):** the production “Test thermal
  severe” simulation control and the static NEXUS strip were
  removed from The Room, reducing shipped test surface.
- Network security config: HTTPS by default; cleartext limited to
  loopback/localhost/emulator host (see SEC-05 — keep it that way).
- Dependency/toolchain versions for the candidate belong in the
  P0 manifest; this review does not substitute for that record.

## 7. What closes P7 (security half)

1. SEC-01 disposition implemented (server minting or Crew Link
   exclusion) and proven on the candidate.
2. SEC-02 remove-key UI wired and device-tested.
3. SEC-04 privacy panel shipped and checked against §3.
4. SEC-05 Ollama topology decided; helper text corrected.
5. SEC-06 per-service disposition recorded and applied.
6. SEC-07 backup policy implemented; reset/remove-all device-
   tested.
7. SEC-09 final manifest minimised with per-permission evidence.
8. Device Logcat sweep on the frozen candidate shows no secret,
   token, or prompt logging.
9. SEC-03 shipped-config rule added to the P0/P8 checklist.
10. Age assurance passes its own matrix — or the 21+ exclusion is
    in force (see the age design doc).

**Fixed in this tranche:** the two release-hygiene items in §6.
**Everything else in this review is OPEN and is not represented as
fixed.**
