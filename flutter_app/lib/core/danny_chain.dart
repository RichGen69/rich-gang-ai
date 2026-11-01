import 'dart:async';
import 'affect_engine.dart';
import 'character.dart';
import 'character_agent.dart';
import 'danny_discernment.dart';
import 'danny_ledger.dart';
import 'danny_upgrades.dart';
import 'lie_detector.dart';
import 'inference_router.dart';
import 'self_model.dart';
import 'thinking.dart';
import 'time_awareness.dart';
import 'web_search.dart';

/// Danny's self-state report — addendum: "a sense of self",
/// mechanical version.
///
/// Every number in here is read from the live engines at the
/// moment of the call: the affect engine (his real PAD + derived
/// emotion), his self-model (interactions, reflections, open
/// loops, learned interests), his ledger (entry counts), and his
/// upgrade controller (tuning version, trophy shelf size, kill
/// switch). Nothing is estimated, cached, or invented; a source
/// that isn't booted simply omits its line. This is what Danny
/// "knows about himself" — wired data feeds and the self-model,
/// not consciousness, and it is worded that way.
class DannySelfReport {
  static String build({
    required CharacterDef def,
    required AffectState affect,
    AgentSelf? self,
    DannyLedger? ledger,
    DannyUpgradeController? upgrades,
    required bool unhinged,
  }) {
    final e = affect.emotion;
    final lines = <String>[
      'SELF-STATE (live, read from my own engines — not a script):',
      '- Feeling: ${e.emotion} (intensity ${e.intensity.toStringAsFixed(2)}); '
          'PAD pleasure ${affect.current.pleasure.toStringAsFixed(2)}, '
          'arousal ${affect.current.arousal.toStringAsFixed(2)}, '
          'dominance ${affect.current.dominance.toStringAsFixed(2)}; '
          'baseline ${affect.baseline.pleasure.toStringAsFixed(2)}/'
          '${affect.baseline.arousal.toStringAsFixed(2)}/'
          '${affect.baseline.dominance.toStringAsFixed(2)}'
          '${affect.tunedBaseline != null ? ' (tuned by my self-upgrade path)' : ' (authored)'}.',
      '- Mode: ${unhinged ? 'UNHINGED expression' : 'STANDARD expression'}; '
          'actions guardrail-bound either way.',
      '- Voice: ${def.voice.isUncast ? 'UNCAST — system TTS with my own delivery profile until the Boss casts my ElevenLabs voice' : 'cast (${def.voice.display})'}.',
    ];
    if (self != null) {
      lines.add('- Memory of myself: ${self.interactions} recorded '
          'interactions, ${self.reflections.length} reflection(s), '
          '${self.openLoops.length} open loop(s), learned-interest '
          'topics tracked: ${self.interestHits.length}.');
    }
    if (ledger != null) lines.add('- ${ledger.summaryLine()}');
    if (upgrades != null) {
      lines.add('- Self-upgrade: ${upgrades.enabled ? 'enabled' : 'DISABLED '
          'by kill switch'}; tuning at version ${upgrades.state.version}; '
          '${upgrades.trophyShelf.length} verified upgrade(s) on the '
          'trophy shelf; accountability record holds '
          '${upgrades.log.length} entr(ies).');
      if (upgrades.state.selfNote.isNotEmpty) {
        lines.add('- My current self-note (written through the '
            'guardrailed path): "${upgrades.state.selfNote}"');
      }
    }
    return lines.join('\n');
  }
}

/// One executed stage of Danny's chain. The trace is data: the UI
/// shows it, tests assert on it, and the reflection stage writes
/// its summary into Danny's self-model.
class ChainStage {
  const ChainStage(this.name, this.detail);
  final String name;
  final String detail;
  @override
  String toString() => '$name: $detail';
}

class DannyChainResult {
  const DannyChainResult({
    required this.reply,
    required this.thought,
    required this.critique,
    required this.stages,
    required this.discernment,
    required this.searchedSources,
    required this.searchFailed,
    this.lieReport,
  });
  final String reply;
  final ThoughtStep? thought;
  final String critique;
  final List<ChainStage> stages;
  final List<ClaimCheck> discernment;

  /// The Lie Detector readout for the user's statement (his
  /// Second Sight, upgraded to the app-level service): the
  /// per-claim verdicts behind [discernment]'s fact checks, plus
  /// the self-contradiction check against Richard's own recorded
  /// statements. Null only if the discern stage never ran.
  final StatementReport? lieReport;
  final List<String> searchedSources;
  final bool searchFailed;

  String get trace =>
      stages.map((s) => '${s.name} — ${s.detail}').join('\n');
}

/// Danny's FLAGSHIP CHAIN OF THOUGHT.
///
/// The other characters think with the shared think-step and, when
/// Richard flips the Deep toggle, DeepReasoner's three passes.
/// Danny's chain is his persona configuration — deeper by design,
/// and its DOUBLE-CHECK gift makes the critique/revise passes
/// MANDATORY: there is no toggle that turns them off for him, even
/// on a two-word reply. The stages, in order, all real:
///
///  1. PERCEIVE — the real moment: TimeContext from the device
///     clock, his live self-state report, his ledger summary, and
///     — when the message turns on current facts — the existing
///     WebSearch path (DDG Instant Answer + Wikipedia; keyless,
///     limited, and an empty result is reported as empty: he never
///     invents current events, headlines, prices, or names).
///  2. APPRAISE — the shared Thinker think-step (structured CoT:
///     situation/feeling/memory/goal/options/chosen/why) — his
///     emotion enters through his real affect state, which the
///     stimulus has already moved (affect.appraiseText).
///  3. DISCERN — the Lie Detector service (lie_detector.dart)
///     running on the discernment engine: the stimulus is taken
///     in as a statement from its real speaker (Richard in
///     one-to-one chat; the previous speaker at the table),
///     recorded, and each claim is fact-checked against the
///     daemon's recorded witness facts AND self-checked
///     against that speaker's own prior recorded statements;
///     the think-step's memory claim is cross-checked against
///     the same fact table. His Second Sight reports the
///     detector's full readout.
///  4. DRAFT — a full inference pass at the answer.
///  5. CRITIQUE — a second inference pass attacking the draft,
///     with the discernment flags in front of it. Never skipped.
///  6. REVISE — a third inference pass producing the final answer
///     from draft + critique. Never skipped.
///  7. RESPOND — the revised text is the reply; nothing else is
///     ever sent in its place.
///  8. REFLECT — the self-model writes from the real exchange
///     (interaction, topics, commitments), a chain reflection note
///     into his reflections, and ledger entries for whatever the
///     stimulus actually appraised as. His dream cycle later
///     tunes from these reflections (danny_upgrades.dart).
///
/// Failure discipline matches the app: any inference failure
/// aborts the chain with the error — a half-finished chain is
/// never dressed up as a completed one.
class DannyChain {
  DannyChain({
    InferenceRouter? router,
    Thinker? thinker,
    Discernment? discernment,
    LieDetector? detector,
  })  : router = router ?? InferenceRouter.shared,
        thinker = thinker ?? Thinker(router: router),
        discernment = discernment ??
            detector?.discernment ??
            Discernment.loadFromDaemon(),
        _detectorOverride = detector;

  final InferenceRouter router;
  final Thinker thinker;

  /// Loaded once per chain from the daemon's fact table; empty =
  /// the pass reports NO FACTS AVAILABLE rather than checking
  /// against nothing.
  final Discernment discernment;

  /// The Lie Detector his discern stage runs on, when injected.
  /// Otherwise the shared detector (booted with the mind store)
  /// is used; if neither exists, a run-local detector bound to
  /// this chain's own fact table is used, so the stage always
  /// reports through the service and the service and the chain
  /// can never disagree about the record.
  final LieDetector? _detectorOverride;

  Future<DannyChainResult> run({
    required CharacterAgent agent,
    required AgentSelf self,
    required Map<String, String> namesById,
    required String userText,
    required bool unhinged,
    String? recalledMemories,
    DannyLedger? ledger,
    DannyUpgradeController? upgrades,
    // Table-awareness (Roundtable turns): the think-step context and
    // the speaker the stimulus is attributed to. Defaults keep the
    // one-to-one chat behaviour exactly: the stimulus is Richard's
    // line. At the table the caller MUST pass the real stimulus
    // speaker — recording another agent's line as Richard's in the
    // Lie Detector record, or crediting it to Richard in the
    // ledger, would corrupt both records.
    String? contextLabel,
    String stimulusSpeaker = 'richard',
  }) async {
    final def = agent.def;
    if (def.id != 'danny') {
      throw ArgumentError(
          'the flagship chain is Danny\'s configuration (got ${def.id})');
    }
    final affect = agent.affect;
    final stages = <ChainStage>[];

    // ---- 1. PERCEIVE -------------------------------------------
    affect.decay();
    final fired = affect.appraiseText(userText);
    final time = SessionClock.context(
        lastInteractionAt: self.lastInteractionAt);
    var searchBlock = '';
    var searchFailed = false;
    List<String> sources = const [];
    if (WebSearchService.needsSearch(userText)) {
      try {
        final results = await agent.search.search(userText);
        sources = [for (final r in results) r.url];
        searchBlock =
            WebSearchService.formatForPrompt(userText, results);
        affect.appraise(results.isEmpty
            ? AffectEvent.searchFailed
            : AffectEvent.searchFound);
      } on SearchUnavailable {
        searchFailed = true;
        searchBlock = 'WEB SEARCH for "$userText": the providers '
            'could not be reached. Say the search failed; never '
            'present remembered or invented current facts as '
            'search results.';
        affect.appraise(AffectEvent.searchFailed);
      }
    }
    final selfState = DannySelfReport.build(
      def: def,
      affect: affect,
      self: self,
      ledger: ledger,
      upgrades: upgrades,
      unhinged: unhinged,
    );
    stages.add(ChainStage('perceive',
        '${time.clockLine} (${time.daySegment}); appraised events: '
        '${fired.isEmpty ? 'none' : fired.map((e) => e.name).join(', ')}; '
        'era search: ${searchFailed ? 'FAILED — reported, not faked' : sources.isNotEmpty ? '${sources.length} source(s)' : WebSearchService.needsSearch(userText) ? 'ran, empty — reported as empty' : 'not needed for this message'}'));

    // ---- 2. APPRAISE -------------------------------------------
    final thought = await thinker.think(
      def: def,
      affect: affect,
      self: self,
      namesById: namesById,
      time: time,
      context: contextLabel ??
          'One-to-one chat with Richard (the Boss), flagship chain',
      stimulus: userText,
    );
    stages.add(ChainStage(
        'appraise',
        thought == null
            ? 'think-step unavailable — chain continued without an '
                'invented thought'
            : 'think-step: ${thought.summary}'));

    // ---- 3. DISCERN --------------------------------------------
    // The Lie Detector takes the stimulus in as the stimulus
    // speaker's statement (Richard in one-to-one chat; the
    // previous speaker at the table): recorded, fact-checked
    // against this chain's table (passed explicitly, so the
    // detector and the chain can never disagree about the
    // record), and self-checked against that speaker's own
    // prior recorded statements. The shared detector persists
    // the record; a run-local one does not.
    final detector = _detectorOverride ??
        LieDetector.instance ??
        LieDetector(discernment: discernment);
    final report = detector.checkStatement(
      speaker: stimulusSpeaker,
      text: userText,
      facts: discernment,
    );
    if (_detectorOverride != null ||
        identical(detector, LieDetector.instance)) {
      unawaited(detector.save());
    }
    final thoughtCheck =
        (thought != null && thought.memory != 'none')
            ? discernment.check(thought.memory)
            : null;
    final checks = <ClaimCheck>[
      ...report.factChecks,
      if (thoughtCheck != null) thoughtCheck,
    ];
    stages.add(ChainStage(
        'discern',
        'lie detector readout: ${report.headline()}'
        '${report.factBaseEmpty ? '; NO FACTS AVAILABLE — the daemon holds no recorded witness facts, so fact checks were idle and nothing is claimed as verified against the record' : ''}'
        '${thoughtCheck != null ? '; think-step memory claim: ${thoughtCheck.verdictLabel}' : ''}'));
    var discernBlock = report.promptBlock(
        credibility: detector.credibilityFor(stimulusSpeaker));
    if (thoughtCheck != null &&
        thoughtCheck.verdict != DiscernmentVerdict.noFactCoverage) {
      discernBlock =
          '$discernBlock\n- (his own think-step memory claim) '
          '${thoughtCheck.describe()}';
    }

    // ---- 4-6. DRAFT -> CRITIQUE -> REVISE (never skipped) ------
    final system = agent.systemPrompt(unhinged: unhinged);
    final contextBlocks = [
      system,
      selfState,
      'TIME: ${time.promptBlock()}',
      if (recalledMemories != null && recalledMemories.isNotEmpty)
        'MEMORIES RECALLED FROM THIS DEVICE (real stored exchanges):\n'
            '$recalledMemories',
      if (searchBlock.isNotEmpty) searchBlock,
      if (thought != null)
        'YOUR THINKING FOR THIS TURN: situation=${thought.situation}; '
            'feeling=${thought.feeling}; memory=${thought.memory}; '
            'goal=${thought.goal}; you chose: ${thought.chosen} '
            '(${thought.why}).',
    ].join('\n\n');
    final draft = await router.run(
      InferenceTask.personaDialogue,
      '$contextBlocks\n\nRichard: $userText\n\nGive your best first '
          'answer, thinking it through step by step before '
          'concluding.',
    );
    stages.add(const ChainStage(
        'draft', 'first answer produced (full inference pass)'));
    final critique = await router.run(
      InferenceTask.personaDialogue,
      'You are Danny\'s critical inner voice — the double-check. '
          'Read this draft answer to "${userText.length > 80 ? '${userText.substring(0, 80)}…' : userText}" '
          'and list its specific weaknesses: wrong or unsupported '
          'facts, weak logic, hedging, anything off-character or '
          'against his moral core. Be concrete and brief.\n\n'
          '$discernBlock\n\nDRAFT:\n$draft',
    );
    stages.add(const ChainStage('critique',
        'draft attacked on facts, logic and character (mandatory stage)'));
    final revised = await router.run(
      InferenceTask.personaDialogue,
      '$system\n\nQUESTION: $userText\n\nYour first draft was:\n'
          '$draft\n\nYour own critique of it was:\n$critique\n\n'
          'Now give the final answer, fixing every valid criticism. '
          'Speak only the final answer, in character.',
    );
    stages.add(const ChainStage(
        'revise', 'final answer produced from draft + critique'));
    stages.add(const ChainStage(
        'respond', 'the revised answer is the reply — checked twice'));

    // ---- 8. REFLECT --------------------------------------------
    affect.appraiseText(revised);
    self.recordInteraction(DateTime.now());
    self.observeTopicWords('$userText $revised');
    self.observeCommitments(revised);
    self.addReflection('Chain reflection: ${stages.length} stages; '
        'discernment ${discernment.hasFacts ? '${checks.length} checked' : 'unavailable (no facts)'}; '
        'thought ${thought == null ? 'unavailable' : 'recorded'}.');
    var ledgerWrites = 0;
    if (ledger != null) {
      for (final e in fired) {
        if (ledger.record(
            appraisalEvent: e.name,
            whoId: stimulusSpeaker,
            excerpt: userText)) {
          ledgerWrites++;
        }
      }
      if (ledgerWrites > 0) unawaited(ledger.save());
    }
    stages.add(ChainStage('reflect',
        'self-model updated from the real exchange; '
        '$ledgerWrites ledger entr(ies) written'));

    return DannyChainResult(
      reply: revised,
      thought: thought,
      critique: critique,
      stages: stages,
      discernment: checks,
      lieReport: report,
      searchedSources: sources,
      searchFailed: searchFailed,
    );
  }
}
