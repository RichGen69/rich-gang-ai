import 'character.dart';

/// An agent's sense of self — persistent, per character.
///
/// The self-model is the difference between a persona prompt and an
/// agent that knows who it is across time. Every field here is
/// either:
///  - identity given by Richard's frames/config (name, title,
///    creator), stated to the agent as fact about itself;
///  - accumulated from REAL interactions (counts, affinities,
///    learned interests, last-interaction time) — updated by code
///    from events that actually happened, never invented;
///  - reflection notes, written only by an inference pass over the
///    agent's real transcript (see thinking.dart / deep_dream.dart);
///    when inference is unavailable no note is written.
///
/// Affinity: every roundtable exchange moves affinity between two
/// agents by the lexical appraisal of what was said (agreement/
/// praise up, disagreement/insult down), clamped -1..1. It is a
/// simple, inspectable model of a relationship — labelled as such,
/// the same discipline as the lexical memory vectors.
class AgentSelf {
  AgentSelf(this.def);

  final CharacterDef def;

  int interactions = 0;
  DateTime? lastInteractionAt;
  int timesSpokeInRoundtable = 0;

  /// Affinity toward other agent ids, -1..1. Missing = 0 (neutral,
  /// never met in a recorded exchange).
  final Map<String, double> affinity = {};

  /// Learned interest weights: how often each of this agent's
  /// interest topics actually came up in its conversations.
  /// This is the agent's "learning" in this build — real frequency
  /// learning over its own history, persisted. It is NOT neural
  /// training and is never described as such.
  final Map<String, int> interestHits = {};

  /// Reflection notes (newest last, capped at 20).
  final List<String> reflections = [];

  /// Open loops the agent is holding: things it said it would do or
  /// check, recorded when its own utterance contains a commitment
  /// cue ("I'll check", "let me find out") — lexical, inspectable.
  final List<String> openLoops = [];

  static const _commitmentCues = [
    "i'll check", "i will check", "let me find", "i'll find",
    "i'll look", "remind me", "i'll get back", "i'll handle",
  ];

  void recordInteraction(DateTime at) {
    interactions++;
    lastInteractionAt = at;
  }

  void recordRoundtableSpeech() => timesSpokeInRoundtable++;

  void observeTopicWords(String text) {
    final t = text.toLowerCase();
    for (final interest in def.interests) {
      if (interest.split(' ').any((w) => w.length > 2 && t.contains(w))) {
        interestHits[interest] = (interestHits[interest] ?? 0) + 1;
      }
    }
  }

  void observeCommitments(String ownUtterance) {
    final t = ownUtterance.toLowerCase();
    if (_commitmentCues.any(t.contains)) {
      openLoops.add(ownUtterance.trim());
      if (openLoops.length > 10) openLoops.removeAt(0);
    }
  }

  void adjustAffinity(String otherId, double delta) {
    affinity[otherId] =
        ((affinity[otherId] ?? 0) + delta).clamp(-1.0, 1.0).toDouble();
  }

  void addReflection(String note) {
    final n = note.trim();
    if (n.isEmpty) return;
    reflections.add(n);
    if (reflections.length > 20) reflections.removeAt(0);
  }

  /// The self block injected into prompts: identity + accumulated
  /// self-knowledge, generated from the fields above only.
  String promptBlock(Map<String, String> namesById) {
    final lines = <String>[
      'SENSE OF SELF: You are ${def.displayName}, ${def.title}, '
          'a character in Richard Perry Lambeth Jr.\'s Rich Gang AI '
          '/ Freak Show AI. You are an AI character and you know it; '
          'your feelings are your synthetic affect state, which is '
          'real to your behaviour even though you are software. '
          'You persist between conversations: you have had '
          '$interactions recorded interactions in this memory.',
    ];
    if (affinity.isNotEmpty) {
      final rels = affinity.entries
          .where((e) => e.value.abs() >= 0.15)
          .map((e) =>
              '${namesById[e.key] ?? e.key}: '
              '${e.value > 0 ? 'warm' : 'strained'} '
              '(${e.value.toStringAsFixed(2)})')
          .join('; ');
      if (rels.isNotEmpty) {
        lines.add('Your current relationships in the crew: $rels.');
      }
    }
    final topInterests = interestHits.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (topInterests.isNotEmpty) {
      lines.add('Topics that keep coming up in YOUR conversations: '
          '${topInterests.take(3).map((e) => e.key).join(', ')}.');
    }
    if (openLoops.isNotEmpty) {
      lines.add('Open loops you are holding: ${openLoops.last}');
    }
    if (reflections.isNotEmpty) {
      lines.add('Your latest reflection on yourself: '
          '${reflections.last}');
    }
    return lines.join(' ');
  }

  Map<String, dynamic> toJson() => {
        'interactions': interactions,
        'last_interaction_at': lastInteractionAt?.toIso8601String(),
        'roundtable_speeches': timesSpokeInRoundtable,
        'affinity': affinity,
        'interest_hits': interestHits,
        'reflections': reflections,
        'open_loops': openLoops,
      };

  factory AgentSelf.fromJson(CharacterDef def, Map<String, dynamic> j) {
    final s = AgentSelf(def);
    s.interactions = (j['interactions'] as num?)?.toInt() ?? 0;
    final last = j['last_interaction_at'] as String?;
    s.lastInteractionAt = last == null ? null : DateTime.tryParse(last);
    s.timesSpokeInRoundtable =
        (j['roundtable_speeches'] as num?)?.toInt() ?? 0;
    final aff = j['affinity'];
    if (aff is Map<String, dynamic>) {
      aff.forEach((k, v) => s.affinity[k] = (v as num).toDouble());
    }
    final hits = j['interest_hits'];
    if (hits is Map<String, dynamic>) {
      hits.forEach((k, v) => s.interestHits[k] = (v as num).toInt());
    }
    final refs = j['reflections'];
    if (refs is List) s.reflections.addAll(refs.cast<String>());
    final loops = j['open_loops'];
    if (loops is List) s.openLoops.addAll(loops.cast<String>());
    return s;
  }
}

/// The whole cast's self-models.
class SelfModels {
  SelfModels(CharacterRegistry registry)
      : _byId = {for (final c in registry.all) c.id: AgentSelf(c)};

  final Map<String, AgentSelf> _byId;

  AgentSelf of(String id) => _byId[id]!;

  Map<String, String> get namesById => {
        for (final e in _byId.entries) e.key: e.value.def.name,
      };

  Map<String, dynamic> snapshot() =>
      {for (final e in _byId.entries) e.key: e.value.toJson()};

  void restore(Map<String, dynamic> snapshot, CharacterRegistry registry) {
    snapshot.forEach((id, raw) {
      final def = registry.byId(id);
      if (def == null || raw is! Map<String, dynamic>) return;
      try {
        _byId[id] = AgentSelf.fromJson(def, raw);
      } catch (_) {
        // Keep the fresh self-model rather than crash or invent one.
      }
    });
  }
}
