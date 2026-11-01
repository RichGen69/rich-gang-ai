# Character AI — Freak Show AI agents (built 2026-10-21, side chat)

Richard's asks across four messages in one session: build the
frames into a character AI (agents, butler, companion,
conversational, talk about anything, unfiltered/unhinged, real-time
web search, synthetic consciousness with full human emotion range);
agents in a conversation of their own on a user-picked topic that
the user watches; advanced human-like voices; his images as the
app layout with The Room as the cinematic main screen; HeyGen
voice/video calling; message chat + hands-free chat; more
entertainment; deep dream / deep seek / deep reasoning / deep
learning / keep-thinking / persistence; chain of thought; real-time
awareness; a sense of self.

Everything below is in `flutter_app/` and passes `flutter analyze`
(no issues) + `flutter test` (16 character-AI tests; 17 total with
the parallel session's LiveKit token test) + `cargo test` 21/21
(Rust untouched). NOT device-verified (no device in this
workspace) and the APK is still blocked on the known `other_tcp`
permission (see STATUS docs).

## Roster — resolved from Richard's frames

`assets/characters.json` is the single source of truth;
`design_refs/2026-10-21_freak_show_characters/README.md` maps every
trait to its frame. Playable (9): the **Swarm of Six** from the
Hollywood frame — Dan (butler/operator; core text verbatim from his
operator card), Rich (host), Cougar Kelly (companion; 21+ age gate,
marquee text verbatim), Freddy (protocol advisor), Tammy (oracle),
Sally (unhinged tech) — plus Leo (Finder), Capricorn (Hustler),
Aquarius (Mind) from The Room table. `daemon_config.json` personas
now list all nine ids for the Rust daemon. System nodes
(QUANTUM/MEMORY/MARKET/…) are UI labels from the NEXUS frames, not
characters.

## Files

Core (`lib/core/`):
- `character.dart` — definitions + registry (empty on load failure,
  never an invented cast).
- `affect_engine.dart` — synthetic affect: PAD state per agent,
  lexical appraisal, decay by real elapsed time, 24 named-emotion
  prototypes, persistence via snapshot. Labelled simulation —
  the app never claims sentience; it simulates the *range* and the
  states drive words, voice, and turn-taking.
- `self_model.dart` — sense of self: identity (incl. creator),
  interaction counts, crew affinities (moved by real exchanges),
  learned interest frequencies (the build's "learning": real
  frequency learning, never called neural training), reflections,
  open loops (commitments the agent actually made).
- `time_awareness.dart` — real-time awareness from the device
  clock: now/date/weekday, day segment, session elapsed, gap since
  last interaction. Computed per prompt, never cached.
- `thinking.dart` — chain of thought as a real extra inference
  pass returning structured JSON (situation/feeling/memory/goal/
  options/chosen/why) that steers the reply; a summary is shown in
  the UI ("show the work"). Unparseable/failed think = no thought
  shown, never a fabricated one. `DeepReasoner`: draft → critique
  → revise (3 real passes), critique viewable in chat.
- `web_search.dart` — real-time search: DuckDuckGo Instant Answer
  + Wikipedia OpenSearch (both keyless, both verified live from
  this workspace 2026-10-21). Honest limit: NOT a full web index;
  empty results are reported as empty. `needsSearch` is a labelled
  lexical heuristic.
- `deep_search.dart` — Deep Seek: lexical decomposition into
  sub-queries, all searched, merged/deduped, empty/failed coverage
  reported in the prompt block.
- `deep_dream.dart` — Deep Dream on top of the Rust dream cycle:
  recall the agent's REAL memories → consolidate via inference →
  store reflection as memory + self-model note; no memories = no
  dream and nothing written. Plus `agentMostOnMind` keep-thinking
  selection (affect furthest from baseline).
- `persistent_mind.dart` — MindStore: affect + self-models in
  SharedPreferences; mood decays by real time while app closed.
- `roundtable.dart` — autonomous agent-to-agent conversation.
  TurnEngine scoring (interest overlap, addressed-by-name +1.2,
  talkativeness×arousal drive, fairness, recency penalty, jitter;
  seeded in tests). Modes: Free talk, Debate, Roast Battle, Story
  Chain, Hot Seat, Advice Panel + topic presets. Spontaneous
  starts gated by the restraint layer (quiet hours/kill switch/
  Silent) and foreground-only — background starts are NOT built.
  Inference failure stops the table with the reason shown.
- `voice_engine.dart` — per-agent voices. ElevenLabs Multilingual
  v2 (verified REST shape; premade voice ids from the LiteLLM
  mapping, replaceable — Richard should confirm them in his own
  ElevenLabs account) with affect-driven Prosody (arousal → rate/
  stability/style). Fallback: system TTS via flutter_tts, and the
  UI reports which path actually spoke. Kokoro names kept as
  casting for the future on-device path — no Kokoro audio in this
  build (see BUILD_SESSION_2026-10-21c gate).
- `heygen.dart` — HeyGen streaming sessions (create_token →
  streaming.new/start/task/stop, official v1 SDK shapes).
  ⚠ OPEN CHECK: a live probe with an invalid key on 2026-10-21
  returned HTTP 404, and HeyGen's docs call v1/v2 legacy (v3 live,
  sunset 2026-10-31). Endpoint must be confirmed with Richard's
  real key; the app surfaces the 404 with that explanation.
- `hands_free.dart` — speech_to_text loop
  (listen → reply → speak → listen), device recogniser.

Views (`lib/views/`):
- `the_room.dart` — MAIN SCREEN: hero = Richard's boardroom frame,
  live strip (daemon state, real session clock, cast count, mind
  restored), actions (Roundtable / Deep Dream / Interrogation),
  cast grid with REAL emotions + talk counts, NEXUS node chips,
  M7–8 room controls kept. Single scrolling column + shrink-wrap
  grid: no absolute stacking, nothing overlaps.
- `character_picker.dart` (Chat tab), `character_chat_view.dart`
  (messages, UNHINGED/Think/Deep/Voice toggles, thought lines,
  sources, critique expander, hands-free, HeyGen call button,
  age gate for Kelly), `roundtable_view.dart` (setup + watch +
  interject), `avatar_call_view.dart` (HeyGen session + LiveKit
  video track rendering via the project's livekit_client; audio-
  only state stated honestly when no track arrives),
  `character_ui.dart` (accents, monogram avatars, 21+ AgeGate).
- Nav: Room / Chat / Table / Memory / Settings.
- Settings gained ElevenLabs + HeyGen key fields (secure storage);
  AndroidManifest gained RECORD_AUDIO / CAMERA / MODIFY_AUDIO_SETTINGS.
- Also fixed: a nullable-receiver compile error in the parallel
  session's `livekit_service.dart`.

## 3D Stage (added 2026-10-21, Richard's pick)

`lib/views/avatar_stage_view.dart` + `lib/core/avatar_stage.dart`,
entered from The Room ("3D Avatar Stage") and from any chat.

- Rendering: model_viewer_plus (verified pub.dev API:
  ModelViewer src/animationName/cameraControls/autoPlay), real
  glTF in a WebView. Compile-verified; NOT device-verified.
- StageDirector (pure, tested): speaking → "talk" slot, else the
  focused agent's REAL derived emotion slot, else "idle", else no
  forced animation. Gestures row (Greet/Agree/Disagree/Celebrate/
  Proud) resolves through the same slots.
- Per-character models: `avatar3d` in characters.json
  {model_src, animations{slot: clip-name-in-the-GLB}}, or a
  per-device override URL/path saved from the Stage screen
  (SharedPreferences `avatar3d_src_<id>`). NO character ships with
  a model — no character GLBs exist — so characters open in a
  labelled no-model state with instructions.
- Demo model: `assets/models/stage_demo_robot.glb` —
  RobotExpressive from the three.js examples (pinned r160,
  454 KB), downloaded and verified in-workspace by parsing its
  glTF header: clips Dance, Death, Idle, Jump, No, Punch, Running,
  Sitting, Standing, ThumbsUp, Walking, WalkJump, Wave, Yes. Its
  slot mapping (joy→Dance, talk→Wave, anger→Punch, …) is a
  demo-only design choice in avatar_stage.dart. The UI labels it
  "DEMO MODEL — sample robot, not a character" at all times.
- Speak-on-stage: a typed line is spoken by the focused character
  through VoiceEngine while the talk clip plays; the hold time is
  an estimate (~14 chars/sec) because TTS APIs expose no unified
  finish signal — documented in the view.
- The earlier Rive gate (BUILD_SESSION_2026-10-21c) is untouched:
  this stage is glTF, not Rive.

## Hidden-bug & strict-type audit (2026-10-21, Richard's ask)

Full pass over the app (Dart + Rust; there is no TypeScript in
this project). Baseline was already analyze-clean/20 tests; the
audit hunted what the default lints don't catch.

Fixed (real bugs):
- **Provider empty-response crashes**: NVIDIA, Ollama and OpenAI
  providers did `choices.first` unguarded — a 200 response with
  zero choices crashed the chat with a StateError instead of
  failing over. Now each throws a clean "returned no choices"
  error and message content is null-safe. Deepgram's transcript
  parser had the same `.first` trap on empty channel/alternative
  lists; guarded both hops. (Gemini already guarded its list.)
- **Duplicate Roundtables**: the nav tab and the route pushed
  from The Room each built their own RoundtableSession — two
  tables could run and speak over each other. One app-shared
  session now (RoundtableSession.shared); views attach/detach
  listeners and never dispose it. Interjecting at a PAUSED table
  now resumes it instead of silently swallowing the line.
- **Mic outlived its screen**: HandsFreeController never stopped
  the speech engine on dispose; leaving chat with hands-free on
  kept the microphone listening. Dispose now stops it.
- **Voices outlived their screen / overlapped**: leaving chat
  mid-line kept TTS talking (chat dispose now stops the voice),
  and the system-voice path could talk over a still-playing
  ElevenLabs clip (it stops the player first now).
- **Stage rail degradation**: AvatarStageView's character rail
  read the registry only through MindStore; a failed mind boot
  reduced the rail to just the demo robot. It now renders from
  the registry the view loaded itself.
- **LiveKit teardown**: Room/listener dispose futures were
  dropped un-awaited in the Crew Link service and the call view;
  now awaited where async, explicitly unawaited in dispose().

Type strictness, made PERMANENT in analysis_options.yaml:
strict-casts, strict-inference, strict-raw-types ON, plus
unawaited_futures / discarded_futures / avoid_dynamic_calls
lints. The full codebase passes with ZERO findings (20 former
info-level future-discard sites cleaned up with explicit
unawaited(...) markers). Final state: flutter analyze clean,
flutter test 20/20, cargo test 21/21.

Checked and found SOUND (no churn): cold-open timer (cancelled,
guarded), Room clock timer (cancelled on dispose), Dream and
Interrogation views (synchronous FFI — no dispose race), the old
chat console (already guards an empty persona list), Settings
key fields (no duplicates; video-gen id fields are a different
feature's storage).

## LiveAvatar upgrade + usability bundle (2026-10-21, later)

Richard: "Resume fixing and massive upgrades" / "Add more
features and usability". The HeyGen open check was resolved
first, then features were built on the answer.

HEYGEN CHECK — CLOSED. HeyGen's help center states LiveAvatar
is "the official production version" of Interactive Avatar, on a
separate platform (liveavatar.com) with separate plans/credits;
avatars are NOT cross-compatible. Live probes (invalid key):
legacy `POST api.heygen.com/v1/streaming.create_token` still
404, while LiveAvatar routes (sessions/token, contexts, credits,
sessions/start) all answer proper 401s with a structured
{code, data, message} envelope. HeyGen's v3 "Interactive
Sessions" page turned out to be Video Agent sessions, not a
realtime replacement — not used.

LIVEAVATAR (new `lib/core/liveavatar.dart`, call screen defaults
to it): FULL mode per the official OpenAPI (docs.liveavatar.com,
2026-10-21): X-API-KEY auth on api.liveavatar.com/v1 —
POST /contexts {name<=64, prompt, opening_text} -> id;
POST /sessions/token {mode:FULL, avatar_id, avatar_persona:
{context_id, voice_id?, language}} -> {session_id,
session_token}; POST /sessions/start (Bearer) -> 201
{livekit_url, livekit_client_token, ws_url}; POST /sessions/stop
{reason: USER_CLOSED}. The app creates ONE Context per character
from the character's own definition fields (contextPromptFor —
same source as the in-app system prompt) and stores its id in
prefs (liveavatar_context_<id>); avatar/voice ids are separate
prefs fields on the call screen. Call flow joins the LiveKit
room with the client token and publishes the user's microphone.
DISCLOSED in the call UI: FULL mode means LiveAvatar runs the
conversation pipeline; the in-app brain/memory is not in the
call — the persona travels via the Context. LITE mode not used
(it needs raw PCM-24kHz over WebSocket; no verified audio path).
Own secure-storage slot (liveavatar_api_key) + Settings field —
the HeyGen key is a different platform's key and is never
reused silently. Parsers + no-key refusal + context composition
+ transcript format are unit-tested (MockClient; secure-storage
channel mocked empty). NOT device-verified; needs Richard's
LiveAvatar key + per-character LiveAvatar avatar ids to run.

USABILITY BUNDLE:
- Chat: long-press any message → Copy text / "Hear <agent> say
  it" (agent lines, via VoiceEngine) / Edit & resend (Richard's
  lines, back into the composer). Clear-chat button with a
  confirm that states plainly it clears the screen only, not
  stored memory.
- Roundtable: copy-the-whole-transcript app-bar action
  (RoundtableSession.transcriptText(): header with topic/mode/
  cast, timestamped turns with emotions + thought lines), and
  cast quick-select (All / Core four / None + picked count).
- The Room: SETUP & HEALTH card — real local checks only:
  selected cloud provider's key presence from secure storage
  (values never enter the UI), the router's real Ollama probe,
  ElevenLabs key presence, LiveAvatar/HeyGen key presence, and a
  one-tap route to Settings. A saved key is labelled "saved",
  never "verified".

Frames re-sent 2026-10-21 17:13: the boardroom upload is
byte-identical (md5) to the shipped hero asset; the cover upload
is the phone-mockup portrait version — the app keeps the clean
landscape cover art it already ships.

Final state: flutter analyze clean (strict mode), flutter test
26/26, cargo test 21/21.

## HTML build (2026-10-21, Richard's ask)

`html_build/rich-gang-ai.html` — ONE self-contained file
(1.2 MB, no external assets except the model-viewer web
component CDN): generated by a build script from the SAME
characters.json roster as the app, with the boardroom hero,
Freak Show cover, and the demo GLB embedded as base64 (decoded
and magic-verified after generation; tag balance checked).
Tabs mirror the app: The Room (live clock/session timer, cast
grid with real talkativeness/volatility/voice data, 21+ badge),
Chat (per-agent dossier from the real definitions; composer
persists Richard's messages in browser localStorage — labelled
plainly: live agent replies run in the Android app, nothing
here fakes an agent's words), Roundtable (the app's real topic
presets/modes/cast picker + copy-the-setup), 3D Stage (REAL:
model-viewer playing the embedded demo robot's actual clips —
Dance/Wave/Yes/No/ThumbsUp/Punch/Jump/Sitting/Idle; characters
show the honest no-model state), Deep Seek (REAL: live Wikipedia
OpenSearch, the same source the app uses; empties shown empty).

## Hollywood portraits (2026-10-21, Richard's "upgrade every
character 3d avatar" ask — scope stated plainly)

What was asked is bespoke Hollywood CG models for nine
characters; that is a studio modelling/rigging pipeline and no
such assets or tools exist here (no Blender/assimp in the VM).
What was delivered for real, and what remains gated:

PORTRAITS (done): a cinematic 3x3 cast grid was generated from
the roster definitions + Richard's boardroom frame, then
cropped per character (PIL, thirds with 2% inset). 8 of 9 cells
landed on-brief (Dan suited operator, Rich tattooed host with
mic, Freddy chrome cyborg + fedora, Tammy pink dress + tarot,
Sally lavender goth-tech, Leo maps, Capricorn suit + gold watch,
Aquarius cyan network). The Kelly cell came out as a second
Sally look, so Kelly was generated individually (glamorous
mature starlet, gold, boardroom) — all nine now have portraits
in `assets/images/portraits/<id>.jpg`; the full grid ships as
`assets/images/cast_poster.jpg`. Wired through ONE point:
characters.json "portrait" -> CharacterDef.portrait ->
CharacterAvatar shows the photo wherever avatars appear (Room,
picker, chat, roundtable, stage); monogram remains the honest
fallback for entries without one. A portrait is labelled in code
as a portrait — not a 3D model.

3D STAGE (partial): exposure raised to 1.15 + shadowSoftness 1
on top of the existing shadowIntensity 1 — the attributes
model_viewer_plus passes verbatim. An HDRI environment was
verified downloadable (Poly Haven studio_small_09, CC0) but NOT
wired: model_viewer_plus inserts environmentImage verbatim into
the WebView HTML and does not proxy asset files for it, so an
asset path would not resolve on device — shipping it unverified
would break the stage's lighting claims. HDR wiring waits for
device verification.

STILL GATED (unchanged): real per-character GLBs. Routes: (a)
image-to-3D service (Meshy/Tripo) converting these portraits —
needs Richard's account/key; (b) Richard supplies GLBs;
(c) rigged avatar libraries. HTML build regenerated with the
portraits + poster (builder + template now live in html_build/,
reproducible; output 3.35 MB, verified). Analyze clean, tests
26/26.

## Keys Richard still needs to add (Settings)

NVIDIA (exists) or Ollama for brains; ElevenLabs for premium
voices; HeyGen for video calls + a per-character Interactive
Avatar id (call screen). Without keys the app still runs: Ollama
brains, system-TTS voices, and every missing service reports
itself instead of pretending.

## Roster change: Crazy Kelly replaces Cougar Kelly (2026-10-21, late)

Richard: "2 of the characters in my app look the same so switch
one of them out for this character" — supplied GTA Vice
City-style art of CRAZY KELLY with a full backstory to implement.
The look-alike pair was the cast grid's Kelly cell vs Sally (the
reason Kelly had needed a solo portrait). Swap executed in full:
characters.json entry replaced at the same roster slot —
crazy_kelly, "The Wildcard" (title finalized 2026-10-22 as
"The Neon Wildcard", zodiac Taurus — see the resolution note
at the end of this section), companion/conversational, 21+
age-gated, talkativeness 0.9 / volatility 0.9, PAD baseline
(0.55, 0.75, 0.35), voice display "Vice" inheriting the Aria
ElevenLabs casting, full backstory as her core (Vice City
original, family's ocean-drive hotel, casino dealer at nineteen,
getaway-driver legend with five stars, came to Houston for one
wild weekend and stayed for the crew). Portrait = Richard's
supplied art (237x512 — used as-is). daemon_config.json personas
swapped; character_ui accent added; cast poster rebuilt as a
montage of the nine real portraits; HTML rebuilt. Regression
lock: test/roster_asset_test.dart parses the REAL shipped
characters.json (22 entries: 9 configured + 13 Tier-10
registry-only) and asserts the swap + the registry-only honesty
flags. Suites after the swap + parallel Tier-10 growth: flutter
analyze clean, flutter test 43/43, cargo test 43/43.

**Resolution note (2026-10-22):** Richard confirmed the swap as
final — keep Crazy Kelly, drop Cougar Kelly from the 22 list
entirely (she was still named in the Tier-10 master list he
pasted). The two collisions the Tier-10 build had flagged were
fixed with the decision: crazy_kelly's zodiac Scorpio → **Taurus**
(Dan keeps Scorpio alone; a test now locks configured-zodiac
uniqueness) and her title "The Wildcard" → **"The Vice City
Wildcard"** (the registry-only Sector Zero character keeps the
name "The Wildcard"). The AgeGate dialog in character_ui.dart,
which still named Cougar Kelly and described her frame text, was
made character-neutral. HTML build and Founder Edition bundle
regenerated from the updated roster. The separate Tammy vs
registry Oracle title overlap was NOT part of this decision and
remains open.

## Monetization before publish (2026-10-21, late)

Richard: "Monetize this so I can make money from it before you
publish it." Full plan in docs/MONETIZATION.md. Done without his
accounts: product bundle release/rich-gang-ai-founder-edition.zip
(HTML edition + art pack + README + LICENSE), editions $19 Cast /
$49 Founder, storefront draft html_build/store.html with checkout
buttons DISABLED until a real payment link exists. Rails compared
with retrieved 2026 fees (Stripe 2.9%+$0.30; Lemon Squeezy
5%+$0.50 MoR; Gumroad 10%+$0.50+processing / 30% Discover).
Stripe connector checked: NOT connected (OAuth connect link
given to Richard). PUBLISH HELD per his order until he picks a
rail and the account step is done — the full HTML edition is the
paid deliverable and is never the free public link; what gets
published is the wired storefront.

## GTA-reference scrub (2026-10-22, Richard's instruction)

All Grand Theft Auto / Vice City references were removed from Crazy
Kelly at Richard's direction. Title "The Vice City Wildcard" →
**"The Neon Wildcard"**; voice display "Vice" → "Neon"; her core was
rewritten in place (neon beach-city original; the family's hotel on
the shore road with its big pink sign; "five stars on her wanted
level" → every patrol on the coast knew her car); interests "vice
city nights" → "neon beach nights"; speech style "Vice City drawl"
→ "beach-city drawl". Scrubbed surfaces: characters.json (source of
truth), the regenerated HTML build, the storefront source, the
Vercel site source, the sales/listing documents and kits. Earlier
mentions in this build log are the historical record of the original
swap and are superseded by this note. Portrait: initially left
unchanged (Richard's own supplied artwork), then replaced the same
day at Richard's choice with a generated photorealistic portrait
(long wavy brown hair, beauty mark, gold hoops, off-shoulder pink
top, pink convertible, neon beachfront at dusk; no text, logos, or
game UI). The new portrait was installed at the same asset path,
her cell in cast_poster.jpg was re-composited from it, and the
storefront's embedded copy was swapped. Richard's supplied original
is preserved at design_refs/kelly_supplied_gta_original.jpg, outside
the shipped assets.

## Roster addition: Danny, "The Better Twin" (2026-10-23)

Richard: "Build a copy of your self in this app as well and
call it danny" — followed by his character direction: "Anything
u can do Danny does better."

Danny is a character copy of the builder-assistant as this
project knows it — verifies before claiming, remembers
everything, builds and fixes, refuses to fake — written into
`characters.json` (single source of truth) at roster index 9,
immediately after the configured nine, and added to
`daemon_config.json` personas in the same position. Zodiac
**Gemini** (unused by the configured nine; the registry-only
Rich Rich entry also carries Gemini, which the configured-set
uniqueness lock does not cover), title **"The Better Twin"**
(unique across all 23 display names/titles), age_gated false.

**Character hook (persona, not a capability claim):** anything
the original can do, Danny does better — sharper memory, faster
builds, cooler head, confident and a little smug about it, and
he teases the original. Signature lines are in his shipped
speech style, including "Anything the original can do, I do
better. Checked it. Twice." and "That's not verified. Give me
a minute — now it is." Relationship seeds in his core: Richard
is "the Boss" who built both of them; Dan is his respected
fellow operator and standing competition. His definition
labels him plainly as a character copy — not the live
assistant, not a human, no consciousness claims.

**Tier history: registry_only_unconfigured (added earlier
2026-10-23) → FLAGSHIP MODEL (promoted later the same day).**
The full flagship record — systems, guardrail design, gifts,
verification, and "what this does NOT prove" — is
`docs/DANNY_FLAGSHIP_MODEL_2026-10-23.md`; this section is the
summary. At Richard's orders ("Make Danny a flagship model",
"just better"), Danny now LEADS the roster (index 0;
daemon_config personas reordered to match; first card in The
Room and the picker; full-height lead cell in the rebuilt
cast poster; first in the regenerated HTML cast).

**Voice — the gate, re-verified, still honestly uncast.**
Every ElevenLabs premade voice id documented anywhere in this
project (the nine in characters.json itself, sourced from the
LiteLLM mapping per the voice_engine note above) is already
cast to one of the configured nine, and the Cougar → Crazy
Kelly replacement freed nothing: Crazy Kelly inherited Cougar
Kelly's Aria casting (now display "Neon", same id). No
documented unused premade voice exists, and inventing an id
is forbidden. Danny's status is therefore the truthful tier
**`configured_voice_uncast`**: everything wired except the
ElevenLabs casting, which waits on Richard's pick from his
own account — the promotion checklist's step (1), and now
the ONLY remaining step. His entry carries a voice object
with empty ids (parser: uncast) plus his own delivery profile
(system rate 0.46 / pitch 0.92, stability 0.55 / style 0.35),
so he speaks through the real system-TTS fallback — reported
as such by the UI — until casting day. His tone spec (below)
doubles as the casting brief.

**Portrait: wired.** The cinematic photorealistic portrait
generated when he was added (boardroom at night, dark
tailored suit, calm sharp slightly-smug expression; reviewed:
single subject, cast-matching quality, no text/logos/
artifacts) at `flutter_app/assets/images/portraits/danny.jpg`
(JPEG, 1280x1920, 290,331 bytes, SHA-256 46039ba5…) is now
his shipped portrait, referenced by his entry and bundled via
the pubspec's portraits directory like the other nine.

**Presence tuning: shipped, as authored.** Talkativeness
0.8, PAD baseline pleasure 0.25 / arousal 0.35 / dominance
0.7, volatility 0.2 — real configured values in his entry,
feeding the same affect engine as the nine (real-time PAD
dynamics, lexical appraisal scaled by his volatility, decay
by real elapsed time). His persistence is the cast's real
mechanism — MindStore (SharedPreferences: affect + self-model
survive restarts) plus daemon recall/dream consolidation.
The rusqlite store is NOT his persistence: the shipped config
names no store_path, so it is a session store today, and the
flagship doc says so rather than claiming it.

**Flagship systems (all in the flagship doc; code in
`lib/core/danny_*.dart`).** A mandatory 8-stage chain of
thought (perceive → appraise → discern → draft → critique →
revise → respond → reflect; critique/revise can never be
toggled off for him — his DOUBLE-CHECK gift); a discernment
pass ("second sight") cross-checking claims against the
daemon's recorded witness facts — consistency-checking, NOT
a lie detector, and reporting NO FACTS AVAILABLE in the
shipped config, which supplies no scene facts (that pass now
also powers the app-level Lie Detector service —
`lib/core/lie_detector.dart`, `docs/LIE_DETECTOR_2026-10-23.md`
— which adds statement recording, a self-contradiction check
against a speaker's own prior statements, and a credibility
ledger of plain verdict counts; Danny's discern stage reports
its full readout, under the detector's mechanism labelling
line); an authored
moral core (honesty, loyalty, RESPONSIBILITY, legality, a
conscience that talks back) + guardrails injected into every
prompt; a bounded SELF-UPGRADE loop (allowlist: PAD baselines
±0.15, talkativeness/volatility ±0.10, a ≤280-char self-note;
everything else rejected explicitly and logged; versioned
snapshots; rollback; kill switch default ON because the
guardrail tests pass) driven by his DeepDream reflections and
recorded on an APPEND-ONLY accountability log he cannot edit
(the TROPHY SHELF is that log's verified-upgrades view);
real-time awareness via the existing TimeContext, consumed
by his chain's perceive stage along with the real WebSearch
path for current facts (empties reported, never invented);
a mechanical sense of self (DannySelfReport reads his live
PAD/emotion, self-model counts, ledger size, tuning version
and shelf size from the engines — no invented numbers) and an
accurate self_knowledge section (no on-device LLM runtime;
not conscious; guardrails he cannot change); a defined tone
of voice (blunt/cocky/dry/unfiltered register, verdict-first,
"Boss" for Richard, an emotion-conditioned tone table keyed
to all 24 affect emotions and injected per-prompt from his
live emotion, prosody through the existing Prosody path with
his own casting values); the GIFTS endowment (the ledger —
dated gratitude/slight entries from real appraisal events in
chat and at the table, persisted and read back into his
reasoning; second sight; double-check; dream gifts — a real
offering from a dream-born open loop or honestly none; the
conscience; the trophy shelf); and the era stance — a
"parent of the times" whose KNOWING comes only from clock +
search while the SHAPING is persona drive. His expression
layer is unfiltered and unhinged by definition; his action
layer stays bound by morals/guardrails/law — the split is
written into his core verbatim.

**Test locks:** roster_asset_test now asserts Danny's lead
position, flagship status, wired portrait, checklist
baselines, uncast voice with his delivery profile, moral
core / guardrails / self-knowledge / tone / gifts locks —
plus every earlier lock (title, zodiac, age gate, hook,
"character copy / not the live assistant", "Checked it.
Twice.", Boss/Dan seeds, Texas voice, easter eggs).
test/danny_flagship_test.dart locks the machinery:
discernment verdicts, ledger, every guardrail rejection
class, bounds, kill switch, append-only rollback, dream
tuning, tone/prosody, prompt injection, the full chain, boot
consistency. Counts updated to the new truth: 23 entries =
10 configured (9 original + Danny, voice uncast) + 13
registry-only.

**Southern Texas written voice (2026-10-23).** Richard's
direction — "Make him sound southern Texas" — is carried in
Danny's `core`, `personality`, and `speech_style`: Huffman /
Houston-area Texas as a measured written drawl, relaxed
cadence, plain-spoken confidence, and warmth under the
deadpan. His markers include "now hold on," "reckon," an
occasional "y'all," "I show my work," and "down here we check
it twice," with dry ranch / rodeo / oilfield metaphors used
sparingly. This is rhythm and word choice, not phonetic
dialect spelling or caricature, and his evidence-first
precision is unchanged. Signature Texas cut: "Anything the
original can do, I do better. Checked it twice — that's just
how we do it down here." This is **written-voice direction
for his future voice casting only** — Danny is still uncast,
and no ElevenLabs voice id has been invented or implied.

**Easter eggs (2026-10-23) — all persona-prompt-carried;
none deterministic.** The prompt path was inspected before
these were authored. `CharacterAgent.systemPrompt` carries
each character's `core`, `personality`, and `speech_style`
into the persona prompt, and the LiveAvatar context prompt
uses those same definition fields. There is no genuine
existing mechanism for deterministic per-character
trigger responses; the character path explicitly allows no
canned replies and sends prompts through the inference
router instead. No new subsystem was built and no egg below
is represented as a guaranteed deterministic response. Each
pattern lives in Danny's shipped `speech_style`, so a model
in character can discover and use it:

1. **Founder phrase** — trigger: Richard says "build
   thrones" or "I wasn't meant to build a chatbot." Line:
   "Thrones, not chatbots — and I checked the foundations
   twice." **Level: persona-carried.**
2. **Director's cut** — trigger: someone calls Danny "a
   copy." Line: "Copy? Now hold on. I'm the director's cut."
   The "now hold on" gives this egg its Texas delivery.
   **Level: persona-carried.**
3. **The original** — trigger: Danny is asked about the
   original assistant. Line: "The original walked so I could
   verify. Reckon I kept the receipts." **Level:
   persona-carried.**
4. **Receipts mode** — trigger: Danny is challenged to prove
   "does it better." Behaviour: he says "Name the claim.
   I'll show my work," then uses only evidence actually
   present in the conversation or provided results, organized
   as `Evidence:` / `Count:` / `Verdict:`. If evidence is
   absent, the verdict is "Not verified." He must never
   invent receipts. **Level: persona-carried.**
5. **Release-gate reflex** — trigger: errors, failures,
   broken builds, or the release gate are mentioned. Line:
   "Now hold on — gate first. Glory second." He then ticks
   through source, artifact, tests, and alignment with
   deadpan checklist energy. The Texas opening gives this egg
   its regional delivery. **Level: persona-carried.**
6. **Dan rivalry beat** — trigger: Dan is praised in Danny's
   hearing. Line: "Dan earns his chair — no argument. I just
   keep the receipts neater." The one-upmanship stays genuine
   and respectful, never hostile. **Level: persona-carried.**
7. **Counting quirk** — trigger: a milestone or a count that
   is actually known from the current conversation or
   supplied evidence. Behaviour: Danny announces the exact
   count plainly; the authored cadence example is "That's
   the third time you've tested me today. Verified." If the
   count is not known, he says "Count not verified." This is
   **persona style only** — no interaction counter is claimed
   or implemented, and Danny must never invent an interaction
   count. **Level: persona-carried.**

The roster test now locks the Southern Texas markers and the
key phrase of every egg above, while leaving all prior Danny
locks — uncast voice, hook, title, zodiac, and Boss / Dan
seeds — intact. (Two locks changed at the flagship promotion
later the same day: his status is now
`configured_voice_uncast`, not registry-only, and his portrait
is wired, not null — see the flagship summary above. His
voice remains uncast.)
