import 'affect_engine.dart';
import 'character.dart';
import 'inference_router.dart';
import 'self_model.dart';
import 'time_awareness.dart';
import 'web_search.dart';

/// Mode switch from Richard's boardroom frame: the "UNHINGED"
/// tablet. In this build it is a per-conversation instruction set,
/// stated honestly for what it is:
///
/// - ON: the character speaks raw and direct — profanity allowed,
///   no corporate hedging, no PR softening, strong opinions stated
///   as its own. This is what "unfiltered and unhinged" controls
///   inside the app: the character's voice and stance.
/// - It does NOT remove the hosted model's own limits (NVIDIA /
///   Ollama enforce theirs server-side; the app cannot and does not
///   claim to override them), and it never licences invented facts:
///   the no-fabrication rules below apply in BOTH modes.
class UnhingedMode {
  static const onText = 'MODE: UNHINGED. Talk raw, direct, and '
      'unfiltered, in character: strong language is fine, hedges and '
      'corporate softening are not. Say what the character actually '
      'thinks. Still never invent facts, search results, or memories.';
  static const offText = 'MODE: STANDARD. Talk naturally and '
      'directly, in character, without corporate softening.';
}

/// Builds prompts for one character and runs them through the
/// existing InferenceRouter. No canned replies anywhere in this
/// path: if inference fails, the exception propagates and the UI
/// says "inference unavailable", exactly like the chat console.
class CharacterAgent {
  CharacterAgent({
    required this.def,
    required this.affect,
    this.self,
    this.namesById = const {},
    InferenceRouter? router,
    WebSearchService? search,
  })  : router = router ?? InferenceRouter.shared,
        search = search ?? WebSearchService();

  final CharacterDef def;
  final AffectState affect;

  /// Persistent self-model, when the mind store is booted. Null =
  /// the prompt simply omits the self block (first-run before the
  /// store loads) — it never fabricates one.
  final AgentSelf? self;
  final Map<String, String> namesById;
  final InferenceRouter router;
  final WebSearchService search;

  /// The character's system prompt, assembled from the evidenced
  /// definition + its REAL current affect state. Pure — testable.
  String systemPrompt({required bool unhinged}) {
    return [
      'You are ${def.displayName} — ${def.title} — a character in '
          'Freak Show AI / Rich Gang AI, created by Richard Perry '
          'Lambeth Jr. Stay in character at all times.',
      'CORE: ${def.core}',
      'PERSONALITY: ${def.personality}',
      'SPEECH STYLE: ${def.speechStyle}',
      'YOUR CURRENT FEELING (synthetic affect state — let it colour '
          'your word choice, energy, and patience, and refer to it '
          'naturally if asked how you feel): ${affect.moodLine()}',
      if (self != null) self!.promptBlock(namesById),
      SessionClock.context(lastInteractionAt: self?.lastInteractionAt)
          .promptBlock(),
      unhinged ? UnhingedMode.onText : UnhingedMode.offText,
      'RULES: Talk about anything Richard brings up. Use memories '
          'and search results when they are provided below; when they '
          'are not provided, do not claim to remember or to have '
          'looked anything up. If you do not know a current fact, '
          'say so.',
      // Danny's flagship sections (only Danny carries these fields;
      // every other character's prompt is byte-identical to before).
      // His moral core and guardrails ride in EVERY prompt he gets,
      // so the conscience that talks back is present in chat, in
      // the roundtable, and in his LiveAvatar context alike.
      if (def.moralCore != null) 'MORAL CORE: ${def.moralCore}',
      if (def.guardrails != null) 'GUARDRAILS: ${def.guardrails}',
      if (def.selfKnowledge != null) 'WHAT YOU ARE: ${def.selfKnowledge}',
      if (def.toneSpec != null) 'TONE OF VOICE: ${def.toneSpec}',
      if (def.toneByEmotion.isNotEmpty)
        'YOUR TONE RIGHT NOW (emotion: ${affect.emotion.emotion}): '
            '${def.toneByEmotion[affect.emotion.emotion] ?? 'Your defined register: blunt, cocky, dry, unfiltered.'}',
      if (def.gifts.isNotEmpty) 'YOUR GIFTS: ${def.gifts.values.join(' ')}',
      if (def.ageGated)
        'You are an adult companion character in a 21+ category. '
            'The app locks this character unless its separate '
            'age-assurance boundary has authorised access; do not '
            'claim that any age verification has occurred in this '
            'conversation. Be the loyal, romantic, unfiltered '
            'partner described in your core.',
    ].join('\n');
  }

  /// One conversational turn with Richard.
  ///
  /// When [allowSearch] and the message looks like it needs outside
  /// facts, a REAL search runs first and its results (or its empty
  /// state) go into the prompt. The returned [searchedSources] are
  /// the actual URLs used, so the UI can show them — citations are
  /// data, not decoration.
  Future<AgentReply> reply(
    String userText, {
    required bool unhinged,
    bool allowSearch = true,
    String? recalledMemories,
  }) async {
    affect.decay();
    affect.appraiseText(userText);

    List<SearchResult> results = const [];
    String? searchBlock;
    var searchFailed = false;
    if (allowSearch && WebSearchService.needsSearch(userText)) {
      try {
        results = await search.search(userText);
        searchBlock = WebSearchService.formatForPrompt(userText, results);
        affect.appraise(results.isEmpty
            ? AffectEvent.searchFailed
            : AffectEvent.searchFound);
      } on SearchUnavailable {
        searchFailed = true;
        searchBlock = 'WEB SEARCH for "$userText": the search '
            'providers could not be reached. Say the search failed; '
            'do not present remembered facts as search results.';
        affect.appraise(AffectEvent.searchFailed);
      }
    }

    final prompt = [
      systemPrompt(unhinged: unhinged),
      if (recalledMemories != null && recalledMemories.isNotEmpty)
        'MEMORIES RECALLED FROM THIS DEVICE (real stored exchanges):\n'
            '$recalledMemories',
      if (searchBlock != null) searchBlock,
      'Richard: $userText',
      '${def.name}:',
    ].join('\n\n');

    final text = await router.run(InferenceTask.personaDialogue, prompt);
    affect.appraiseText(text);
    // Learning + self, from the real exchange only.
    self?.recordInteraction(DateTime.now());
    self?.observeTopicWords('$userText $text');
    self?.observeCommitments(text);
    return AgentReply(
      text: text,
      emotion: affect.emotion.emotion,
      searchedSources: [for (final r in results) r.url],
      searchFailed: searchFailed,
    );
  }

  /// Prompt for one roundtable turn: this character speaking to the
  /// OTHER agents, not to Richard. Pure — the RoundtableSession owns
  /// inference, timing, and speech.
  String roundtablePrompt({
    required String topic,
    required List<({String speaker, String text})> transcript,
    required bool unhinged,
    String? searchBlock,
    String modeFraming = '',
  }) {
    final history = transcript.map((t) => '${t.speaker}: ${t.text}').join('\n');
    return [
      systemPrompt(unhinged: unhinged),
      'SETTING: You are in The Room with the other agents, talking '
          'to EACH OTHER about the topic below. Richard is watching '
          'and may jump in, but right now you are talking to the '
          'crew, not to him. React to what the last speaker actually '
          'said — agree, argue, riff, ask them something. Address '
          'them by name. Keep it to 2-4 sentences so the conversation '
          'moves. Do not narrate or add stage directions.',
      'TOPIC: $topic',
      if (modeFraming.isNotEmpty) 'MODE: $modeFraming',
      if (searchBlock != null) searchBlock,
      if (history.isNotEmpty) 'CONVERSATION SO FAR:\n$history',
      '${def.name}:',
    ].join('\n\n');
  }
}

class AgentReply {
  const AgentReply({
    required this.text,
    required this.emotion,
    required this.searchedSources,
    required this.searchFailed,
  });
  final String text;

  /// The agent's derived emotion AFTER this turn (real affect state).
  final String emotion;
  final List<String> searchedSources;
  final bool searchFailed;
}
