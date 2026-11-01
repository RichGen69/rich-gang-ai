# Build session addendum — 2026-10-21 (later, main chat "Resume building")

## Done this session

- **Re-verified green:** `cargo test` 19/19; `flutter analyze` clean
  (after the changes below).
- **Decaying cold open built (revised build order step 1).**
  - `AppSettings.coldOpenDuration()` in `lib/core/settings.dart`:
    Silent = never; Standard = 2400 / 1600 / 800 ms on launches
    1 / 2 / 3, then off; Theater = 2400 ms every launch. Hard gates at
    every position: kill switch, quiet hours (22:00–08:00), system
    reduced motion. Visual only — no audio, no haptics.
  - Launch count is durable via `shared_preferences` (added to
    pubspec, resolved by `flutter pub get` — 8 dependencies changed).
    Counter increments in `main()` before `runApp`; if storage is
    unreadable the count stays 0 and the cold open stays off under
    Standard rather than guessing.
  - `lib/views/cold_open_view.dart`: brand mark + the daemon's real
    status line from `NativeBridge.isUp` / `daemonVersion` ("DAEMON
    OFFLINE" when down — no invented state). Tap to skip. Wired as an
    overlay in `AppScaffold`, decided once on first build.
- **Toolchain repair:** JDK 17 was missing from this VM (the original
  install did not survive in a persistent path — `find` showed no
  `java` anywhere; the first APK retry failed on JAVA_HOME).
  Reinstalled Temurin **17.0.20.1+1** (same version as the original
  build) to the persistent `~/toolchains/jdk17`, and added
  `JAVA_HOME` + PATH to `~/workspace/flutter_env.sh` so every future
  session inherits it.

## Still blocked — unchanged root cause

`flutter build apk --release --target-platform android-arm64` now gets
past Java and fails at Gradle with **"Could not dispatch a message to
the daemon"** — the same proven cause as before: this VM's
`other_tcp` direct-network permission is Deny, severing the Gradle
client's loopback connection to its daemon. Only Richard can change
it: Muse Settings → Permissions → Direct network protocols →
`other_tcp` → **Ask**, then approve the card on the next build attempt.
Everything upstream is green; the first build after that change is
expected to produce `build/app/outputs/flutter-apk/app-release.apk`.

## Blocker diagnosis refined (2026-10-21 ~16:00 UTC)

Re-probed the `other_tcp` block with language-level socket tests; the
block is **JVM-scoped**, not a blanket loopback ban:

- Python loopback (in-process, and two separate processes, 1000-byte
  payloads) now works end-to-end — the 08:57 CDT probe failure no longer
  reproduces for Python.
- A Java client connecting to a Java server on 127.0.0.1 completes the
  TCP handshake, but the sandbox's transparent proxy injects the
  interceptor text into the socket on first read/write instead of
  proxying to the real server:

  `muse: Other TCP connections is turned off for this assistant. To
  allow it, ask the user to open Muse settings -> Permissions ->
  Direct network protocols and switch other_tcp from Deny to Ask.`

- Gradle failure chain (confirmed via `--stacktrace` + daemon
  `daemon-*.out.log`): the single-use daemon starts fine and binds its
  loopback port (e.g. 127.0.0.1:40995), the Java client "connects", then
  `MessageIOException: Could not write '/127.0.0.1:<port>'` caused by
  `java.io.IOException: Broken pipe`; the client removes the daemon
  from the registry and the daemon self-terminates on its health check.

Net: only Richard flipping `other_tcp` to Ask unblocks the APK — no
code-side route exists (Gradle 9 always forks its single-use daemon and
talks to it over a loopback socket, and bypassing a user permission
filter is not attempted).

## Still open (unchanged)

- Persona roster: only Leo / Capricorn / Aquarius named in code;
  remaining names are Richard's call (config `personas` array).
- Richard's own interrogation scene data for
  `flutter_app/assets/daemon_config.json` (format:
  `docs/SCENE_FORMAT.md`).
- No device verification possible in this VM.
