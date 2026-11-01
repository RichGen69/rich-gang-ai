import 'dart:async';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/age_assurance.dart';
import '../core/call_history.dart';
import '../core/character.dart';
import '../core/character_agent.dart';
import '../core/heygen.dart';
import '../core/liveavatar.dart';
import '../core/persistent_mind.dart';
import '../core/secure_keys.dart';
import '../theme/obsidian.dart';
import 'character_ui.dart';

/// Voice + video call with one character — two real providers.
///
/// HEYGEN (legacy): the flow this screen shipped with. A streaming
/// session is created with Richard's HeyGen key, the character
/// agent generates its lines through the normal in-app inference
/// path, and each line is sent to HeyGen as a speak task — the
/// avatar delivers the CHARACTER's words with the in-app brain
/// behind them. KNOWN STATE (verified 2026-10-21): HeyGen's v1
/// token endpoint answers 404 in pre-flight probes and v1/v2 are
/// slated to retire 2026-10-31, so this path may already be dead
/// on HeyGen's side; the app surfaces that honestly when it fails.
///
/// LIVEAVATAR (current): HeyGen's production realtime platform.
/// FULL mode — LiveAvatar runs the conversation (speech-to-text,
/// model, voice) driven by a Context this app creates from the
/// character's own definition, and the user talks through the
/// microphone. Disclosed trade-off, in the UI: the in-app
/// brain/memory is NOT in a LiveAvatar call; the persona travels
/// via the Context. LiveAvatar is a separate platform/plan/key
/// from HeyGen and its avatar ids are its own.
///
/// Video for both: the avatar's stream is WebRTC via LiveKit;
/// this screen joins the returned room and renders the first
/// remote video track. If none arrives the screen says the call
/// is audio-only so far — it never draws a fake feed. Compile-
/// verified; NOT device-verified (no device in this workspace).
///
/// CALL HISTORY (2026-10-30): ending a call saves it to
/// CallHistory (on-device, SharedPreferences call_history_v1).
/// LiveAvatar lines are fetched once at call end from
/// GET /v1/sessions/{session_id}/transcript; if that fetch
/// fails, the record is session metadata only. There is no
/// history viewer on this screen yet — the record is the
/// stored data, not a displayed list.
class AvatarCallView extends StatefulWidget {
  const AvatarCallView({super.key, required this.character});
  final CharacterDef character;

  @override
  State<AvatarCallView> createState() => _AvatarCallViewState();
}

enum CallProvider { heygen, liveAvatar }

class _AvatarCallViewState extends State<AvatarCallView> {
  final _heygen = HeyGenService();
  final _liveAvatar = LiveAvatarService();
  final _history = CallHistory();
  String? _historyCallId;
  DateTime? _historyStartedAt;
  bool _historyLoaded = false;
  final _avatarId = TextEditingController();
  final _laAvatarId = TextEditingController();
  final _laVoiceId = TextEditingController();
  final _say = TextEditingController();

  // LiveAvatar is the working path (see class docs) — it is the
  // default. HeyGen legacy stays one tap away.
  CallProvider _provider = CallProvider.liveAvatar;
  HeyGenSession? _session;
  LiveAvatarSessionData? _laSession;
  String? _laContextId;
  String _status = 'No session';
  bool _busy = false;
  bool _ageChecked = false;
  bool _ageAuthorised = false;
  bool _liveAvatarKeySaved = false;
  final List<String> _log = [];

  Room? _room;
  EventsListener<RoomEvent>? _listener;
  VideoTrack? _avatarTrack;

  CharacterDef get def => widget.character;
  bool get _live => _session != null || _laSession != null;

  /// Load the on-device history once, before any call starts it,
  /// so a later load cannot overwrite a call started in memory.
  Future<void> _ensureHistoryLoaded() async {
    if (_historyLoaded) return;
    await _history.load();
    _historyLoaded = true;
  }

  /// Start the history record for the call that just went live.
  /// Metadata (agent, start time) is recorded even if the
  /// transcript fetch at call end later fails.
  Future<void> _startHistory() async {
    await _ensureHistoryLoaded();
    _historyStartedAt = DateTime.now();
    _historyCallId =
        await _history.startCall(def.id, at: _historyStartedAt);
  }

  @override
  void initState() {
    super.initState();
    if (def.ageGated) {
      unawaited(AgeAssurance.load().then((assurance) {
        if (!mounted) return;
        setState(() {
          _ageAuthorised = assurance.isAuthorised(def);
          _ageChecked = true;
          if (!_ageAuthorised) {
            _status = 'Locked — no verified age assurance';
          }
        });
      }));
    } else {
      _ageChecked = true;
      _ageAuthorised = true;
    }
    unawaited(_ensureHistoryLoaded());
    unawaited(SecureKeys.liveAvatarKey.then((key) {
      if (mounted) {
        setState(() => _liveAvatarKeySaved = (key ?? '').isNotEmpty);
      }
    }));
    unawaited(SharedPreferences.getInstance().then((p) {
      if (!mounted) return;
      setState(() {
        _avatarId.text = p.getString(HeyGenAvatars.prefsKeyFor(def.id)) ?? '';
        _laAvatarId.text =
            p.getString(LiveAvatarConfig.avatarKeyFor(def.id)) ?? '';
        _laVoiceId.text =
            p.getString(LiveAvatarConfig.voiceKeyFor(def.id)) ?? '';
        _laContextId = p.getString(LiveAvatarConfig.contextKeyFor(def.id));
      });
    }));
  }

  @override
  void dispose() {
    final s = _session;
    if (s != null) unawaited(_heygen.stop(s));
    final la = _laSession;
    if (la != null) unawaited(_liveAvatar.stopSession(la.sessionId));
    unawaited(_listener?.dispose() ?? Future<void>.value());
    unawaited(_room?.disconnect() ?? Future<void>.value());
    unawaited(_room?.dispose() ?? Future<void>.value());
    _avatarId.dispose();
    _laAvatarId.dispose();
    _laVoiceId.dispose();
    _say.dispose();
    super.dispose();
  }

  /// Join a LiveKit room and grab the avatar's video track when it
  /// subscribes. [publishMic] is for LiveAvatar FULL mode, where
  /// the user's voice IS the input; the legacy HeyGen flow is
  /// text-driven, so its mic stays off.
  Future<void> _joinRoom(String url, String token,
      {required bool publishMic}) async {
    try {
      final room = Room(
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
        ),
      );
      _room = room;
      _listener = room.createListener();
      _listener!.on<TrackSubscribedEvent>((event) {
        final track = event.track;
        if (track is VideoTrack && mounted) {
          setState(() => _avatarTrack = track);
        }
      });
      await room.connect(url, token);
      if (publishMic) {
        await room.localParticipant?.setMicrophoneEnabled(true);
      }
      // The avatar may already be publishing when we join.
      for (final p in room.remoteParticipants.values) {
        for (final pub in p.videoTrackPublications) {
          final t = pub.track;
          if (t is VideoTrack && mounted) {
            setState(() => _avatarTrack = t);
          }
        }
      }
      setState(() => _log.add('Joined LiveKit room for video.'));
    } catch (e) {
      setState(() => _log.add('Video join failed ($e) — call continues.'));
    }
  }

  Future<void> _saveHeyGenId() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(HeyGenAvatars.prefsKeyFor(def.id), _avatarId.text.trim());
  }

  Future<void> _saveLiveAvatarIds() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
        LiveAvatarConfig.avatarKeyFor(def.id), _laAvatarId.text.trim());
    await p.setString(
        LiveAvatarConfig.voiceKeyFor(def.id), _laVoiceId.text.trim());
  }

  bool get _liveAvatarPreflightReady =>
      _liveAvatarKeySaved && _laAvatarId.text.trim().isNotEmpty;

  Widget _preflightCard() {
    if (_provider == CallProvider.heygen) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.block_outlined),
          title: Text('Preflight — HeyGen legacy disabled'),
          subtitle: Text('This provider path has not passed the '
              'flagship live-call proof, so it is disabled in this '
              'build. Use LiveAvatar.'),
        ),
      );
    }
    Widget row(String label, bool ok) => Row(children: [
          Icon(ok ? Icons.check_circle_outline : Icons.error_outline,
              size: 18, color: ok ? Obsidian.goldBright : Obsidian.red),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
        ]);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('PREFLIGHT',
                style: TextStyle(
                    letterSpacing: 1.5,
                    fontSize: 11,
                    color: Obsidian.gold,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            row(
                _liveAvatarKeySaved
                    ? 'LiveAvatar key saved (unverified)'
                    : 'LiveAvatar key missing — add it in Settings',
                _liveAvatarKeySaved),
            const SizedBox(height: 6),
            row(
                _laAvatarId.text.trim().isNotEmpty
                    ? 'LiveAvatar avatar ID entered for ${def.name}'
                    : 'LiveAvatar avatar ID missing — enter it under '
                        'Advanced & IDs below',
                _laAvatarId.text.trim().isNotEmpty),
            const SizedBox(height: 6),
            row(
                'Brain disclosure: LiveAvatar FULL mode runs the '
                'conversation; the in-app brain/memory is not in '
                'this call',
                true),
          ],
        ),
      ),
    );
  }

  Future<void> _start() async {
    if (def.ageGated && !_ageAuthorised) {
      setState(() => _status = 'Locked — no verified age assurance');
      return;
    }
    if (_provider == CallProvider.liveAvatar && !_liveAvatarPreflightReady) {
      setState(() => _status = _liveAvatarKeySaved
          ? 'Preflight failed: LiveAvatar avatar ID is missing'
          : 'Preflight failed: LiveAvatar key is missing');
      return;
    }
    if (_provider == CallProvider.heygen) {
      await _startHeyGen();
    } else {
      await _startLiveAvatar();
    }
  }

  Future<void> _startHeyGen() async {
    setState(() {
      _busy = true;
      _status = 'Creating HeyGen session…';
    });
    try {
      await _saveHeyGenId();
      final session = await _heygen.startSession(
        avatarName: _avatarId.text,
      );
      await _startHistory();
      setState(() {
        _session = session;
        _status = 'Session live (HeyGen)';
        _log.add('Session ${session.sessionId} started. '
            'LiveKit room: ${session.liveKitUrl}');
      });
      await _joinRoom(session.liveKitUrl, session.accessToken,
          publishMic: false);
      // Opening line from the character itself.
      await _agentSpeaks('The call just started. Greet Richard.');
    } catch (e) {
      if (mounted) setState(() => _status = 'Could not start: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startLiveAvatar() async {
    setState(() {
      _busy = true;
      _status = 'Preparing LiveAvatar…';
    });
    try {
      await _saveLiveAvatarIds();
      final avatarId = _laAvatarId.text.trim();
      if (avatarId.isEmpty) {
        throw LiveAvatarException(
            'paste this character\'s LiveAvatar avatar id first '
            '(from the LiveAvatar dashboard — HeyGen ids do not '
            'work on LiveAvatar)');
      }
      // One Context per character, created from its own
      // definition on first use and reused after that.
      var contextId = _laContextId;
      if (contextId == null || contextId.isEmpty) {
        setState(() => _status = 'Creating ${def.name}\'s context…');
        contextId = await _liveAvatar.createContext(
          name: 'Rich Gang AI — ${def.displayName}',
          prompt: LiveAvatarService.contextPromptFor(def),
          openingText: LiveAvatarService.openingTextFor(def),
        );
        final p = await SharedPreferences.getInstance();
        await p.setString(LiveAvatarConfig.contextKeyFor(def.id), contextId);
        _laContextId = contextId;
        _log.add('Context created for ${def.name}: $contextId');
      }
      setState(() => _status = 'Minting LiveAvatar session…');
      final token = await _liveAvatar.createSessionToken(
        avatarId: avatarId,
        contextId: contextId,
        voiceId: _laVoiceId.text,
      );
      final session = await _liveAvatar.startSession(token.sessionToken);
      if (!mounted) return;
      await _startHistory();
      setState(() {
        _laSession = session;
        _status = 'Session live (LiveAvatar) — just talk';
        _log.add('LiveAvatar session ${session.sessionId} started.');
      });
      await _joinRoom(session.liveKitUrl, session.liveKitClientToken,
          publishMic: true);
    } catch (e) {
      if (mounted) setState(() => _status = 'Could not start: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Legacy HeyGen only: the character agent writes a line through
  /// the in-app inference path and HeyGen's avatar speaks it.
  Future<void> _agentSpeaks(String stimulus) async {
    final session = _session;
    final mind = MindStore.instance;
    if (session == null || mind == null) return;
    try {
      final agent = CharacterAgent(
        def: def,
        affect: mind.affects.of(def.id),
        self: mind.selves.of(def.id),
        namesById: mind.selves.namesById,
      );
      final reply = await agent.reply(stimulus, unhinged: true);
      await _heygen.speak(session, reply.text);
      final historyCallId = _historyCallId;
      if (historyCallId != null) {
        await _history.addLine(
            historyCallId, def.displayName, reply.text);
      }
      setState(() => _log.add('${def.name}: ${reply.text}'));
    } catch (e) {
      setState(() => _log.add('Call line failed: $e'));
    }
  }

  Future<void> _end() async {
    final s = _session;
    if (s != null) await _heygen.stop(s);
    final la = _laSession;
    if (la != null) await _liveAvatar.stopSession(la.sessionId);
    await _room?.disconnect();
    await _room?.dispose();
    _room = null;
    // Capture the history ids before clearing them, then finish
    // the record AFTER the provider session stops: LiveAvatar
    // lines come from one post-call transcript fetch, and a
    // failed fetch leaves metadata only — never invented lines.
    final historyCallId = _historyCallId;
    final historyStartedAt = _historyStartedAt;
    final laSessionId = la?.sessionId;
    _historyCallId = null;
    _historyStartedAt = null;
    setState(() {
      _session = null;
      _laSession = null;
      _avatarTrack = null;
      _status = 'Session ended';
    });
    if (historyCallId != null) {
      if (laSessionId != null) {
        try {
          final lines = await _liveAvatar.fetchTranscript(
            laSessionId,
            sessionStartedAt: historyStartedAt,
          );
          for (final line in lines) {
            final speaker =
                line.role == 'user' ? 'Richard' : def.displayName;
            await _history.addLine(
                historyCallId, speaker, line.text, at: line.at);
          }
        } catch (e) {
          if (mounted) {
            setState(() => _log.add('Transcript fetch failed ($e) — '
                'call history saved without lines.'));
          }
        }
      }
      await _history.endCall(historyCallId);
      final saved = _history.byId(historyCallId);
      if (mounted) {
        setState(() => _log.add(
            'Call saved to history (${saved?.lines.length ?? 0} lines).'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (def.ageGated && (!_ageChecked || !_ageAuthorised)) {
      return Scaffold(
        appBar: AppBar(title: Text('Call ${def.displayName}')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _ageChecked
                  ? '21+ character locked — no verified age-assurance '
                      'provider is configured in this build.'
                  : 'Checking age assurance…',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    final live = _live;
    return Scaffold(
      appBar: AppBar(title: Text('Call ${def.displayName}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            CharacterAvatar(def: def, radius: 30),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(def.displayName,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(def.title,
                      style: const TextStyle(color: Obsidian.muted)),
                  Text(_status,
                      style: TextStyle(
                          color: live ? Obsidian.goldBright : Obsidian.muted)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 14),
          SegmentedButton<CallProvider>(
            segments: const [
              ButtonSegment(
                  value: CallProvider.liveAvatar, label: Text('LiveAvatar')),
              ButtonSegment(
                  value: CallProvider.heygen,
                  label: Text('HeyGen (disabled)'),
                  enabled: false),
            ],
            selected: {_provider},
            onSelectionChanged:
                live ? null : (v) => setState(() => _provider = v.first),
          ),
          const SizedBox(height: 8),
          Text(
            _provider == CallProvider.liveAvatar
                ? 'LiveAvatar runs the conversation on its side '
                    '(FULL mode) from a context built from '
                    '${def.name}\'s own character definition — '
                    'talk with your voice. The in-app brain and '
                    'memory are not part of this call.'
                : 'HeyGen legacy: ${def.name}\'s lines come from '
                    'the in-app agent and the avatar speaks them. '
                    'HeyGen\'s v1 endpoint is slated to retire '
                    '2026-10-31 and currently fails pre-flight '
                    'checks — LiveAvatar is the working path.',
            style: const TextStyle(fontSize: 12, color: Obsidian.muted),
          ),
          const SizedBox(height: 16),
          // ---- Avatar video (real LiveKit track, or honest state)
          Container(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: _avatarTrack != null
                  ? VideoTrackRenderer(_avatarTrack!)
                  : Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          live
                              ? 'Session live — waiting for the '
                                  'avatar\'s video track… If none '
                                  'arrives, this call is audio-only.'
                              : 'The avatar\'s live video appears '
                                  'here when the call starts.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 12, color: Obsidian.muted),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          _preflightCard(),
          const SizedBox(height: 12),
          ExpansionTile(
            title: const Text('Advanced & IDs'),
            subtitle:
                const Text('Per-character provider IDs and saved context. '
                    'Not part of the ordinary call flow.'),
            children: [
              if (_provider == CallProvider.heygen) ...[
                TextField(
                  controller: _avatarId,
                  decoration: const InputDecoration(
                    labelText:
                        'HeyGen Interactive Avatar id for this character',
                    hintText: 'From labs.heygen.com/interactive-avatar',
                  ),
                ),
              ] else ...[
                TextField(
                  controller: _laAvatarId,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'LiveAvatar avatar id for this character',
                    hintText: 'UUID from the LiveAvatar dashboard',
                    helperText: 'LiveAvatar avatars are separate from HeyGen '
                        'avatars — ids do not carry over.',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _laVoiceId,
                  decoration: const InputDecoration(
                    labelText: 'LiveAvatar voice id (optional)',
                    hintText: 'Blank = the avatar\'s default voice',
                  ),
                ),
                if (_laContextId != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('context: $_laContextId',
                        style: const TextStyle(
                            fontSize: 11, color: Obsidian.muted)),
                  ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(children: [
            FilledButton.icon(
              onPressed: _busy ||
                      live ||
                      (_provider == CallProvider.liveAvatar &&
                          !_liveAvatarPreflightReady)
                  ? null
                  : _start,
              icon: const Icon(Icons.videocam),
              label: const Text('Start call'),
            ),
            const SizedBox(width: 10),
            if (live)
              OutlinedButton.icon(
                onPressed: _end,
                icon: const Icon(Icons.call_end),
                label: const Text('End call'),
              ),
          ]),
          if (live && _provider == CallProvider.heygen) ...[
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _say,
                  decoration:
                      InputDecoration(hintText: 'Say something to ${def.name}'),
                  onSubmitted: (_) => _sendLine(),
                ),
              ),
              IconButton(
                onPressed: _sendLine,
                icon: const Icon(Icons.send, color: Obsidian.goldBright),
              ),
            ]),
          ],
          if (live && _provider == CallProvider.liveAvatar)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Text(
                'Your microphone is live — talk, and the avatar '
                'answers in character. End the call to hang up.',
                style: TextStyle(fontSize: 13, color: Obsidian.gold),
              ),
            ),
          const SizedBox(height: 16),
          ExpansionTile(
            title: const Text('Diagnostics'),
            subtitle: const Text('Raw provider/session log'),
            children: [
              if (_log.isEmpty)
                const ListTile(title: Text('No session log yet.'))
              else
                for (final line in _log.reversed.take(20))
                  ListTile(
                    dense: true,
                    title: Text(line, style: const TextStyle(fontSize: 13)),
                  ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _sendLine() async {
    final text = _say.text.trim();
    if (text.isEmpty) return;
    _say.clear();
    final historyCallId = _historyCallId;
    if (historyCallId != null) {
      await _history.addLine(historyCallId, 'Richard', text);
    }
    setState(() => _log.add('Richard: $text'));
    await _agentSpeaks(text);
  }
}
