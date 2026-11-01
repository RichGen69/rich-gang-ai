# Build session addendum — 2026-10-21 (cloud API integrations)

Richard: "Use likekit api and open ai and deepgram and use heygen api"
+ "And use gemini api and astra gpt 6". ("likekit" = LiveKit;
"astra gpt 6" = GPT-6 Astra, OpenAI's flagship released 2026-09-03 —
a model on the OpenAI API, not a separate API.)

Every endpoint below was verified against the provider's own docs /
server sources in this session before code was written.

## Wired

- **OpenAI** (`openai_provider.dart`): standard chat-completions,
  Bearer auth, probe via GET /v1/models. Default model = GPT-6 Astra
  via `AppSettings.openAiModel` (slug is a setting; must be confirmed
  in the OpenAI dashboard — API errors surface verbatim). GBNF ->
  UnsupportedError (no GBNF parameter exists on this API).
- **Gemini** (`gemini_provider.dart`): POST
  /v1beta/models/{model}:generateContent, key in the
  `x-goog-api-key` header (never a ?key= URL), contents/parts body;
  parser skips `"thought": true` parts. Default model
  `gemini-2.5-flash` from Google's reference example (setting).
- **Router**: Settings gains a cloud-provider selector
  (NVIDIA | OpenAI | Gemini). OpenAI/Gemini get the same
  probe-cache + fallback-to-Ollama shape as NVIDIA; local-only tasks
  unchanged; grammar UnsupportedErrors propagate, never downgrade.
- **Deepgram** (`deepgram_client.dart`): STT POST /v1/listen
  (`Authorization: Token <key>`, model=nova-3, smart_format) by URL or
  raw bytes; TTS POST /v1/speak (Aura, default aura-2-thalia-en)
  returning audio bytes. No mic capture wired — no verified recorder
  exists in this build yet, and the input half is not faked.
- **HeyGen video generation** (`heygen_video.dart`): GET /v2/avatars,
  GET /v2/voices, POST /v2/video/generate -> video_id, GET
  /v1/video_status.get -> data (no self-polling; generation is
  billed). Avatar/voice IDs are Settings fields, refused when unset.
  NOTE: the parallel character build already had HeyGen *streaming*
  (heygen.dart, interactive-avatar calls over LiveKit) — untouched.
- **LiveKit** (`livekit_service.dart`): on-device access-token
  minting (JWT HS256; claims shape verified against LiveKit's server
  SDK: iss/sub/nbf/exp + video grant roomJoin/room/canPublish/
  canSubscribe/canPublishData; HMAC via package:crypto) + Crew Link
  room service using the Room pattern already proven in
  avatar_call_view.dart. Triple-gated in connect(): Crew Link flag
  on, project URL set, key/secret in secure storage — each missing
  piece throws a StateError naming it. Security note in code: the
  secret sits in Keystore storage on-device; acceptable for this
  private build, a shipped product must mint server-side.
  Manifest gained the remaining livekit_client Android permissions
  (CHANGE_NETWORK_STATE, BLUETOOTH/BLUETOOTH_ADMIN ≤30,
  BLUETOOTH_CONNECT).
- **Keys**: SecureKeys slots for OpenAI, Gemini, Deepgram, LiveKit
  key+secret; Settings UI fields for all of them (+ LiveKit URL,
  HeyGen generation avatar/voice IDs). HeyGen key field already
  existed from the character build.

## Verification
- `flutter pub get`: livekit_client ^2.8.0 + crypto ^3.0.3 resolved
  (22 deps changed).
- `flutter test test/livekit_token_test.dart`: **passed** (JWT shape,
  claims, TTL, signature actually keyed by the secret).
- `flutter analyze`: **zero issues in every file this session
  touched**. The run shows 6 pre-existing minor lints in the parallel
  character build's files (roundtable_view.dart, the_room.dart) —
  not introduced here and left to that workstream.
- NOT exercised live: no API keys exist in this environment for any
  of the six services, so no real call has been made. First use is:
  paste keys in Settings (Keystore), select provider, talk. Failures
  will surface the provider's own error text.

## Still blocked / open (unchanged)
- APK packaging: `other_tcp` = Deny (Richard's one setting).
- No device verification for any of this (no device in the VM).
