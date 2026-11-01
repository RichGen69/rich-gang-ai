# Rich Gang AI — production Android signing

Status: **signing code configured; production keystore NOT created**.
Richard owns the production signing identity. No agent may create
the keystore, choose its passwords, or receive its passwords in chat,
docs, source, or an evidence bundle.

## How the build now behaves

`flutter_app/android/app/build.gradle.kts` no longer assigns the
Android debug key to release builds.

- A release task (`assembleRelease`, `bundleRelease`, or a Flutter
  release build, which invokes a release Gradle task) requires real
  production signing material.
- If the material is missing or incomplete, Gradle is designed to
  stop with an explicit error beginning:
  `signing_not_configured: Production release signing is not configured.`
- There is **no debug-key fallback** for release.
- Debug builds continue to use Android's normal debug signing and do
  not need the production keystore.

Signing values are read, in priority order, from:

1. `flutter_app/android/keystore.properties` — local only and now
   explicitly covered by `flutter_app/android/.gitignore`; or
2. environment variables:
   - `RGAI_KEYSTORE_PATH`
   - `RGAI_KEYSTORE_PASSWORD`
   - `RGAI_KEY_ALIAS`
   - `RGAI_KEY_PASSWORD`

## Richard: create the keystore yourself

Do this on a machine you control. If the release build will run in
this VM, the keystore file must be present in this VM at build time,
but its password still goes only into your local
`keystore.properties` or your shell/CI secret environment — never
into chat or a committed file.

1. Choose a private location outside the repository if possible, for
   example:

   ```text
   $HOME/secure/rich-gang-ai/richgang-release.jks
   ```

2. Create the key with JDK `keytool`. Replace the alias only if you
   choose a different one, and record the alias you actually used:

   ```bash
   mkdir -p "$HOME/secure/rich-gang-ai"
   keytool -genkeypair -v \
     -keystore "$HOME/secure/rich-gang-ai/richgang-release.jks" \
     -alias richgang-release \
     -keyalg RSA -keysize 2048 -validity 10000
   ```

   `keytool` will prompt you for the passwords interactively. Those
   prompts are the secure flow: type them there, nowhere else.

3. Back up both the `.jks` file and its password in your own password
   manager / offline key backup. Losing either can permanently break
   update continuity for the same signed product identity.

4. Create `flutter_app/android/keystore.properties` locally with
   exactly these keys (values shown as placeholders, not secrets to
   copy from anyone else):

   ```properties
   storeFile=/absolute/path/to/richgang-release.jks
   storePassword=<the keystore password you just set>
   keyAlias=richgang-release
   keyPassword=<the key password you just set>
   ```

   A relative `storeFile` is resolved relative to
   `flutter_app/android/`. An absolute path is clearer.

5. Verify the certificate fingerprint yourself with:

   ```bash
   keytool -list -v \
     -keystore "$HOME/secure/rich-gang-ai/richgang-release.jks" \
     -alias richgang-release
   ```

   The release/approval record may contain **only**:
   - the key alias; and
   - the certificate SHA-256 fingerprint.

   It must never contain the keystore, private key, or any password.

## Verification limits recorded in Tranche 1

No production keystore exists in this workspace, and none was
created by the agent. Gradle execution in this VM remains subject
to the known `other_tcp` daemon block, so the signing change's
runtime Gradle behaviour must be re-proven on the first build after
Richard changes `other_tcp` to Ask: the expected result with no
keystore configured is the explicit `signing_not_configured` failure
above, before any APK is produced — not a debug-signed APK.
