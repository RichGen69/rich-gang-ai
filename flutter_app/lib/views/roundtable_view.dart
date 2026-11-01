import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/character.dart';
import '../core/persistent_mind.dart';
import '../core/roundtable.dart';
import '../core/voice_engine.dart';
import '../theme/obsidian.dart';
import 'character_ui.dart';
import 'settings_view.dart';

/// The Roundtable — Richard picks the topic and the cast, the
/// agents talk to EACH OTHER, and Richard watches. He can jump in
/// at any time (interject), pause them, or let them start on their
/// own (spontaneous, restraint-gated in roundtable.dart).
///
/// The transcript shows, per turn: who spoke, their REAL derived
/// emotion, their think-step summary when the think pass produced
/// one, and the line itself. When the conversation fails it stops
/// and says why — on this screen, in red, not with a fake line.
class RoundtableView extends StatefulWidget {
  const RoundtableView({super.key});

  @override
  State<RoundtableView> createState() => _RoundtableViewState();
}

class _RoundtableViewState extends State<RoundtableView> {
  final _topic = TextEditingController();
  final _interject = TextEditingController();
  final _scroll = ScrollController();
  static const _defaultCast = {'dan', 'sally', 'capricorn', 'tammy'};
  final Set<String> _selected = {..._defaultCast};
  RoundtableSession? _session;
  bool _voice = false;
  bool _spontaneous = false;

  @override
  void dispose() {
    // The session is app-shared now (see RoundtableSession.shared):
    // detach this view's listener, never dispose the table itself.
    _session?.removeListener(_onSession);
    _topic.dispose();
    _interject.dispose();
    _scroll.dispose();
    super.dispose();
  }

  RoundtableSession _ensureSession() {
    final mind = MindStore.instance;
    if (mind == null) {
      throw StateError('mind store not ready');
    }
    if (_session == null) {
      _session = RoundtableSession.shared(affects: mind.affects);
      _session!.addListener(_onSession);
    }
    return _session!;
  }

  void _onSession() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _start() async {
    final registry = await CharacterRegistry.load();
    if (MindStore.instance == null) await MindStore.boot(registry);
    var cast = [
      for (final id in _selected)
        if (registry.byId(id) != null) registry.byId(id)!,
    ];
    // Age assurance is enforced HERE, in the cast, not just in
    // chat: a 21+ character joins only when the fail-closed
    // AgeAssurance boundary authorises it. This build configures
    // no vendor, so gated characters are removed and the removal
    // is said out loud — never silently replaced.
    final gated = cast.where((c) => c.ageGated).toList();
    var gatedRemoved = false;
    for (final c in gated) {
      if (!await AgeGate.isAuthorised(c)) {
        cast.remove(c);
        gatedRemoved = true;
      }
    }
    if (gatedRemoved && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('21+ characters are locked in this build '
              '(no verified age-assurance provider configured) and '
              'were removed from the cast.')));
    }
    if (cast.length < 2) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Pick at least two agents for a roundtable.')));
      }
      return;
    }
    final session = _ensureSession();
    session.voiceEnabled = _voice;
    session.start(withCast: cast, topic: _topic.text);
    if (_spontaneous) session.armSpontaneous();
    setState(() {});
  }

  Widget _sessionBar(RoundtableSession session) {
    final running = session.status == RoundtableStatus.running;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(session.status.name.toUpperCase(),
              style: TextStyle(
                  color: session.status == RoundtableStatus.failed
                      ? Obsidian.red
                      : Obsidian.goldBright,
                  fontWeight: FontWeight.bold,
                  fontSize: 12)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              session.topic.isEmpty
                  ? 'Topic chosen by the crew'
                  : 'Topic: ${session.topic}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Text('${session.cast.length} at the table',
              style: const TextStyle(fontSize: 11, color: Obsidian.muted)),
        ]),
        Row(children: [
          if (running)
            OutlinedButton(
              onPressed: () => session.pause(),
              child: const Text('Pause'),
            ),
          if (session.status == RoundtableStatus.paused)
            OutlinedButton(
              onPressed: () => session.resume(),
              child: const Text('Resume'),
            ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => session.stop(),
            child: const Text('Stop'),
          ),
          if (session.failure != null)
            Expanded(
              child: Text(session.failure!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Obsidian.red, fontSize: 12)),
            ),
        ]),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final mind = MindStore.instance;
    final session = _session;
    final running = session?.status == RoundtableStatus.running;
    final paused = session?.status == RoundtableStatus.paused;
    return Scaffold(
      appBar: AppBar(
        title: const Text('THE ROUNDTABLE'),
        actions: [
          IconButton(
            tooltip: 'Copy the whole transcript',
            icon: const Icon(Icons.copy_all_outlined),
            onPressed: session == null || session.transcript.isEmpty
                ? null
                : () async {
                    await Clipboard.setData(
                        ClipboardData(text: session.transcriptText()));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Transcript copied — '
                              '${session.transcript.length} turns')));
                    }
                  },
          ),
        ],
      ),
      body: Column(
        children: [
          // ---- Setup (collapses visually once running: it stays
          // scrollable at top; transcript takes the space) ----
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
            child: (running || paused) && session != null
                ? _sessionBar(session)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _topic,
                        decoration: const InputDecoration(
                          labelText:
                              'Topic — or leave empty and the crew picks',
                          hintText: 'What should they talk about?',
                        ),
                      ),
                      const SizedBox(height: 6),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(children: [
                          for (final t in roundtableTopicPresets)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ActionChip(
                                label: Text(t,
                                    style: const TextStyle(fontSize: 11)),
                                onPressed: () =>
                                    setState(() => _topic.text = t),
                              ),
                            ),
                        ]),
                      ),
                      const SizedBox(height: 8),
                      if (mind != null)
                        Row(children: [
                          const Text('CAST',
                              style: TextStyle(
                                  fontSize: 11,
                                  letterSpacing: 1.5,
                                  color: Obsidian.muted)),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: running
                                ? null
                                : () => setState(() => _selected.addAll(mind
                                    .registry.all
                                    .where((c) => c.isConfigured)
                                    .map((c) => c.id))),
                            child: const Text('All configured'),
                          ),
                          TextButton(
                            onPressed: running
                                ? null
                                : () => setState(() {
                                      _selected
                                        ..clear()
                                        ..addAll(_defaultCast);
                                    }),
                            child: const Text('Core four'),
                          ),
                          TextButton(
                            onPressed: running
                                ? null
                                : () => setState(_selected.clear),
                            child: const Text('None'),
                          ),
                          const Spacer(),
                          Text('${_selected.length} picked',
                              style: const TextStyle(
                                  fontSize: 11, color: Obsidian.muted)),
                        ]),
                      if (mind != null)
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            for (final c in mind.registry.all)
                              FilterChip(
                                avatar: CharacterAvatar(def: c, radius: 10),
                                label: Text(c.isRegistryOnly
                                    ? '${c.name} (not configured)'
                                    : c.name),
                                tooltip: c.isRegistryOnly
                                    ? 'Registry only — not configured'
                                    : null,
                                selected: _selected.contains(c.id),
                                onSelected: running || c.isRegistryOnly
                                    ? null
                                    : (v) => setState(() => v
                                        ? _selected.add(c.id)
                                        : _selected.remove(c.id)),
                              ),
                          ],
                        ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(children: [
                          for (final m in RoundtableMode.values)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(m.label),
                                selected: (session?.mode ??
                                        RoundtableMode.freeTalk) ==
                                    m,
                                onSelected: (_) =>
                                    setState(() => _ensureSession().mode = m),
                              ),
                            ),
                        ]),
                      ),
                      Row(children: [
                        _switch('Voice', _voice, (v) => _voice = v),
                        _switch('Spontaneous', _spontaneous, (v) {
                          _spontaneous = v;
                          if (v) _session?.armSpontaneous();
                        }),
                        const Spacer(),
                        if (session != null)
                          Text(
                            session.status.name.toUpperCase(),
                            style: TextStyle(
                              color: session.status == RoundtableStatus.failed
                                  ? Obsidian.red
                                  : Obsidian.goldBright,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                      ]),
                      Row(children: [
                        FilledButton.icon(
                          onPressed: running ? null : _start,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Start — let them talk'),
                        ),
                        const SizedBox(width: 8),
                        if (running && session != null)
                          OutlinedButton(
                            onPressed: () => session.pause(),
                            child: const Text('Pause'),
                          ),
                        if (paused && session != null)
                          OutlinedButton(
                            onPressed: () => session.resume(),
                            child: const Text('Resume'),
                          ),
                        if (session != null &&
                            session.status != RoundtableStatus.idle)
                          TextButton(
                            onPressed: () => session.stop(),
                            child: const Text('Stop'),
                          ),
                      ]),
                      if (session?.topicChosenByAgents == true &&
                          session!.topic.isNotEmpty)
                        Text('Topic chosen by the crew: ${session.topic}',
                            style: const TextStyle(
                                fontSize: 12, color: Obsidian.muted)),
                      if (session?.failure != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(session!.failure!,
                              style: const TextStyle(
                                  color: Obsidian.red, fontSize: 12)),
                        ),
                      if (session?.failure != null)
                        Row(children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                  builder: (_) => const SettingsView()),
                            ),
                            child: const Text('Check Settings'),
                          ),
                          TextButton(
                            onPressed: running ? null : _start,
                            child: const Text('Start again'),
                          ),
                        ]),
                      if (session?.lastVoicePath != null)
                        Text(
                          session!.lastVoicePath == VoicePath.elevenLabs
                              ? 'voice: ElevenLabs'
                              : 'voice: system TTS',
                          style: const TextStyle(
                              fontSize: 11, color: Obsidian.muted),
                        ),
                    ],
                  ),
          ),
          const Divider(height: 1),
          // ---- Watch area ----
          Expanded(
            child: session == null || session.transcript.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Pick a topic and at least two agents, then '
                        'start. They talk to each other — you watch, '
                        'and jump in whenever you want.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Obsidian.muted),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(12),
                    itemCount: session.transcript.length,
                    itemBuilder: (_, i) => _turn(session.transcript[i]),
                  ),
          ),
          // ---- Interject ----
          SafeArea(
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _interject,
                  decoration: const InputDecoration(
                    hintText: 'Jump in — say something to the room',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  onSubmitted: (_) => _sendInterject(),
                ),
              ),
              IconButton(
                onPressed: _sendInterject,
                icon: const Icon(Icons.send, color: Obsidian.goldBright),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _switch(String label, bool value, void Function(bool) set) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Switch(
        value: value,
        onChanged: (v) => setState(() => set(v)),
      ),
      Text(label, style: const TextStyle(fontSize: 12)),
      const SizedBox(width: 8),
    ]);
  }

  void _sendInterject() {
    final session = _session;
    final text = _interject.text.trim();
    if (session == null || text.isEmpty) return;
    _interject.clear();
    session.interject(text);
  }

  Widget _turn(RoundtableTurn t) {
    final accent = t.isUser ? Obsidian.cream : characterAccent(t.speakerId);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Obsidian.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: accent, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(t.speakerName,
                style: TextStyle(color: accent, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            if (!t.isUser)
              Text('feeling ${t.emotion}',
                  style: const TextStyle(fontSize: 11, color: Obsidian.muted)),
            const Spacer(),
            Text(
              '${t.at.hour.toString().padLeft(2, '0')}:'
              '${t.at.minute.toString().padLeft(2, '0')}:'
              '${t.at.second.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 11, color: Obsidian.muted),
            ),
          ]),
          if (t.thoughtSummary != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('💭 ${t.thoughtSummary}',
                  style: const TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: Obsidian.muted)),
            ),
          const SizedBox(height: 4),
          Text(t.text),
        ],
      ),
    );
  }
}
