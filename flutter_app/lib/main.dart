import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_scaffold.dart';
import 'core/character.dart';
import 'core/daemon_config.dart';
import 'core/native_bridge.dart';
import 'core/persistent_mind.dart';
import 'core/settings.dart';
import 'theme/obsidian.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Durable launch counter for the decaying cold open (build order
  // step 1). If storage is unreadable the counter stays 0 and the
  // cold open stays off under Standard — no guessing at the count.
  try {
    final prefs = await SharedPreferences.getInstance();
    final count = (prefs.getInt('launch_count') ?? 0) + 1;
    await prefs.setInt('launch_count', count);
    AppSettings.instance.launchCount = count;
  } catch (e) {
    debugPrint('launch counter unavailable ($e); cold open off this launch');
  }
  // Daemon config: bundled at assets/daemon_config.json. This file is
  // where user-supplied data lives — personas roster and the
  // interrogation scene ("facts" key, format in docs/SCENE_FORMAT.md).
  // A missing or empty asset boots the daemon with an empty config:
  // default personas, NO scene (interrogation shows its empty state).
  // Nothing in the app invents the missing content.
  var config = '{}';
  try {
    final loaded = await rootBundle.loadString('assets/daemon_config.json');
    if (loaded.trim().isNotEmpty) config = loaded;
  } catch (e) {
    debugPrint('daemon config asset not loaded ($e); using empty config');
  }
  // P6 runtime config: this (Dart) handle is the canonical owner
  // of file-backed daemon state. Extend the shared asset config
  // with a store_path in the app-private support directory so the
  // rusqlite store is durable. If the support directory cannot be
  // resolved, the daemon boots with the asset config unchanged —
  // its store then reports itself session-only (persistent:false)
  // rather than pretending to be durable, and the failure is in
  // the log. A store_path that cannot be OPENED still fails
  // daemon start outright (the daemon's own semantics).
  try {
    final support = await getApplicationSupportDirectory();
    await Directory('${support.path}/${DaemonConfig.storeDirectoryName}')
        .create(recursive: true);
    config = DaemonConfig.withStorePath(
      config,
      DaemonConfig.storePathForSupportDir(support.path),
    );
  } catch (e) {
    debugPrint('daemon runtime store path unavailable ($e); '
        'store stays session-only this launch');
  }
  // Character minds: load the roster and restore each agent's
  // persisted affect + self-model, so agents wake up as themselves.
  // A failure here leaves MindStore unbooted and the views boot it
  // lazily — it never blocks the app or invents a mind.
  try {
    final registry = await CharacterRegistry.load();
    // MindStore.boot also boots Danny's flagship stores (ledger +
    // self-upgrade state) and applies his persisted tuning.
    if (!registry.isEmpty) await MindStore.boot(registry);
  } catch (e) {
    debugPrint('mind store not booted at startup ($e); views retry');
  }
  // Milestone 1 handshake: boot the Rust daemon. On a machine without
  // libdaemon.so staged (desktop dev, CI) this throws - catch it and let
  // the UI show the daemon as offline instead of crashing the app.
  try {
    NativeBridge().boot(config: config);
    debugPrint('[RICHARD] daemon online: ${NativeBridge().daemonVersion}');
    // The store's first named workload (P6): a runtime-provenance
    // record, rewritten at every boot. Reading it back on a later
    // launch is the durable-store proof; a failed write is logged,
    // never hidden.
    try {
      NativeBridge().storePut(DaemonConfig.provenanceSchemaKey,
          DaemonConfig.provenanceSchemaVersion);
      NativeBridge().storePut(DaemonConfig.provenanceBootKey,
          DateTime.now().toUtc().toIso8601String());
    } catch (e) {
      debugPrint('daemon store provenance write failed: $e');
    }
  } catch (e) {
    debugPrint('daemon offline: $e');
  }
  runApp(const RichGangApp());
}

class RichGangApp extends StatelessWidget {
  const RichGangApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rich Gang AI',
      theme: Obsidian.theme(),
      home: const AppScaffold(),
    );
  }
}
