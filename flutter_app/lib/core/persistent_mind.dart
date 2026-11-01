import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'affect_engine.dart';
import 'character.dart';
import 'danny_ledger.dart';
import 'danny_upgrades.dart';
import 'lie_detector.dart';
import 'self_model.dart';

/// Persistent memory for the agents' minds.
///
/// Three layers persist on-device, all in SharedPreferences (small
/// state only — the Rust daemon's store holds the conversation
/// memories themselves):
///  1. affect snapshot  — each agent's PAD state + when it was felt,
///     so mood survives an app restart and decays by REAL elapsed
///     time while the app was closed (AffectState.decay does that
///     math on restore).
///  2. self-models      — interactions, affinities, learned
///     interests, reflections, open loops.
///  3. last interaction — feeds real-time awareness ("you were gone
///     a day").
///
/// A failed load returns fresh state and says nothing was restored
/// ([restored] false): persistence failure degrades to a first-run
/// mind, it never fabricates a history.
class MindStore {
  MindStore(this.registry) {
    affects = AffectEngine(registry);
    selves = SelfModels(registry);
  }

  final CharacterRegistry registry;
  late final AffectEngine affects;
  late final SelfModels selves;
  bool restored = false;

  static const _key = 'mind_store_v1';

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return;
      final doc = jsonDecode(raw) as Map<String, dynamic>;
      final affectDoc = doc['affects'];
      if (affectDoc is Map<String, dynamic>) affects.restore(affectDoc);
      final selfDoc = doc['selves'];
      if (selfDoc is Map<String, dynamic>) {
        selves.restore(selfDoc, registry);
      }
      restored = true;
    } catch (_) {
      restored = false;
    }
  }

  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode({
          'affects': affects.snapshot(),
          'selves': selves.snapshot(),
        }),
      );
    } catch (_) {
      // Persistence is best-effort at this layer; the caller never
      // claims a save that failed, it just tries again next turn.
    }
  }

  /// The shared store for the app session. Built once the character
  /// registry has loaded; null before that, and callers must handle
  /// the null as "mind not ready" rather than assume a roster.
  static MindStore? instance;

  static Future<MindStore> boot(CharacterRegistry registry) async {
    final store = MindStore(registry);
    await store.load();
    instance = store;
    // Danny's flagship stores ride along with EVERY mind boot —
    // main.dart's startup path and the views' lazy retry paths
    // alike — so his ledger and self-upgrade state are never
    // silently absent in a session that booted late. His persisted
    // tuning is applied to his live affect state here, so he
    // wakes up tuned the way his accountability record says.
    try {
      await DannyLedger.boot();
      final danny = registry.byId('danny');
      if (danny != null) {
        final upgrades = await DannyUpgradeController.boot(danny);
        upgrades.applyToAffect(store.affects.of('danny'));
      }
    } catch (_) {
      // Danny's stores degrade independently: a failure leaves
      // his chain running without them (they report as absent in
      // his self-state) instead of taking the whole mind down.
    }
    try {
      // The Lie Detector's statement record rides along too.
      // Only the record loads here: the daemon boots AFTER the
      // mind in main.dart, so the detector's fact table resolves
      // lazily from the daemon at check time (lie_detector.dart).
      await LieDetector.boot();
    } catch (_) {
      // Degrades independently like Danny's stores: surfaces
      // acquire the detector lazily if this boot failed.
    }
    return store;
  }
}
