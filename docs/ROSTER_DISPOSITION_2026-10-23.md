# ROSTER DISPOSITION — all 23 registry entries (2026-10-23)

Source of truth: `flutter_app/assets/characters.json`, read at
this sweep. "Configured" = authored definition + portrait +
voice casting + affect baselines in the registry. "Marketable"
means: may be presented as a flagship character once the app's
general gates clear (P1 device proof, P2 provider proof) **and**
the per-character items below are closed. Nothing on this page
is marketable today — the flagship is not finished (P8).

Shared outstanding items for every **configured** character:
ElevenLabs voice IDs are from the LiteLLM premade mapping and
must be confirmed in Richard's own ElevenLabs account (or
replaced by him); per-character LiveAvatar avatar IDs do not
exist yet (HeyGen IDs do not carry over); device behaviour is
unverified (no APK has ever run).

## Configured — 10

| # | Character | Status | Marketable? | Exactly what's missing |
|---|---|---|---|---|
| 1 | Danny — "The Better Twin" | `configured_voice_uncast` | **NO — excluded until decided** | A real ElevenLabs voice: Richard picks one in his own account and supplies the exact name/ID (all nine documented premade voices are already cast; inventing an ID is forbidden). Until then he speaks via system TTS and is labelled VOICE UNCAST in-app. Alternative: Richard approves Danny excluded from flagship marketing. Everything else is shipped: portrait, baselines, flagship chain, ledger, discernment, self-upgrade bounds. |
| 2 | Rich Dan — "The Universal Operator" | configured (voice: Dave) | Pending general gates | Account confirmation of the Dave voice ID; LiveAvatar avatar ID if marketed for calls. |
| 3 | Chosen One Rich — "The Host" | configured (voice: Drew) | Pending general gates | Account confirmation of the Drew voice ID; LiveAvatar avatar ID if marketed for calls. |
| 4 | Crazy Kelly — "The Neon Wildcard" | configured (voice: Aria), **21+** | **NO — also blocked on P7** | Everything for the nine, **plus** the 21+ decision: a verified age-assurance provider/method chosen and opened by Richard, or his approval to exclude all 21+ characters from flagship access and marketing. As of this sweep she is locked in-app by the fail-closed AgeAssurance boundary. |
| 5 | Freddy — "The Protocol Advisor" | configured (voice: Clyde) | Pending general gates | Account confirmation of the Clyde voice ID; LiveAvatar avatar ID if marketed for calls. |
| 6 | Tammy — "The Oracle" | configured (voice: Domi) | Pending general gates | Account confirmation of the Domi voice ID; LiveAvatar avatar ID if marketed for calls. |
| 7 | Sally — "The Unhinged Tech" | configured (voice: Rachel) | Pending general gates | Account confirmation of the Rachel voice ID; LiveAvatar avatar ID if marketed for calls. |
| 8 | Leo — "The Finder" | configured (voice: Fin) | Pending general gates | Account confirmation of the Fin voice ID; LiveAvatar avatar ID if marketed for calls. |
| 9 | Capricorn — "The Hustler" | configured (voice: Paul) | Pending general gates | Account confirmation of the Paul voice ID; LiveAvatar avatar ID if marketed for calls. |
| 10 | Aquarius — "The Mind" | configured (voice: Roger) | Pending general gates | Account confirmation of the Roger voice ID; LiveAvatar avatar ID if marketed for calls. |

## Registry-only — 13 (excluded from flagship marketing)

Every entry below is `registry_only_unconfigured`: **no
portrait, no voice casting, no affect baselines**. In-app they
now sit in a separate "REGISTRY — NOT CONFIGURED" section and do
not open as finished characters. To promote any of them takes,
per character: an authored portrait, a real voice casting from
Richard's account, affect baselines, and a status flip with the
roster tests re-run — Richard's call on which, if any, are worth
that work before the flagship ships.

| # | Character | Extra blocker |
|---|---|---|
| 11 | Rich Rich — "1986 Synthwave Mogul" | — |
| 12 | Richard — "Technical Systems Architect" | — |
| 13 | Mustang — "Systems Architecture / Rust Daemon" | — |
| 14 | WickOS — "Security / Global Audit" | — |
| 15 | Shawna — "21+ Tactical Companion" | **21+**: also blocked on the P7 decision (see Kelly) |
| 16 | Ruby — "21+ Neon Companion" | **21+**: also blocked on the P7 decision (see Kelly) |
| 17 | The Iron Outlaw — "Ashfall-77 Survivor" | — |
| 18 | The Empress — "Veloria Political Strategist" | — |
| 19 | The Wildcard — "Sector Zero Underground Champion" | — |
| 20 | The Oracle of Nocturna — "Nocturna Dream Analyst" | — |
| 21 | The Archivist — "Meridian-9 Memory Researcher" | — |
| 22 | Tom — "Imperium-12 Corporate Strategist" | — |
| 23 | Caesar — "Prime Architect of The Room" | — |

## Summary counts

- Registry: **23** = 10 configured + 13 registry-only.
- Configured and voice-cast: **9**. Configured, voice uncast: **1** (Danny).
- 21+ characters: **3** (Crazy Kelly configured; Shawna, Ruby
  registry-only) — all locked in-app as of this sweep, all
  awaiting Richard's P7 decision.
- Marketable today: **0** — the app itself has no device or
  live-provider proof yet (P1/P2), independent of this roster.
