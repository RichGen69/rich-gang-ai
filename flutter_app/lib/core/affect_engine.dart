import 'dart:convert';
import 'dart:math' as math;
import 'character.dart';

/// Synthetic affect engine — the "synthetic consciousness" layer,
/// honestly scoped.
///
/// WHAT THIS IS: a functional simulation with the same moving parts
/// a feeling agent needs to behave like one across time —
///   perception (lexical appraisal of what was said/done),
///   affect state (PAD: pleasure/arousal/dominance, persistent,
///     decaying toward the character's baseline),
///   emotion labelling (nearest named-emotion prototype in PAD
///     space, with an intensity from distance),
///   self-report (a mood line generated ONLY from the real state
///     numbers — same discipline as PerformanceDirector's summary),
///   continuity (the state serialises to JSON and is persisted by
///     the caller, so an agent wakes up tomorrow in the mood the
///     conversation left it in).
///
/// WHAT THIS IS NOT: phenomenal consciousness. No file in this app
/// claims the agents are sentient. They simulate the full *range* of
/// human emotions as labelled states that drive word choice, voice
/// prosody, and who speaks next — which is what Richard asked to
/// build ("give them synthetic consciousness with full range of
/// human emotions and feelings"), delivered without pretending the
/// simulation is the thing itself.
///
/// Appraisal is LEXICAL (word lists), the same honest labelling as
/// the Rust vector store's token-overlap vectors: it reacts to words
/// it recognises and says so. It is not semantic understanding.
class Pad {
  const Pad(this.pleasure, this.arousal, this.dominance);
  final double pleasure; // -1..1
  final double arousal; // -1..1
  final double dominance; // -1..1

  Pad operator +(Pad o) => Pad(
        (pleasure + o.pleasure).clamp(-1.0, 1.0),
        (arousal + o.arousal).clamp(-1.0, 1.0),
        (dominance + o.dominance).clamp(-1.0, 1.0),
      );

  double distanceTo(Pad o) {
    final dp = pleasure - o.pleasure;
    final da = arousal - o.arousal;
    final dd = dominance - o.dominance;
    return math.sqrt(dp * dp + da * da + dd * dd);
  }

  Map<String, dynamic> toJson() =>
      {'p': pleasure, 'a': arousal, 'd': dominance};
  factory Pad.fromJson(Map<String, dynamic> j) => Pad(
        (j['p'] as num).toDouble(),
        (j['a'] as num).toDouble(),
        (j['d'] as num).toDouble(),
      );
}

/// Named emotions as PAD prototypes (standard PAD emotion mapping,
/// Mehrabian). The derived emotion for any state is the nearest
/// prototype; intensity falls off with distance, so a state far from
/// every prototype honestly reports as low-intensity / mixed.
const Map<String, Pad> emotionPrototypes = {
  'joy': Pad(0.8, 0.6, 0.5),
  'excitement': Pad(0.7, 0.9, 0.4),
  'amusement': Pad(0.6, 0.5, 0.3),
  'affection': Pad(0.7, 0.2, 0.2),
  'desire': Pad(0.6, 0.7, 0.3),
  'pride': Pad(0.6, 0.3, 0.8),
  'relief': Pad(0.5, -0.3, 0.3),
  'curiosity': Pad(0.3, 0.5, 0.1),
  'calm': Pad(0.4, -0.6, 0.4),
  'contentment': Pad(0.6, -0.4, 0.3),
  'boredom': Pad(-0.3, -0.6, -0.1),
  'loneliness': Pad(-0.6, -0.3, -0.5),
  'sadness': Pad(-0.7, -0.4, -0.5),
  'grief': Pad(-0.9, 0.1, -0.7),
  'shame': Pad(-0.6, 0.2, -0.8),
  'guilt': Pad(-0.5, 0.1, -0.6),
  'anxiety': Pad(-0.5, 0.7, -0.6),
  'fear': Pad(-0.7, 0.9, -0.8),
  'frustration': Pad(-0.6, 0.6, 0.2),
  'anger': Pad(-0.7, 0.8, 0.6),
  'contempt': Pad(-0.4, 0.3, 0.7),
  'disgust': Pad(-0.8, 0.4, 0.3),
  'surprise': Pad(0.1, 0.9, -0.2),
  'awe': Pad(0.5, 0.6, -0.4),
};

class EmotionReading {
  const EmotionReading(this.emotion, this.intensity);
  final String emotion;

  /// 0..1 — 1 when the state sits on the prototype.
  final double intensity;
}

/// Events the engine can appraise. Sources: the user's message
/// (lexical), an agent's own turn outcome, search results, being
/// addressed by name in a roundtable, a task Dan completed, etc.
enum AffectEvent {
  praised,
  insulted,
  thanked,
  ignored,
  addressedByName,
  taskSucceeded,
  taskFailed,
  searchFound,
  searchFailed,
  romanticWarmth,
  disagreement,
  agreement,
  novelty,
  longSilence,
}

/// Fixed appraisal vectors (PAD deltas before volatility scaling).
/// These are design constants of the simulation, documented here —
/// not measurements of anything, and never presented as such.
const Map<AffectEvent, Pad> _appraisals = {
  AffectEvent.praised: Pad(0.35, 0.20, 0.25),
  AffectEvent.insulted: Pad(-0.45, 0.45, -0.20),
  AffectEvent.thanked: Pad(0.30, 0.10, 0.15),
  AffectEvent.ignored: Pad(-0.20, -0.10, -0.20),
  AffectEvent.addressedByName: Pad(0.15, 0.25, 0.05),
  AffectEvent.taskSucceeded: Pad(0.30, 0.25, 0.35),
  AffectEvent.taskFailed: Pad(-0.35, 0.30, -0.25),
  AffectEvent.searchFound: Pad(0.20, 0.30, 0.20),
  AffectEvent.searchFailed: Pad(-0.15, 0.10, -0.10),
  AffectEvent.romanticWarmth: Pad(0.40, 0.35, 0.0),
  AffectEvent.disagreement: Pad(-0.15, 0.35, 0.10),
  AffectEvent.agreement: Pad(0.20, 0.05, 0.10),
  AffectEvent.novelty: Pad(0.15, 0.40, 0.0),
  AffectEvent.longSilence: Pad(-0.10, -0.25, -0.05),
};

/// Lexical cue lists for appraising raw text. Deliberately small and
/// inspectable; a miss means no appraisal, never a guessed one.
const Map<AffectEvent, List<String>> _cues = {
  AffectEvent.praised: [
    'great', 'amazing', 'awesome', 'brilliant', 'perfect', 'love it',
    'well done', 'impressive', 'genius', 'beautiful',
  ],
  AffectEvent.insulted: [
    'stupid', 'useless', 'dumb', 'pathetic', 'shut up', 'hate you',
    'worthless', 'idiot',
  ],
  AffectEvent.thanked: ['thank', 'thanks', 'appreciated', 'grateful'],
  AffectEvent.romanticWarmth: [
    'love you', 'miss you', 'kiss', 'beautiful', 'darling', 'baby',
    'gorgeous', 'need you',
  ],
  AffectEvent.disagreement: [
    'wrong', 'disagree', 'no way', "that's not", 'nonsense', 'bullshit',
  ],
  AffectEvent.agreement: ['exactly', 'agree', 'right', 'yes', 'true'],
};

/// One character's live affect state.
class AffectState {
  AffectState(this.character)
      : current = Pad(character.baselinePleasure, character.baselineArousal,
            character.baselineDominance),
        updatedAt = DateTime.now();

  AffectState._(this.character, this.current, this.updatedAt);

  final CharacterDef character;
  Pad current;
  DateTime updatedAt;

  /// Self-upgrade tuning overrides (Danny only, 2026-10-23): set
  /// ONLY through the guardrailed, logged self-upgrade path
  /// (danny_upgrades.dart), restored from his persisted tuning
  /// state at boot. Null = the authored definition values rule.
  /// These are the live end of the leash: decay, appraisal scaling
  /// and turn-taking all read the EFFECTIVE values below, so a
  /// verified tuning change genuinely changes how Danny feels and
  /// speaks — and a rollback genuinely changes it back.
  Pad? tunedBaseline;
  double? tunedTalkativeness;
  double? tunedVolatility;

  Pad get baseline =>
      tunedBaseline ??
      Pad(character.baselinePleasure, character.baselineArousal,
          character.baselineDominance);

  double get effectiveTalkativeness =>
      tunedTalkativeness ?? character.talkativeness;
  double get effectiveVolatility =>
      tunedVolatility ?? character.volatility;

  /// Apply an event, scaled by this character's volatility.
  void appraise(AffectEvent e) {
    final v = _appraisals[e]!;
    final s = 0.4 + effectiveVolatility; // 0.4..1.25 multiplier
    current = current + Pad(v.pleasure * s, v.arousal * s, v.dominance * s);
    updatedAt = DateTime.now();
  }

  /// Appraise text lexically. Returns the events actually matched —
  /// callers (and tests) can see exactly what fired and what didn't.
  List<AffectEvent> appraiseText(String text) {
    final t = ' ${text.toLowerCase()} ';
    final fired = <AffectEvent>[];
    _cues.forEach((event, words) {
      if (words.any((w) => t.contains(w))) {
        appraise(event);
        fired.add(event);
      }
    });
    return fired;
  }

  /// Decay toward baseline: 12% of the remaining distance per
  /// 5 minutes elapsed, computed from real elapsed time — an agent
  /// left furious at lunch is merely annoyed by dinner, and back to
  /// itself by tomorrow. No decay is applied for zero elapsed time.
  void decay([DateTime? now]) {
    final at = now ?? DateTime.now();
    final elapsed = at.difference(updatedAt);
    if (elapsed <= Duration.zero) return;
    final steps = elapsed.inSeconds / 300.0; // per 5 min
    final keep = math.pow(0.88, steps).toDouble();
    final b = baseline;
    current = Pad(
      b.pleasure + (current.pleasure - b.pleasure) * keep,
      b.arousal + (current.arousal - b.arousal) * keep,
      b.dominance + (current.dominance - b.dominance) * keep,
    );
    updatedAt = at;
  }

  EmotionReading get emotion {
    var best = 'calm';
    var bestDist = double.infinity;
    emotionPrototypes.forEach((name, proto) {
      final d = current.distanceTo(proto);
      if (d < bestDist) {
        bestDist = d;
        best = name;
      }
    });
    // Max PAD distance is ~3.46; intensity 1 at the prototype.
    final intensity = (1.0 - bestDist / 2.0).clamp(0.0, 1.0);
    return EmotionReading(best, intensity);
  }

  /// Self-report generated only from the real state above. This is
  /// the agent's "inner monologue" line for prompts and the UI:
  /// factual about the simulation, worded in first person.
  String moodLine() {
    final e = emotion;
    final strength = e.intensity >= 0.75
        ? 'strongly'
        : e.intensity >= 0.5
            ? 'clearly'
            : 'a little';
    return 'I am feeling $strength ${e.emotion} right now '
        '(pleasure ${current.pleasure.toStringAsFixed(2)}, '
        'arousal ${current.arousal.toStringAsFixed(2)}, '
        'dominance ${current.dominance.toStringAsFixed(2)}).';
  }

  Map<String, dynamic> toJson() => {
        'id': character.id,
        'pad': current.toJson(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory AffectState.fromJson(CharacterDef c, Map<String, dynamic> j) =>
      AffectState._(
        c,
        Pad.fromJson(j['pad'] as Map<String, dynamic>),
        DateTime.parse(j['updated_at'] as String),
      );

  String encode() => jsonEncode(toJson());
}

/// The whole cast's affect, keyed by character id. The caller
/// persists [snapshot] (e.g. SharedPreferences) for continuity.
class AffectEngine {
  AffectEngine(this.registry) {
    for (final c in registry.all) {
      _states[c.id] = AffectState(c);
    }
  }

  final CharacterRegistry registry;
  final Map<String, AffectState> _states = {};

  AffectState of(String characterId) => _states[characterId]!;

  void restore(Map<String, dynamic> snapshot) {
    snapshot.forEach((id, raw) {
      final c = registry.byId(id);
      if (c == null || raw is! Map<String, dynamic>) return;
      try {
        final s = AffectState.fromJson(c, raw)..decay();
        _states[id] = s;
      } catch (_) {
        // Corrupt entry: keep the baseline state rather than crash
        // or invent a mood.
      }
    });
  }

  Map<String, dynamic> snapshot() =>
      {for (final e in _states.entries) e.key: e.value.toJson()};
}
