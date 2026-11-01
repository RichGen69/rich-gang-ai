import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'affect_engine.dart';
import 'character.dart';
import 'character_agent.dart';
import 'danny_chain.dart';
import 'danny_ledger.dart';
import 'danny_upgrades.dart';
import 'inference_router.dart';
import 'persistent_mind.dart';
import 'thinking.dart';
import 'time_awareness.dart';
import 'settings.dart';
import 'voice_engine.dart';
import 'web_search.dart';

/// Speaker selection — the part that makes a roundtable feel like a
/// conversation instead of a queue.
///
/// For each candidate, a desire-to-speak score:
///   interest   lexical overlap between the agent's interest tags
///              and (topic + last utterance) — labelled lexical, the
///              same honesty rule as the rest of the stack;
///   addressed  +1.2 if the last speaker named this agent (people
///              answer when spoken to — the strongest natural cue);
///   drive      talkativeness × (0.5 + arousal) from the agent's
///              REAL affect state — an excited Sally pushes in, a
///              calm Freddy waits;
///   fairness   +0.25 per turn since this agent last spoke, capped,
///              so nobody is frozen out;
///   recency    −2.0 if this agent spoke last (no monologues), and
///              a smaller penalty for speaking two turns ago;
///   jitter     small random term so equal scores don't resolve in
///              the same order every time.
/// Pure and seedable: unit-tested with a fixed [math.Random].
class TurnEngine {
  TurnEngine(this._rng);
  final math.Random _rng;

  static Set<String> _words(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.length > 2)
      .toSet();

  double score(
    CharacterDef c,
    AffectState affect, {
    required String topic,
    required String lastText,
    required String? lastSpeakerId,
    required int turnsSinceSpoke,
  }) {
    final hay = _words('$topic $lastText');
    final interestHits =
        c.interests.where((i) => i.split(' ').any(hay.contains)).length;
    var s = interestHits * 0.35;
    if (lastText.toLowerCase().contains(c.name.toLowerCase())) s += 1.2;
    // Effective talkativeness: the authored value, or Danny's
    // guardrail-tuned value when his self-upgrade path has set one
    // (affect.effectiveTalkativeness — danny_upgrades.dart).
    s += affect.effectiveTalkativeness *
        (0.5 + (affect.current.arousal + 1) / 2) *
        0.8;
    s += math.min(turnsSinceSpoke, 6) * 0.25;
    if (lastSpeakerId == c.id) s -= 2.0;
    s += _rng.nextDouble() * 0.3;
    return s;
  }

  CharacterDef pick(
    List<CharacterDef> cast,
    Map<String, AffectState> affects, {
    required String topic,
    required String lastText,
    required String? lastSpeakerId,
    required Map<String, int> turnsSinceSpoke,
  }) {
    CharacterDef? best;
    var bestScore = double.negativeInfinity;
    for (final c in cast) {
      final s = score(
        c,
        affects[c.id]!,
        topic: topic,
        lastText: lastText,
        lastSpeakerId: lastSpeakerId,
        turnsSinceSpoke: turnsSinceSpoke[c.id] ?? 99,
      );
      if (s > bestScore) {
        bestScore = s;
        best = c;
      }
    }
    return best!;
  }

  /// Agent-chosen topic for spontaneous sessions: the interest tag
  /// with the highest combined interest across the cast. Real
  /// selection from real data — the UI labels the topic as
  /// agent-chosen so Richard knows he didn't pick it.
  static String chooseTopic(List<CharacterDef> cast) {
    final counts = <String, int>{};
    for (final c in cast) {
      for (final i in c.interests) {
        counts[i] = (counts[i] ?? 0) + 1;
      }
    }
    var best = 'the crew itself';
    var bestCount = -1;
    counts.forEach((k, v) {
      if (v > bestCount) {
        bestCount = v;
        best = k;
      }
    });
    return 'What the crew really thinks about $best';
  }
}

class RoundtableTurn {
  const RoundtableTurn({
    required this.speakerId,
    required this.speakerName,
    required this.text,
    required this.emotion,
    required this.at,
    required this.isUser,
    this.thoughtSummary,
  });
  final String speakerId;
  final String speakerName;
  final String text;

  /// Speaker's derived emotion after this turn (real affect state),
  /// or '—' for Richard's own interjections.
  final String emotion;
  final DateTime at;
  final bool isUser;

  /// The agent's structured think-step summary for this turn
  /// (situation → chose → why), or null when the think step was off
  /// or could not be produced. Never filled in after the fact.
  final String? thoughtSummary;
}

enum RoundtableStatus { idle, running, paused, stopped, failed }

/// Entertainment formats for the roundtable — Richard asked for
/// more entertaining features; these are real format changes (the
/// framing goes into every turn's prompt), not renamed buttons.
enum RoundtableMode {
  freeTalk(
    'Free talk',
    'A natural crew conversation. Follow the energy, change the '
        'subject if it dies, bring it back if it was good.',
  ),
  debate(
    'Debate',
    'A structured DEBATE. Take a side on the topic and defend it. '
        'Attack arguments, not people — except in character, where '
        'a little blood is fine. Concede a point only when you are '
        'actually beaten.',
  ),
  roastBattle(
    'Roast Battle',
    'A ROAST BATTLE between the agents in the room. The topic names '
        'the target. Go hard, be funny, stay clever — every agent '
        'gets roasted in turn, and taking it well is part of the '
        'game. Richard is off-limits unless he jumps in.',
  ),
  storyChain(
    'Story Chain',
    'A STORY CHAIN. Continue the shared story from the last line, '
        'in character, 2-4 sentences, and end your turn on a hook '
        'the next agent must pick up. Never restart the story.',
  ),
  hotSeat(
    'Hot Seat',
    'HOT SEAT. The topic names who is in the seat. Everyone else '
        'asks that agent ONE hard, funny, or revealing question per '
        'turn; the agent in the seat must answer in character '
        'before the next question lands.',
  ),
  advicePanel(
    'Advice Panel',
    'An ADVICE PANEL on the topic. Each agent answers from their '
        'own angle — Dan executes, Capricorn prices it, Tammy reads '
        'it, Sally hacks it — and argues with the other answers.',
  );

  const RoundtableMode(this.label, this.framing);
  final String label;
  final String framing;
}

/// Topic presets shown in the UI (starters, not content — the
/// conversation itself is always generated live).
const roundtableTopicPresets = <String>[
  'Who in this room would survive longest on a desert island?',
  'Is the crew a family, a business, or a cult with good branding?',
  'Houston: best city in Texas or not even close?',
  'What should Rich Gang AI build next?',
  'Money vs loyalty — which one actually runs this room?',
  'The crew plans a heist movie: who plays which role?',
];

/// An autonomous agent-to-agent conversation Richard watches.
///
/// Flow per turn: TurnEngine picks who speaks → that agent's
/// CharacterAgent builds a roundtable prompt (character + real
/// affect + transcript + optional real search) → InferenceRouter
/// generates → every OTHER agent's affect appraises the utterance
/// lexically and anyone named gets addressedByName → transcript
/// grows → voice (if enabled) speaks the line in that agent's voice
/// → next turn after a human-feeling pause.
///
/// Danny's turns are the exception, and deliberately so: when
/// Danny speaks (and a mind is booted — the chain needs his
/// self-model), his flagship chain runs instead of the generic
/// path: perceive → appraise → discern → draft → critique →
/// revise → respond → reflect, critique/revise never skipped,
/// exactly as in one-to-one chat. The chain's think step
/// replaces the generic think step for his turns (never both),
/// the chain's own search replaces the turn's pre-search, and
/// the stimulus is attributed to its real speaker in both the
/// discernment record and his ledger — never to Richard by
/// default when another agent spoke last. His reflect stage
/// already records the interaction, topics and commitments, so
/// the generic self-model block skips those for his turns and
/// only keeps the table-specific counters (speeches, affinity).
/// When no mind is booted, or there is no stimulus at all (no
/// previous line and an empty topic), Danny falls back to the
/// generic path — a chain with nothing to answer would be
/// fabrication, not a flagship turn.
///
/// Failure discipline: if inference throws, the session goes to
/// [RoundtableStatus.failed] with the error in [failure] and STOPS.
/// No agent line is ever fabricated to keep the show going.
///
/// Spontaneity ("talk whenever they want"), honestly scoped: while
/// this session is open and [spontaneous] is on, a timer wakes the
/// room — a cast member starts a NEW conversation on an agent-chosen
/// topic when the room has been silent, but ONLY through the
/// restraint layer: never in quiet hours, never with the kill
/// switch tripped, never on Silent trust dial. Background starts
/// (app closed) are NOT built — that needs foreground-service work
/// and is listed as such in docs/CHARACTER_AI.md.
class RoundtableSession extends ChangeNotifier {
  RoundtableSession({
    required this.affects,
    InferenceRouter? router,
    VoiceEngine? voice,
    WebSearchService? search,
    math.Random? rng,
  })  : _router = router ?? InferenceRouter.shared,
        _voice = voice ?? VoiceEngine(),
        _search = search ?? WebSearchService(),
        _turns = TurnEngine(rng ?? math.Random());

  final AffectEngine affects;

  static RoundtableSession? _sharedInstance;

  /// The ONE table for the whole app. The nav tab and the route
  /// The Room pushes used to build separate sessions, so two
  /// conversations could run — and speak over each other — at
  /// once. Views attach/detach listeners; the session itself is
  /// owned by the app and is never disposed by a view.
  static RoundtableSession shared({required AffectEngine affects}) =>
      _sharedInstance ??= RoundtableSession(affects: affects);

  final InferenceRouter _router;
  final VoiceEngine _voice;
  final WebSearchService _search;
  final TurnEngine _turns;

  RoundtableStatus status = RoundtableStatus.idle;
  String? failure;
  String topic = '';
  bool topicChosenByAgents = false;
  List<CharacterDef> cast = const [];
  final List<RoundtableTurn> transcript = [];
  bool unhinged = true;
  bool voiceEnabled = false;
  RoundtableMode mode = RoundtableMode.freeTalk;

  /// Chain-of-thought steps before each turn (one extra inference
  /// call per turn — real cost, shown in the UI copy).
  bool thinkSteps = true;
  final Thinker _thinker = Thinker();

  /// Path of the most recent spoken line, for the UI's honest
  /// "voice: ElevenLabs / system / off" readout.
  VoicePath? lastVoicePath;

  Timer? _timer;
  bool _stepping = false;

  final Map<String, int> _turnsSince = {};

  /// Start a conversation. [topic] may be empty ONLY when
  /// [spontaneous] start is intended: the cast then chooses.
  void start({
    required List<CharacterDef> withCast,
    String topic = '',
    bool spontaneousStart = false,
  }) {
    cast = withCast;
    this.topic = topic.trim().isNotEmpty
        ? topic.trim()
        : TurnEngine.chooseTopic(withCast);
    topicChosenByAgents = topic.trim().isEmpty;
    transcript.clear();
    failure = null;
    _turnsSince
      ..clear()
      ..addAll({for (final c in cast) c.id: 99});
    status = RoundtableStatus.running;
    notifyListeners();
    unawaited(step());
    if (spontaneousStart) armSpontaneous();
  }

  void pause() {
    if (status != RoundtableStatus.running) return;
    status = RoundtableStatus.paused;
    _timer?.cancel();
    notifyListeners();
  }

  void resume() {
    if (status != RoundtableStatus.paused) return;
    status = RoundtableStatus.running;
    notifyListeners();
    unawaited(step());
  }

  Future<void> stop() async {
    status = RoundtableStatus.stopped;
    _timer?.cancel();
    await _voice.stop();
    notifyListeners();
  }

  /// Richard jumps in: his line enters the transcript and the next
  /// agent turn answers the room INCLUDING what he just said (his
  /// words are the lastText the TurnEngine scores against).
  /// The whole conversation as plain text — for the copy/export
  /// action in the view. Built only from the real transcript;
  /// an empty table exports just the header.
  String transcriptText() {
    String two(int n) => n.toString().padLeft(2, '0');
    final b = StringBuffer()
      ..writeln('RICH GANG AI — THE ROUNDTABLE')
      ..writeln(
          'Topic: ${topic.isEmpty ? '(chosen by the crew)' : topic}')
      ..writeln('Mode: ${mode.label}')
      ..writeln('Cast: ${cast.map((c) => c.name).join(', ')}')
      ..writeln();
    for (final t in transcript) {
      b.writeln('[${two(t.at.hour)}:${two(t.at.minute)}:${two(t.at.second)}] '
          '${t.speakerName}${t.isUser ? '' : ' (feeling ${t.emotion})'}: '
          '${t.text}');
      if (t.thoughtSummary != null) {
        b.writeln('    thought: ${t.thoughtSummary}');
      }
    }
    return b.toString();
  }

  void interject(String text) {
    final t = text.trim();
    if (t.isEmpty || cast.isEmpty) return;
    transcript.add(RoundtableTurn(
      speakerId: 'richard',
      speakerName: 'Richard',
      text: t,
      emotion: '—',
      at: DateTime.now(),
      isUser: true,
    ));
    for (final c in cast) {
      affects.of(c.id).appraiseText(t);
    }
    notifyListeners();
    if (status == RoundtableStatus.running) {
      unawaited(step());
    } else if (status == RoundtableStatus.paused) {
      // Interjecting at a paused table means "keep going, with
      // this" — silently swallowing the line helped no one.
      resume();
    }
  }

  /// One conversation turn. Public so the UI can run "watch" mode
  /// turn-by-turn as well as the auto loop.
  Future<void> step() async {
    if (_stepping || status != RoundtableStatus.running) return;
    if (cast.length < 2) {
      failure = 'A roundtable needs at least two agents.';
      status = RoundtableStatus.failed;
      notifyListeners();
      return;
    }
    _stepping = true;
    try {
      final last = transcript.isEmpty ? null : transcript.last;
      final speaker = _turns.pick(
        cast,
        {for (final c in cast) c.id: affects.of(c.id)},
        topic: topic,
        lastText: last?.text ?? topic,
        lastSpeakerId: last?.speakerId,
        turnsSinceSpoke: _turnsSince,
      );
      final state = affects.of(speaker.id);
      final mind = MindStore.instance;
      // Danny's flagship chain, when it can run, does its own
      // decay (perceive), its own search, and its own think step
      // (appraise) — so the generic versions of all three are
      // skipped for his turns, never doubled. The chain needs a
      // booted mind (his self-model) and a real stimulus to
      // answer: a previous line, or a topic Richard supplied.
      final useChain = speaker.id == 'danny' &&
          mind != null &&
          (transcript.isNotEmpty || topic.isNotEmpty);
      if (!useChain) state.decay();

      // Real search when the topic/last line needs outside facts —
      // once per turn at most, results or honest empty state.
      // Skipped for chain turns: the chain searches the stimulus
      // itself in its perceive stage.
      String? searchBlock;
      final probe = transcript.isEmpty ? topic : last!.text;
      if (!useChain && WebSearchService.needsSearch(probe)) {
        try {
          final results = await _search.search(probe);
          searchBlock = WebSearchService.formatForPrompt(probe, results);
        } on SearchUnavailable {
          searchBlock = 'WEB SEARCH for "$probe": providers '
              'unreachable. Say the search failed if it matters; '
              'do not invent results.';
        }
      }

      final agent = CharacterAgent(
        def: speaker,
        affect: state,
        self: mind?.selves.of(speaker.id),
        namesById: mind?.selves.namesById ?? const {},
        router: _router,
        search: _search,
      );

      String text;
      ThoughtStep? thought;
      if (useChain) {
        // DANNY'S FLAGSHIP CHAIN AT THE TABLE — mandatory
        // draft → critique → revise, exactly as in one-to-one
        // chat, and independent of the thinkSteps toggle (the
        // chain IS his think step). The stimulus speaker is the
        // previous speaker, or Richard when the topic itself is
        // the stimulus — never defaulted to Richard when another
        // agent spoke last.
        final chain = DannyChain(router: _router);
        final result = await chain.run(
          agent: agent,
          self: mind.selves.of(speaker.id),
          namesById: mind.selves.namesById,
          userText: last?.text ?? topic,
          unhinged: unhinged,
          ledger: DannyLedger.instance,
          upgrades: DannyUpgradeController.instance,
          contextLabel:
              'Roundtable (${mode.label}) with ${cast.map((c) => c.name).join(', ')}',
          stimulusSpeaker: last?.speakerId ?? 'richard',
        );
        text = result.reply;
        thought = result.thought;
      } else {
        var prompt = agent.roundtablePrompt(
          topic: topic,
          transcript: [
            for (final t in transcript)
              (speaker: t.speakerName, text: t.text),
          ],
          unhinged: unhinged,
          searchBlock: searchBlock,
          modeFraming: mode.framing,
        );

        // Chain of thought: a real think-step inference pass whose
        // result steers this turn and is shown in the transcript.
        if (thinkSteps && mind != null) {
          thought = await _thinker.think(
            def: speaker,
            affect: state,
            self: mind.selves.of(speaker.id),
            namesById: mind.selves.namesById,
            time: SessionClock.context(
                lastInteractionAt:
                    mind.selves.of(speaker.id).lastInteractionAt),
            context:
                'Roundtable (${mode.label}) with ${cast.map((c) => c.name).join(', ')}',
            stimulus: last?.text ?? 'Start the conversation on: $topic',
          );
          if (thought != null) {
            prompt += '\n\nYOUR THINKING FOR THIS TURN: '
                'situation=${thought.situation}; goal=${thought.goal}; '
                'you chose: ${thought.chosen} (${thought.why}). '
                'Now speak, following that choice.';
          }
        }

        text = await _router.run(InferenceTask.personaDialogue, prompt);
      }

      // The speaker feels its own line; everyone else hears it.
      // Chain turns skip the speaker's self-appraisal: the
      // chain's reflect stage already appraised the revised line.
      if (!useChain) state.appraiseText(text);
      for (final c in cast) {
        if (c.id == speaker.id) continue;
        final other = affects.of(c.id);
        final fired = other.appraiseText(text);
        if (text.toLowerCase().contains(c.name.toLowerCase())) {
          other.appraise(AffectEvent.addressedByName);
        }
        // THE LEDGER (Danny's gift): when Danny is the listener,
        // the appraisal events this line really fired become dated
        // gratitude/slight entries with the speaker and the reason
        // on record — persisted on his own store, like his mind.
        if (c.id == 'danny' && fired.isNotEmpty) {
          final ledger = DannyLedger.instance;
          if (ledger != null) {
            var wrote = false;
            for (final e in fired) {
              wrote = ledger.record(
                    appraisalEvent: e.name,
                    whoId: speaker.id,
                    excerpt: text,
                  ) ||
                  wrote;
            }
            if (wrote) unawaited(ledger.save());
          }
        }
      }

      // Self-model: record the speech, learn topics, hold any
      // commitment the agent made, and shift affinity toward the
      // previous speaker by the lexical tone of this line
      // (agreement warms, disagreement strains — small steps).
      if (mind != null) {
        final self = mind.selves.of(speaker.id);
        if (!useChain) {
          self.recordRoundtableSpeech();
          self.recordInteraction(DateTime.now());
          self.observeTopicWords(text);
          self.observeCommitments(text);
        } else {
          // The chain's reflect stage already recorded the
          // interaction, topics and commitments from this turn;
          // only the table-specific counters remain here.
          self.recordRoundtableSpeech();
        }
        if (last != null && !last.isUser) {
          final lt = text.toLowerCase();
          var delta = 0.0;
          if (lt.contains('agree') ||
              lt.contains('exactly') ||
              lt.contains('good point')) {
            delta = 0.06;
          }
          if (lt.contains('disagree') ||
              lt.contains('wrong') ||
              lt.contains('nonsense')) {
            delta = -0.04;
          }
          if (delta != 0) self.adjustAffinity(last.speakerId, delta);
        }
        unawaited(mind.save());
      }

      _turnsSince.updateAll((k, v) => v + 1);
      _turnsSince[speaker.id] = 0;
      transcript.add(RoundtableTurn(
        speakerId: speaker.id,
        speakerName: speaker.name,
        text: text,
        emotion: state.emotion.emotion,
        at: DateTime.now(),
        isUser: false,
        thoughtSummary: thought?.summary,
      ));
      notifyListeners();

      if (voiceEnabled && status == RoundtableStatus.running) {
        lastVoicePath = await _voice.speak(speaker, state.current, text);
        notifyListeners();
      }
    } catch (e) {
      failure = 'Inference unavailable — the conversation stopped '
          'rather than fake a line. ($e)';
      status = RoundtableStatus.failed;
      notifyListeners();
      return;
    } finally {
      _stepping = false;
    }

    // Human-feeling pacing between turns, then continue the loop.
    if (status == RoundtableStatus.running) {
      await Future<void>.delayed(const Duration(seconds: 2));
      if (status == RoundtableStatus.running) unawaited(step());
    }
  }

  /// Arm the spontaneity timer. Every 45 s, if the room is stopped
  /// or idle, the cast may start talking on its own — gated by the
  /// restraint layer exactly like every ambient feature in this app.
  void armSpontaneous() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (status == RoundtableStatus.running ||
          status == RoundtableStatus.paused) {
        return;
      }
      if (cast.length < 2) return;
      final s = AppSettings.instance;
      if (s.trustDial == TrustDial.silent) return;
      if (s.ambientKilled || AppSettings.inQuietHours) return;
      start(withCast: cast, spontaneousStart: false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
