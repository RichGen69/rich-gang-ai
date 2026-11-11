# Pasted Room UI — gap audit (2026-11-09 17:20 CST)

Source: Richard pasted three Flutter variants in main chat, plus a consolidation
blueprint. Saved ONLY as supplied material. NOT merged into
`flutter_app/lib/main.dart`, NOT built, NOT published.

## What was pasted
1. Variant A — `NavigationHub`, tabs Home / Command / Agents / WICK OS.
   TRUNCATED mid-file (`CommandTile` ends at `border: Border.all`).
2. Variant B — `MainScreen`, tabs Home / Command / Agents / Settings.
3. Variant C / blueprint — same as B, with an architecture diagram and
   5-tab bottom nav in the diagram (Home / The Room / WICK OS / Command /
   Settings) that does not match any of the code versions.

As pasted, the three cannot be one file: duplicate `RichGangApp`,
`main()`, `RoomHomeView`/`RoomHomeScreen`, `AgentListTile`/`AgentCard`,
`VoiceControllerDock`/`PersistentVoiceDock`, and conflicting 4th tabs.

## Conflicts with the verified record — must be fixed before any build
- `$12,482.67` revenue, "8 Operational pipelines", "Active Tasks: 8
  Running", "Local Sync: 100%" / "Node Sync: 100%", "Online" badge:
  INVENTED. Verified state is $0 revenue / $0 users, no APK, never
  device-verified, no live provider verified. Delete, do not relabel.
- "Rust Tokio Async Daemon" / "libdaemon.so Running (0.2ms latency)":
  Tokio is PARKED / spike-level only; latency is invented. The real app
  boots the daemon and shows it offline when `libdaemon.so` is absent.
- "LanceDB + SQLite Indices Synced" / "Vector Persistence: LanceDB +
  SQLite Local Store": LanceDB is REJECTED (18 GB spike removed
  2026-11-06). Locked decision 2026-10-30: Rust rusqlite is the single
  conversation store; Room stays parked and unwired.
- "Zero-Cloud Dependency Secured", "Zero-Copy Memory Active":
  unverified claims, not in the record.
- Roster in variants B/C — Nova, Kai, Sage, Luna, Rex, Zara: NOT in
  `flutter_app/assets/characters.json` (42 entries: 10 configured + 32
  registry-only). Real entries include Danny, Dan, Rich, Kelly, Freddy,
  Tammy, Sally, Leo, Capricorn, Aquarius, Mustang, WickOS, etc.
  Variant A roster (Freddy, Wick, Mustang, Sally, Nova, Aquarius) is
  partly real, partly invented (Nova).
- "WICK OS v5.5": version not verified in the record.
- Voice dock: mic `onPressed: () {}` and "Listening for command..." —
  no real voice engine wired in the paste. Real app has
  `core/voice_engine.dart`, Deepgram/LiveKit clients, but no live
  provider verified.
- "On-Chain Audit — RICHGEN multi-chain telemetry", "Edge Media
  Renderer — Aquarius visual/audio engine", "Real-Time Voice":
  no live/on-chain verification on record.

## What is usable as UI direction
- Dark theme (#070B12 / #0F172A / #00E5FF / #D4AF37), header with
  THE ROOM + status, 4-tab navigation, persistent bottom voice dock,
  home hero card, command telemetry card shape, agent list tiles.
- All of it must be rewired to real sources before shipping:
  roster from `characters.json`, daemon state from `NativeBridge`,
  revenue/metrics as honest empty state ($0, no pipelines), store
  status from rusqlite `storeState`.

## Real app it must NOT overwrite
`flutter_app/lib/main.dart` already boots: launch counter, daemon config
from `assets/daemon_config.json`, rusqlite store path, `CharacterRegistry`
+ `MindStore`, Rust daemon via `NativeBridge().boot()`, with offline
fallback. `lib/views/the_room.dart` is the existing Room hub.

## Next step — awaiting Richard
Pick one: (1) build as an isolated prototype screen wired to real
roster/daemon state, invented figures deleted; (2) keep as reference
only; (3) something else he names. No merge on a blanket approval.
