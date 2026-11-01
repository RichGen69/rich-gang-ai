import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/age_assurance.dart';
import '../core/character.dart';
import '../core/character_agent.dart';
import '../core/danny_chain.dart';
import '../core/danny_ledger.dart';
import '../core/danny_upgrades.dart';
import '../core/hands_free.dart';
import '../core/native_bridge.dart';
import '../core/persistent_mind.dart';
import '../core/thinking.dart';
import '../core/time_awareness.dart';
import '../core/voice_engine.dart';
import '../theme/obsidian.dart';
import 'avatar_call_view.dart';
import 'avatar_stage_view.dart';
import 'character_ui.dart';
import 'settings_view.dart';

class _Msg {
  _Msg(this.fromUser, this.text,
      {this.emotion,
      this.thought,
      this.sources = const [],
      this.critique,
      this.chainTrace});
  final bool fromUser;
  final String text;
  final String? emotion;
  final String? thought;
  final List<String> sources;
  final String? critique;

  /// Danny's flagship chain trace (stage-by-stage record), shown
  /// under his replies; null for every other character.
  final String? chainTrace;
}

/// One-to-one character chat — messages, voice, hands-free, deep
/// reasoning, and the agent's chain of thought, in one screen.
///
/// Everything on this screen is a real path:
/// - reply: CharacterAgent (character + affect + self + real-time +
///   recalled memories + live search) via InferenceRouter;
/// - deep: DeepReasoner (draft → critique → revise), critique
///   viewable under the answer;
/// - think: ThoughtStep shown above the reply it steered;
/// - voice: VoiceEngine speaks the reply in the character's cast
///   voice and reports which path actually spoke;
/// - hands-free: HandsFreeController loop (device recogniser);
/// - memory: the real exchange is stored via rga_remember and
///   recalled via rga_recall (lexical) on later turns.
class CharacterChatView extends StatefulWidget {
  const CharacterChatView({super.key, required this.character});
  final CharacterDef character;

  @override
  State<CharacterChatView> createState() => _CharacterChatViewState();
}

class _CharacterChatViewState extends State<CharacterChatView> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <_Msg>[];
  bool _busy = false;
  bool _unhinged = true;
  bool _voiceOn = false;
  bool _thinkOn = true;
  bool _deepOn = false;
  bool _ageChecked = false;
  bool _ageAuthorised = false;

  /// Last provider failure, shown as an error card (never as a
  /// plain system line) with Retry / Open Settings actions.
  /// Ollama fallback is NOT offered here: the router falls back
  /// on its own, and there is no user-chosen force-Ollama action.
  String? _lastError;
  String? _lastFailedText;
  VoicePath? _lastVoicePath;

  final _handsFree = HandsFreeController();
  final _voice = VoiceEngine();
  MindStore? get _mind => MindStore.instance;

  CharacterDef get def => widget.character;

  @override
  void initState() {
    super.initState();
    _handsFree.onFinal = (heard) => _send(heard);
    _handsFree.speakReply = (_) async {
      // Reply was already spoken inside _send when voice is on; in
      // hands-free the voice is forced on for the loop to make sense.
    };
    if (def.ageGated) {
      // Fail closed: a direct route to a 21+ chat renders a locked
      // screen until the AgeAssurance boundary authorises it. This
      // build has no vendor configured, so it stays locked.
      unawaited(AgeAssurance.load().then((assurance) {
        if (!mounted) return;
        setState(() {
          _ageAuthorised = assurance.isAuthorised(def);
          _ageChecked = true;
        });
      }));
    } else {
      _ageChecked = true;
      _ageAuthorised = true;
    }
  }

  @override
  void dispose() {
    unawaited(_voice.stop());
    _handsFree.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String _recallBlock(String query) {
    try {
      final raw = NativeBridge().recall(query, k: 3);
      final doc = jsonDecode(raw) as Map<String, dynamic>;
      final results = doc['results'];
      if (results is! List || results.isEmpty) return '';
      return [
        for (final r in results)
          if (r is Map<String, dynamic> && r['payload'] is String)
            r['payload'] as String,
      ].join('\n');
    } catch (_) {
      return '';
    }
  }

  Future<void> _send([String? given]) async {
    final text = (given ?? _input.text).trim();
    if (text.isEmpty || _busy) return;
    if (def.ageGated) {
      // The send path checks the boundary itself; a composer or a
      // hands-free callback can never bypass the view-level lock.
      final assurance = await AgeAssurance.load();
      final authorised = assurance.isAuthorised(def);
      if (mounted) {
        setState(() {
          _ageAuthorised = authorised;
          _ageChecked = true;
        });
      }
      if (!authorised) return;
    }
    _input.clear();
    setState(() {
      _messages.add(_Msg(true, text));
      _busy = true;
      _lastError = null;
    });
    _jump();

    final mind = _mind;
    if (mind == null) {
      setState(() {
        _lastError = 'The character mind is still loading — no reply '
            'was generated and nothing was stored.';
        _lastFailedText = text;
        _busy = false;
      });
      return;
    }
    final affect = mind.affects.of(def.id);
    final self = mind.selves.of(def.id);
    final agent = CharacterAgent(
      def: def,
      affect: affect,
      self: self,
      namesById: mind.selves.namesById,
    );

    String? thoughtSummary;
    String? chainTrace;
    try {
      String reply;
      String? critique;
      List<String> sources = const [];
      if (def.id != 'danny' && _thinkOn) {
        final thought = await Thinker().think(
          def: def,
          affect: affect,
          self: self,
          namesById: mind.selves.namesById,
          time: SessionClock.context(lastInteractionAt: self.lastInteractionAt),
          context: 'One-to-one chat with Richard',
          stimulus: text,
        );
        thoughtSummary = thought?.summary;
      }
      if (def.id == 'danny') {
        // DANNY'S FLAGSHIP CHAIN — mandatory, not a toggle: his
        // DOUBLE-CHECK gift means draft -> critique -> revise runs
        // on every reply, short or long, with the discernment
        // pass and the reflection stage built in (danny_chain.dart).
        final chain = await DannyChain().run(
          agent: agent,
          self: self,
          namesById: mind.selves.namesById,
          userText: text,
          unhinged: _unhinged,
          recalledMemories: _recallBlock(text),
          ledger: DannyLedger.instance,
          upgrades: DannyUpgradeController.instance,
        );
        reply = chain.reply;
        critique = chain.critique;
        thoughtSummary = chain.thought?.summary;
        sources = chain.searchedSources;
        chainTrace = chain.trace;
      } else if (_deepOn) {
        final deep = await DeepReasoner().reason(
          systemPrompt: agent.systemPrompt(unhinged: _unhinged),
          question: text,
        );
        reply = deep.answer;
        critique = deep.critique;
        self.recordInteraction(DateTime.now());
        self.observeTopicWords('$text $reply');
      } else {
        final r = await agent.reply(
          text,
          unhinged: _unhinged,
          recalledMemories: _recallBlock(text),
        );
        reply = r.text;
        sources = r.searchedSources;
      }

      // Store the real exchange; a failed store is ignored silently
      // ONLY because the reply itself already happened — the chat
      // console's discipline (never store failed exchanges) holds:
      // nothing reaches here unless inference produced a reply.
      try {
        NativeBridge().remember(
          'chat-${def.id}-${DateTime.now().microsecondsSinceEpoch}',
          '${def.name} on "$text": $reply',
        );
      } catch (_) {}
      await mind.save();

      if (!mounted) return;
      setState(() {
        _messages.add(_Msg(false, reply,
            emotion: affect.emotion.emotion,
            thought: thoughtSummary,
            sources: sources,
            critique: critique,
            chainTrace: chainTrace));
        _busy = false;
        _lastError = null;
      });
      _jump();

      if (_voiceOn || _handsFree.active) {
        final path = await _voice.speak(def, affect.current, reply);
        if (mounted) setState(() => _lastVoicePath = path);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _lastError = 'Inference unavailable — no reply was generated '
            'and nothing was stored. ($e)';
        _lastFailedText = text;
        _busy = false;
      });
    }
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear this chat?'),
        content:
            const Text('This clears the messages on this screen only. What '
                'the agents stored in memory stays stored.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Clear')),
        ],
      ),
    );
    if (ok == true && mounted) setState(_messages.clear);
  }

  /// Long-press actions on a message: copy it, hear an agent line
  /// spoken, or pull one of Richard's lines back into the composer
  /// to edit and resend.
  void _messageActions(_Msg m) {
    unawaited(showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('Copy text'),
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: m.text));
                if (!mounted) return;
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('Copied')));
              },
            ),
            if (!m.fromUser)
              ListTile(
                leading: const Icon(Icons.volume_up_outlined),
                title: Text('Hear ${def.name} say it'),
                onTap: () async {
                  Navigator.of(context).pop();
                  final mind = _mind;
                  if (mind == null) return;
                  final path = await _voice.speak(
                      def, mind.affects.of(def.id).current, m.text);
                  if (mounted) {
                    setState(() => _lastVoicePath = path);
                  }
                },
              ),
            if (m.fromUser)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit & resend'),
                onTap: () {
                  Navigator.of(context).pop();
                  setState(() {
                    _input.text = m.text;
                    _input.selection = TextSelection.fromPosition(
                        TextPosition(offset: _input.text.length));
                  });
                },
              ),
          ],
        ),
      ),
    ));
  }

  void _jump() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _toggleHandsFree() async {
    if (_handsFree.active) {
      await _handsFree.stop();
      await _voice.stop();
      setState(() {});
      return;
    }
    final ok = await _handsFree.start();
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_handsFree.error ?? 'Hands-free unavailable')));
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (def.ageGated && (!_ageChecked || !_ageAuthorised)) {
      return Scaffold(
        appBar: AppBar(title: Text(def.displayName)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _ageChecked
                  ? '21+ character locked — no verified age-assurance '
                      'provider is configured in this build. A '
                      'self-confirmation is not verification.'
                  : 'Checking age assurance…',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    final accent = characterAccent(def.id);
    final mind = _mind;
    // No mind yet means the character is waking, never a
    // permanent "loading" emotion presented as a feeling.
    final emotionLabel = mind == null
        ? 'waking up'
        : 'feeling ${mind.affects.of(def.id).emotion.emotion}';
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: Row(children: [
          // Portrait-forward header: the character's own portrait
          // leads, at a size that reads as a face rather than an icon.
          // Monogram fallback lives inside CharacterAvatar for any
          // entry without a portrait — never a stock face.
          CharacterAvatar(def: def, radius: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(def.displayName,
                    style: const TextStyle(fontSize: 17),
                    overflow: TextOverflow.ellipsis),
                Text('${def.title} • $emotionLabel',
                    style:
                        const TextStyle(fontSize: 11, color: Obsidian.muted),
                    overflow: TextOverflow.ellipsis),
                Text(
                    def.voice.isUncast
                        ? 'VOICE UNCAST — SYSTEM TTS'
                        : 'Voice cast',
                    style: const TextStyle(
                        fontSize: 10,
                        color: Obsidian.goldBright,
                        fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ]),
        actions: [
          IconButton(
            tooltip: '3D stage for this agent',
            icon: const Icon(Icons.view_in_ar_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                  builder: (_) => AvatarStageView(initialCharacterId: def.id)),
            ),
          ),
          IconButton(
            tooltip: 'Video / voice call',
            icon: const Icon(Icons.videocam_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                  builder: (_) => AvatarCallView(character: def)),
            ),
          ),
          IconButton(
            tooltip: 'Clear this chat view (memory is not touched)',
            icon: const Icon(Icons.delete_outline),
            onPressed: _messages.isEmpty ? null : _confirmClear,
          ),
          IconButton(
            tooltip: _handsFree.active
                ? 'Stop hands-free'
                : 'Hands-free chat (speak and listen)',
            icon: Icon(_handsFree.active
                ? Icons.hearing
                : Icons.hearing_disabled_outlined),
            color: _handsFree.active ? accent : null,
            onPressed: _toggleHandsFree,
          ),
        ],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(children: [
              _toggle('UNHINGED', _unhinged, (v) => _unhinged = v),
              _toggle('Think', _thinkOn, (v) => _thinkOn = v),
              _toggle('Deep reasoning', _deepOn, (v) => _deepOn = v),
              _toggle('Voice', _voiceOn, (v) => _voiceOn = v),
              if (_lastVoicePath != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    _lastVoicePath == VoicePath.elevenLabs
                        ? 'voice: ElevenLabs'
                        : 'voice: system TTS',
                    style: const TextStyle(fontSize: 11, color: Obsidian.muted),
                  ),
                ),
              if (_handsFree.active)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text('hands-free: ${_handsFree.state.name}',
                      style: TextStyle(fontSize: 11, color: accent)),
                ),
            ]),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (_, i) => _bubble(_messages[i], accent),
            ),
          ),
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          if (_lastError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Card(
                color: Obsidian.panel,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_lastError!,
                          style: const TextStyle(
                              fontSize: 13, color: Obsidian.red)),
                      const SizedBox(height: 8),
                      Row(children: [
                        TextButton.icon(
                          onPressed: _lastFailedText == null
                              ? null
                              : () => _send(_lastFailedText),
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Retry'),
                        ),
                        TextButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                                builder: (_) => const SettingsView()),
                          ),
                          icon: const Icon(Icons.settings, size: 16),
                          label: const Text('Open Settings'),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
            ),
          SafeArea(
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  decoration: InputDecoration(
                    hintText: 'Message ${def.name} — talk about anything',
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              IconButton(
                onPressed: _busy ? null : () => _send(),
                icon: Icon(Icons.send, color: accent),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _toggle(String label, bool value, void Function(bool) set) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label, style: const TextStyle(fontSize: 11)),
        selected: value,
        onSelected: (v) => setState(() => set(v)),
      ),
    );
  }

  Widget _bubble(_Msg m, Color accent) {
    return Align(
      alignment: m.fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _messageActions(m),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(12),
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.85),
          decoration: BoxDecoration(
            color: m.fromUser ? accent.withValues(alpha: 0.22) : Obsidian.panel,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!m.fromUser && m.thought != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('💭 ${m.thought}',
                      style: const TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: Obsidian.muted)),
                ),
              Text(m.text),
              if (!m.fromUser && m.emotion != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('feeling: ${m.emotion}',
                      style:
                          const TextStyle(fontSize: 11, color: Obsidian.muted)),
                ),
              if (m.sources.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('sources: ${m.sources.join('  ')}',
                      style:
                          const TextStyle(fontSize: 11, color: Obsidian.gold)),
                ),
              if (m.critique != null)
                ExpansionTile(
                  title: const Text('How deep reasoning improved this',
                      style: TextStyle(fontSize: 12)),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(m.critique!,
                          style: const TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              if (m.chainTrace != null)
                ExpansionTile(
                  title: const Text(
                      'Danny\'s chain — perceive to reflect, checked twice',
                      style: TextStyle(fontSize: 12)),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(m.chainTrace!,
                          style: const TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
