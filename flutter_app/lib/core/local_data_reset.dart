import 'package:shared_preferences/shared_preferences.dart';

import 'age_assurance.dart';
import 'secure_keys.dart';

/// The app's own inventory of local preference data, for the
/// Settings reset action (SEC-07).
///
/// The reset removes exactly the keys this inventory names — the
/// mind store, Danny's stores, the discernment store, age-assurance
/// state (including the removed legacy confirmation key), the launch
/// counter, and the per-character provider/stage ID preferences.
/// It does not guess at other apps' or plugins' keys.
///
/// Honest limit: stores already loaded into memory (MindStore,
/// Danny's controllers) keep their in-memory state until the app
/// restarts. The Settings copy says so; the reset takes full effect
/// on the next launch.
class LocalDataReset {
  LocalDataReset._();

  static const Set<String> exactKeys = {
    'mind_store_v1',
    'danny_ledger_v1',
    'danny_upgrades_v1',
    'lie_detector_v1',
    'call_history_v1',
    AgeAssurance.preferenceKey,
    // Legacy self-confirmation key from the pre-boundary AgeGate.
    // It grants nothing now, and reset removes it like everything
    // else in the inventory.
    'age_21_confirmed',
    'launch_count',
  };

  static const List<String> keyPrefixes = [
    'liveavatar_avatar_',
    'liveavatar_voice_',
    'liveavatar_context_',
    'heygen_avatar_',
    'avatar3d_src_',
  ];

  static bool isLocalDataKey(String key) =>
      exactKeys.contains(key) ||
      keyPrefixes.any((prefix) => key.startsWith(prefix));

  /// Remove every inventoried preference key. Returns how many
  /// keys were present and removed.
  static Future<int> clearPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where(isLocalDataKey).toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
    return keys.length;
  }

  /// Remove every stored provider credential (secure storage).
  static Future<void> removeAllApiKeys() => SecureKeys.clearAll();
}
