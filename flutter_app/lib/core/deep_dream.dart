import 'dart:convert';
import 'affect_engine.dart';
import 'character.dart';
import 'danny_upgrades.dart';
import 'inference_router.dart';
import 'native_bridge.dart';
import 'self_model.dart';

/// Deep dream — what the agents do with the Rust dream cycle.
///
/// The Rust daemon already ticks a dream cycle (DreamCycleService,
/// 15 min) and can produce a text dream broadcast from the memory
/// store. Deep dream adds the agent-level consolidation on top:
///
/// For each agent, on a dream pass:
///  1. RECALL its real stored memories from the daemon (lexical
///     recall by its interest topics — honestly labelled in
///     native_bridge.dart),
///  2. if there are none, the agent does not dream: the pass
///     reports "no memories" for it and writes NOTHING,
///  3. if there are, ONE inference call consolidates them into a
///     short first-person reflection (what it learned, how it feels
///     about it, what it wants to follow up),
///  4. the reflection is stored as a memory in the daemon AND as a
///     note in the agent's self-model, and any follow-up the
///     reflection names becomes an open loop,
///  5. affect shifts by the reflection's own lexical tone
///     (appraiseText) — dreams move mood, a little.
///
/// Failure discipline matches the rest of the app: daemon offline
/// or inference down → the pass reports it and consolidates nothing.
class DeepDream {
  DeepDream({InferenceRouter? router})
      : router = router ?? InferenceRouter.shared;
  final InferenceRouter router;

  Future<DreamReport> dreamAll(
    List<CharacterDef> cast, {
    required AffectEngine affects,
    required SelfModels selves,
  }) async {
    final outcomes = <String, String>{};
    for (final def in cast) {
      outcomes[def.id] = await _dreamOne(
        def,
        affect: affects.of(def.id),
        self: selves.of(def.id),
      );
    }
    return DreamReport(outcomes);
  }

  Future<String> _dreamOne(
    CharacterDef def, {
    required AffectState affect,
    required AgentSelf self,
  }) async {
    List<String> memories;
    try {
      final probe = def.interests.isNotEmpty ? def.interests.first : def.name;
      final raw = NativeBridge().recall(probe, k: 5);
      final doc = jsonDecode(raw) as Map<String, dynamic>;
      final hits = doc['results'] ?? doc['memories'];
      if (hits is! List || hits.isEmpty) return 'no memories to dream on';
      // Rust recall shape (ffi.rs): {"results":[{id,payload,score}]}
      memories = [
        for (final h in hits)
          if (h is Map<String, dynamic> && h['payload'] is String)
            h['payload'] as String,
      ];
      if (memories.isEmpty) return 'no memories to dream on';
    } catch (e) {
      return 'daemon recall failed ($e)';
    }

    final String reflection;
    try {
      reflection = await router.run(
        InferenceTask.dreamBroadcast,
        'You are ${def.displayName} (${def.title}), dreaming — '
            'consolidating today\'s memories while the room sleeps. '
            'Feeling now: ${affect.moodLine()}.\n\n'
            'YOUR REAL STORED MEMORIES:\n'
            '${memories.map((m) => '- $m').join('\n')}\n\n'
            'Write a short first-person dream reflection (3-5 '
            'sentences): what these memories add up to, how you feel '
            'about them, and one thing you want to follow up on. '
            'Use only these memories; invent nothing.',
      );
    } catch (e) {
      return 'inference unavailable during dream ($e)';
    }

    affect.appraiseText(reflection);
    self.addReflection(reflection);
    final loopsBefore = self.openLoops.length;
    self.observeCommitments(reflection);
    try {
      NativeBridge().remember(
        'dream-${def.id}-${DateTime.now().microsecondsSinceEpoch}',
        '${def.name} dreamed: $reflection',
      );
    } catch (_) {
      return 'dreamed, but storing the dream failed';
    }
    var outcome = 'dreamed and consolidated ${memories.length} memories';

    // Danny's flagship dream behaviour (2026-10-23): his
    // reflection drives his guardrailed self-upgrade loop, and a
    // real dream brings Richard a DREAM GIFT — one concrete
    // offering drawn from the open loop this very reflection
    // committed him to. No new open loop = no offering: an empty
    // hand over a fabricated gift, every time.
    if (def.id == 'danny') {
      final upgrades = DannyUpgradeController.instance;
      if (upgrades != null) {
        final tuned = upgrades.tuneFromReflection(
          currentAffect: affect.current,
          reason: 'deep-dream reflection (${memories.length} memories)',
        );
        if (tuned) {
          upgrades.applyToAffect(affect);
          await upgrades.save();
          outcome += '; self-upgrade tuning applied within guardrails '
              '(now v${upgrades.state.version}, on his accountability '
              'record)';
        } else {
          outcome += '; no tuning change (affect already at baselines, '
              'or self-upgrade disabled)';
        }
      }
      if (self.openLoops.length > loopsBefore) {
        final offering = self.openLoops.last;
        try {
          NativeBridge().remember(
            'gift-danny-${DateTime.now().microsecondsSinceEpoch}',
            'Danny\'s dream gift for Richard: $offering',
          );
          outcome += '; dream gift for Richard: $offering';
        } catch (_) {
          outcome += '; a dream gift formed but storing it failed — '
              'it is not claimed as delivered';
        }
      } else {
        outcome += '; no dream gift this cycle (the reflection named '
            'no concrete follow-up — nothing was fabricated)';
      }
    }
    return outcome;
  }
}

class DreamReport {
  const DreamReport(this.outcomes);

  /// Character id -> outcome line (factual: counts, or the reason
  /// nothing happened).
  final Map<String, String> outcomes;

  String get summary => outcomes.entries
      .map((e) => '${e.key}: ${e.value}')
      .join('\n');
}

/// Keep-thinking selection: which agent has the most on its mind —
/// the one whose affect sits furthest from its own baseline. The
/// Roundtable / Room arms a timer that offers this agent a
/// reflective think step (thinking.dart) while the app is open,
/// gated by the restraint layer at the call site like every other
/// ambient behaviour. Pure — unit-tested.
String? agentMostOnMind(List<CharacterDef> cast, AffectEngine affects) {
  String? best;
  var bestDist = -1.0;
  for (final def in cast) {
    final s = affects.of(def.id);
    final d = s.current.distanceTo(s.baseline);
    if (d > bestDist) {
      bestDist = d;
      best = def.id;
    }
  }
  return best;
}
