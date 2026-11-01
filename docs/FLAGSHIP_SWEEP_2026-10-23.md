# FLAGSHIP SWEEP — 2026-10-23

Order: Richard — “Take care of everything that needs to happen.”
Scope: every remaining agent-buildable item in the flagship program.
No publishing. No edits to `docs/SALES_LISTING_DRAFT.md`.

Checkpoint rule: each item is recorded here as soon as it lands,
with its evidence. A skipped item records the precise blocker and
the safest partial step taken instead.

## Settled starting state (given, re-verified at close-out)

- cargo 78/78; flutter analyze clean; flutter test 69/69;
  `tools/release_gate.sh --suites` PASS.
- Staged `libdaemon.so` SHA-256 `a8c41581…`.
- Roster truth: **23 entries = 10 configured + 13 registry-only**.
  Danny is `configured_voice_uncast`: portrait and baselines are
  wired; his ElevenLabs voice is UNCAST (empty ids — inventing one
  is forbidden).
- Production signing fails fast with `signing_not_configured` when
  unconfigured (code-level; Gradle-runtime proof still blocked by
  the `other_tcp` permission).
- Collision check at sweep start: no file in the edit set had been
  modified inside the preceding 10 minutes.

## Work log

- [partial] A. P4 remainder + two-daemon canonical owner
  (checkpoint below).
- [done] B. P7 implementation (checkpoint below).
- [done] C. P6 shipped runtime config / store workload
  (checkpoint below).
- [done] D. P5 decision record (checkpoint below).
- [done] E. P3/P8 preparation artefacts (checkpoint below).
- [done] F. Close-out suites + release gate + final lists
  (below).

## A checkpoint — P4 items landed (VM-verified)

- P4-01: The Room now renders a primary **configured cast** grid
  (portrait-forward cards; emotion/talk state from the loaded mind;
  Danny carries a visible "VOICE UNCAST — SYSTEM TTS" badge) and a
  separate collapsed **"REGISTRY — NOT CONFIGURED"** section.
  Registry entries explain the missing configuration and do not open
  a finished-character chat. The hero count reads configured /
  registry-only, never the registry total as a ready count.
- P4-02: configured cards are portrait-forward (asset portrait fills
  the card; avatar fallback when no portrait exists).
- P4-05 (partial): Room SETUP & HEALTH no longer calls a saved key
  "configured" — it says "key saved (unverified)", calls the Ollama
  probe "probe reachable (not a chat proof)", and keeps system TTS
  labelled as the fallback. The full five-state Verified-live state
  still requires P2 evidence and is not claimed.
- P4-07: Roundtable "All" is now "All configured"; registry-only
  chips are disabled and labelled "(not configured)"; while a session
  is running/paused the full setup collapses to a compact session bar
  (status, topic, cast count, pause/resume/stop, failure); a failure
  offers "Check Settings" and "Start again".
- P4-08 (partial): the call screen now leads with a preflight card
  (LiveAvatar key saved/missing, per-character avatar ID
  entered/missing, FULL-mode brain disclosure), disables Start until
  LiveAvatar preflight passes, moves per-character IDs and the saved
  context into "Advanced & IDs", moves the raw session log into
  "Diagnostics", and disables the HeyGen segment in this build
  (legacy path not live-call verified).
- P4-11: Tier10Hud now displays configured / registry-only / total
  counts from the loaded registry (controller carries all three).
- P4-12 (partial): bottom-navigation destinations are hosted in an
  `IndexedStack`, so tab state survives switching.
- P4-13: the unreachable standalone `ChatConsoleView` was removed
  (recoverable trash id
  `20261023-182854-2984d265b3e347e0bef024d8aea7fe3e`); the
  in-character chat is the one chat surface.
- P4 items still open: P4-06 structured provider-error card with
  retry/settings/user-chosen-Ollama actions (errors remain explicit
  text today); P4-09 Stage disposition and P4-10 Interrogation
  disposition (Richard decisions — the Stage still labels the demo
  robot verbatim and Interrogation still shows its honest empty
  state; neither was demoted or removed without his disposition);
  P4-12 remainder (one Settings destination — The Room still pushes
  a second Settings route; brand asset replacing the "◆" glyph;
  semantic labels).

## B checkpoint — AgeAssurance boundary landed (VM-verified)

- New `lib/core/age_assurance.dart`: one fail-closed boundary with
  the design's states (unknown / verificationRequired / pending /
  verifiedAdult / denied / unavailable), a minimal stored record
  (state, verified_at, vendor_id, opaque vendor_reference — never
  DOB/documents), and `isAuthorised(character)` as the only decision.
  No vendor is configured in this build, so a stored record alone
  never authorises: every 21+ character is locked.
- `AgeGate` in `character_ui.dart` is now only a UI adapter over
  that boundary. The old SharedPreferences `age_21_confirmed`
  self-confirmation grant is gone; the explanatory dialog says a
  self-confirmation is not verification.
- Enforcement points wired and test-locked: Room cast card, Chat
  tab picker, direct chat route (locked screen), chat **send path**
  (re-checks the boundary before any send, incl. hands-free),
  call view (locked screen + start guard), Stage (locked screen on
  a gated focus + speak guard), Roundtable cast (gated members are
  removed with an on-screen notice).
- `character_agent.dart` no longer tells the model the character is
  "behind a verified 21+ age gate"; it now says access is locked
  unless the separate boundary authorised it and forbids claiming
  verification occurred.
- Tests: `test/flagship_sweep_test.dart` (AgeAssurance unit tests:
  no-vendor record does not authorise; vendor-configured verified
  record authorises; malformed record = unavailable/locked;
  non-gated never locked; plus source locks for every enforcement
  point) and updated `test/flagship_p4_test.dart`. Targeted run:
  12/12 passed; `flutter analyze` clean at this checkpoint.

## B checkpoint — security remediations landed (VM-verified)

- SEC-02: Settings now has a remove control for **every** stored
  credential — NVIDIA, ElevenLabs, HeyGen, LiveAvatar (hand-rolled
  fields) and OpenAI, Gemini, Deepgram, LiveKit key + secret (the
  shared `_apiKeyField`, whose remove invokes the existing
  `SecureKeys.clear*` methods; removing either LiveKit field
  removes the pair, and the UI says so). Plus **Remove all API
  keys** (`SecureKeys.clearAll`, new) behind a confirmation dialog
  that names every credential removed.
- SEC-04: new in-app privacy surface, `lib/views/privacy_view.dart`,
  reachable from Settings → "Privacy — what leaves this device".
  Its rows mirror the security review §3 map exactly: cloud prompt
  composition (persona + recalled memories + search block + user
  message), Ollama endpoint, ElevenLabs payload, LiveAvatar FULL
  mode (server-side Context + mic audio handled on LiveAvatar's
  side), legacy HeyGen, search queries to DuckDuckGo/Wikipedia,
  Deepgram = nothing sent (no production caller), Crew Link = no
  shipped caller today.
- SEC-05 wording: the Ollama helper text now matches the cleartext
  wall (127.0.0.1 / localhost / 10.0.2.2 only; a LAN `http://`
  address will be refused). The topology decision itself remains
  Richard's (P2/P6).
- SEC-06: orphan credential fields are labelled, not removed —
  Deepgram: "NOT WIRED IN THIS BUILD … stored but unused. Nothing
  is sent to Deepgram." HeyGen key: legacy labelling (call segment
  disabled in this build; video-generation client has no shipped
  workflow). HeyGen video-generation IDs section: "NOT WIRED IN
  THIS BUILD" note. LiveKit fields: "No shipped screen calls the
  Crew Link service today" note.
- SEC-01: token-source abstraction in `livekit_service.dart`.
  `AppSettings.liveKitTokenEndpoint` (session-only, like the
  project URL): when set, `LiveKitService.obtainToken` POSTs
  `{room, identity}` to it and expects `{"token": ...}` — the
  on-device secret is never read, and a failed/invalid server
  response is an explicit error with NO fallback to on-device
  minting. When empty, the existing gated on-device minting is
  unchanged (Crew Link flag + URL + key/secret, all still checked
  in `connect`). Settings copy labels on-device minting as a
  private-build risk (SEC-01) and states a shipped product must
  use a server endpoint or exclude Crew Link. The decision —
  Richard's server endpoint vs Crew Link exclusion from the
  flagship — remains Richard's and is on the final list.
- SEC-07: backup behaviour is now explicit. Manifest declares
  `fullBackupContent` + `dataExtractionRules`; both rule files
  exclude the whole shared-preferences domain and the daemon
  SQLite store files from cloud backup AND device transfer.
  Policy: local state (mind, Danny stores, discernment record,
  IDs — and the age-assurance record above all) is device-local
  and never rides a backup into a restored "verification"; a new
  device starts fresh. Plus **Reset local data** in Settings,
  backed by `lib/core/local_data_reset.dart` (an explicit key
  inventory: mind store, Danny ledger/upgrades, lie-detector
  record, age-assurance + legacy confirmation keys, launch
  counter, LiveAvatar/HeyGen/Stage per-character prefs; it also
  deletes the daemon store's runtime-provenance keys when the
  daemon is up). The dialog and result message state the honest
  limit: in-memory stores clear on the next app start.
- Tests: sweep suite now 17 tests (LocalDataReset inventory +
  removal-scope tests; LiveKit token-source precedence test with
  an injected fetcher; Settings/manifest/rules source locks).
  `flutter analyze` clean at this checkpoint.

## A/C checkpoint — two-daemon decision + P6 runtime config landed

**Decision (F-02): one shared config source, one canonical owner.**
A single owner *process* was not safely buildable in this sweep:
the dream service needs its own JNI handle to tick, and handing
it the Dart handle does not exist as a pattern in this codebase.
What landed instead is the safest partial step the task named:

- Both handles now read the SAME source — the bundled
  `assets/daemon_config.json`. `DreamCycleService` no longer boots
  `nativeBoot("{}")` (default personas, divergent from the UI); it
  loads the asset via `loadSharedDaemonConfig()`, so the personas
  roster both handles see is identical.
- The **Dart/UI handle is the canonical owner of all file-backed
  daemon state**. The Kotlin handle's copy has `store_path`,
  `ring_path`, `causal_links`, and `facts` stripped: it is a
  tick-only handle and must never become a second writer to the
  SQLite store or the mmap ring, nor hold a second copy of the
  scene fact table. A config it cannot read/parse is logged in
  logcat and degrades that handle only to `"{}"` — visible, never
  silent.
- Remaining divergence, stated plainly: the two handles still hold
  separate in-memory daemon state (memories remembered through
  the UI handle are not in the service handle's daemon). Unifying
  in-memory state needs an IPC design (the ring is the candidate
  channel) and is NOT claimed here. Recorded as a P6 follow-up,
  not a solved item.

**P6 shipped config (C):**

- `lib/core/daemon_config.dart` (new): `DaemonConfig.withStorePath`
  extends the asset config with a `store_path` under the app
  support directory (`<support>/rich_gang_ai/daemon_store.sqlite3`),
  throwing a FormatException on a malformed asset instead of
  silently booting a different daemon. `path_provider` is now a
  direct dependency (was transitive; version unchanged, 2.1.6).
- `main.dart`: resolves the support directory, creates the store
  directory, and boots the daemon with the runtime config. If the
  support directory cannot be resolved, the daemon boots with the
  asset config unchanged and the store reports itself session-only
  (`persistent: false`) — logged, not hidden. A `store_path` that
  cannot be opened still fails daemon start outright (existing
  daemon semantics, preserved).
- **First named store workload: the runtime-provenance record.**
  At every boot the app writes `runtime.config_schema` = "1" and
  `runtime.last_boot_at` = the UTC boot time into the durable
  store. It is a real, read-back-able dataset (the durable-store
  proof on later launches) — and it is the ONLY dataset claimed;
  no product dataset has been migrated onto the store, and none
  is marketed. Danny's stores remain on SharedPreferences.
- **Ring: stays disabled.** No first ring workload was named in
  this sweep — the honest candidates (dream-broadcast delivery,
  UI↔service state sync) both need the IPC design above, which is
  a decision + build of its own. Shipping `ring_path` without a
  workload would be plumbing presented as product; the program's
  own rule forbids it. The ring's FFI surface remains available
  and unconfigured, exactly as its state surface reports.
- No Rust or `native_bridge.dart` change was needed (the store
  FFI already existed), so no `.so` rebuild/restage was triggered
  by this item; the release gate still runs at close-out.
- Tests: DaemonConfig unit tests (path composition, personas
  preserved, malformed asset throws), Kotlin + main source locks
  in `test/flagship_sweep_test.dart`.

## D checkpoint — P5 decision record

Created `docs/P5_DECISION_2026-10-23.md`:

- **LanceDB REJECTED** on the spike evidence (upstream
  default-features compile bug, 521-crate/~13 GB cost, `remote`
  workaround dragging a server stack into a local store).
  Semantic memory stays rusqlite + lexical until a lighter
  candidate earns a spike.
- **llama-cpp-2: integration DESIGN only** — shortlist with
  licence + size checked from publisher/quant-repo sources on
  2026-10-23 (no downloads): Qwen2.5-1.5B-Instruct-GGUF Q4_K_M
  ≈1.0 GB, Apache-2.0 (primary); Llama-3.2-1B-Instruct GGUF
  Q4_K_M ≈0.77–0.81 GB, Llama 3.2 Community License, gated
  (viable); Qwen2.5-3B evaluated and rejected on licence
  (research-only checkpoint) and RAM. Size budget proposed
  (model ≤1.2 GB; the 74 MB **debug** libllama warning carried
  verbatim; release size + A16 RAM to be measured). FFI outline
  (edge_inference wiring, model in app files dir, explicit
  `no_model_configured` / `model_file_missing` /
  `model_load_failed` states). Gated on Richard's pick.
- **Tokio PARKED** — no current consumer; only future consumer
  is the unbuilt UDP mesh.

## E checkpoint — P3/P8 preparation artefacts

- `docs/ROSTER_DISPOSITION_2026-10-23.md` — all 23 entries from
  the registry itself: status, marketable/excluded, and exactly
  what's missing per character (Danny: voice pick or marketing
  exclusion; Kelly/Shawna/Ruby: also the P7 decision; the nine:
  account voice-ID confirmation + LiveAvatar IDs + device
  matrix). Marketable today: 0 (the app has no P1/P2 proof).
- `docs/CLAIMS_LEDGER_2026-10-23.md` — every claim in the
  approved draft, one-pager, storefront, and the supplied
  prospectus mapped to evidence, CORRECT (stale counts: 22→23,
  9→10 configured, 43/43 tests, store.html's "22-character
  registry" Founder perk), or DELETE (sub-5 ms failover,
  99.9999% availability, memory-mapped GGML/ONNX/WebGPU weights,
  hardware JWT age assurance, "22 fully-configured agents",
  Deepgram "Nova-2", prospectus valuations as fact).
- HTML companion regenerated with the existing generator
  (`html_build/build_html.py`, ran cleanly): output
  `html_build/rich-gang-ai.html` is now 3,346 KB and embeds the
  current 23-entry registry — Danny present as
  `configured_voice_uncast`, 13 registry-only entries carrying
  the template's "REGISTRY ONLY — voice & affect not configured
  yet" labelling, and the header line "10 configured agents
  (Danny leads; his voice casting still pending Richard's
  ElevenLabs pick) + 13 registry entries". Verified from the
  generated file, not assumed.
- `docs/SALES_LISTING_DRAFT_PROPOSED_2026-10-23.md` — header-
  marked PROPOSED / NOT APPROVED; the approved draft's facts,
  framing, and disclosures with ONLY stale facts corrected
  (23 entries, 10 configured with Danny's uncast voice stated
  plainly, cargo 78 / flutter counts as measured at close-out,
  the age-assurance section corrected from "confirmation-only"
  to the shipped fail-closed lock, the resolved naming items no
  longer listed as open work, HTML size ~3.3 MB). The approved
  draft was not touched.

## F close-out — measured on the settled tree (2026-10-23)

- `cargo test`: **78 passed, 0 failed**.
- `flutter analyze`: **clean** (strict options).
- `flutter test`: **101 passed, 0 failed** (69 settled pre-sweep
  + 13 from the parallel lie-detector integration + 19 added by
  this sweep: `flagship_sweep_test.dart` ×17 and two new
  `flagship_p4_test.dart` locks).
- `tools/release_gate.sh --suites`: **PASS** — staged `.so`
  freshness (SHA-256 `a8c41581…`, unchanged: this sweep made no
  Rust or `native_bridge.dart` change, so no rebuild/restage was
  triggered), 30 exports, all 26 Dart lookups resolve, LOAD
  Align 0x4000, ABI 2 == 2, and the full suites inside the gate.
- Kotlin compile is NOT verified (no Gradle run is possible —
  `other_tcp`); the DreamCycleService change is source-reviewed
  and source-locked by test only. Stated plainly: it has not been
  compiled.
- Nothing was published. `docs/SALES_LISTING_DRAFT.md` was not
  edited.

## Items skipped / blocked, with precise reasons

- **A / two-daemon single owner (full):** not safely buildable —
  no existing pattern hands the Dart daemon handle to the Kotlin
  service. Landed the safest partial: one shared config source +
  canonical-owner rule (see A/C checkpoint). In-memory state
  divergence between the handles remains, recorded, unclaimed.
- **A / P4-06 structured provider-error card:** not landed. Chat
  errors remain explicit text (provider error verbatim, "nothing
  was stored"). The card (Retry / Open Settings / user-chosen
  Ollama) needs a retry-state refactor of `_send`; it exceeded a
  clean testable change in this sweep.
- **A / P4-09 Stage + P4-10 Interrogation dispositions:** Richard
  decisions (source models / demote / remove; demote+label).
  Neither surface was altered beyond the Stage's new age lock;
  both keep their existing honest labels (demo robot labelled
  verbatim; Interrogation's honest empty state).
- **A / P4-12 remainder:** one-Settings-destination (The Room
  still pushes a second Settings route), brand asset replacing
  the "◆" glyph, semantic labels — not landed; IndexedStack
  state preservation landed.
- **A / P4-05 Verified-live state:** impossible without P2
  evidence; the first four states are honest in the UI and
  "Verified live" is not claimed anywhere.
- **C / ring workload:** none named — ring stays disabled by
  record (see A/C checkpoint). Topology likewise has no shipped
  consumer and is unmarketed.
- **B / SEC-03 + SEC-09:** no code change (FFI freeze is now
  backed by the shipped-config tests; permission removal needs
  the P1 device matrix to know what the device workflows use).
- **D / llama inference + Vulkan:** untestable here (no model,
  no Vulkan SDK in this VM) — design only, by decision.

## Final Richard-only list

1. **other_tcp → Ask** in the Muse web app (muse.ai → Settings
   → Permissions → Direct network protocols), then approve the
   Gradle daemon card. Unlocks: APK build/install, signing
   runtime proof, Kotlin compile verification, ALL device work.
2. **A16 access** for the P1 run sheet: connect/unlock the
   Galaxy A16, accept USB-debugging + permission prompts.
3. **Production keystore**: create/control it himself
   (docs/SIGNING.md); passwords via the secure local flow only;
   record alias + certificate fingerprint.
4. **Provider scope + keys**: choose the marketed provider set;
   enter keys on the A16 in Settings (NVIDIA/OpenAI/Gemini/
   ElevenLabs/LiveAvatar); confirm the nine ElevenLabs voice IDs
   in his own account or supply replacements; supply an Ollama
   server + model if Ollama is marketed (and decide the SEC-05
   topology).
5. **LiveAvatar avatar IDs** for each marketed call character.
6. **Danny's voice**: pick a real ElevenLabs voice in his
   account and supply the exact name/ID — or approve Danny
   EXCLUDED from flagship marketing.
7. **21+ decision**: choose a verified age-assurance provider/
   method and open its account — or approve excluding Crazy
   Kelly, Shawna, and Ruby from flagship access and marketing.
   (Until then all three are locked in-app by design.)
8. **SEC-01 decision**: provide a server token endpoint for
   Crew Link (the app now supports it) — or approve Crew Link's
   exclusion from the flagship.
9. **P5 model pick** (only if local inference will be marketed):
   choose from the P5 shortlist (Qwen2.5-1.5B-GGUF primary) and
   approve the size budget.
10. **Scene data** (only if Interrogation will be marketed):
    supply it in the documented format; otherwise Interrogation
    stays demoted/labelled by his P4-10 disposition.
11. **P4 dispositions**: Stage (P4-09) and Interrogation (P4-10)
    — source models, demote to labelled Labs, or remove.
12. **Copy adoption**: review the PROPOSED sales draft +
    claims ledger; adopting corrections into the approved copy,
    and any storefront redeploy with corrected counts, are his.
13. **Final P8 approval** of the exact APK hash, signer, roster,
    provider set, and copy.
