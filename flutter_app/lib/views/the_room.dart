import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import '../core/character.dart';
import '../core/deep_dream.dart';
import '../core/inference_router.dart';
import '../core/native_bridge.dart';
import '../core/performance_director.dart';
import '../core/persistent_mind.dart';
import '../core/room_rate_controller.dart';
import '../core/secure_keys.dart';
import '../core/settings.dart';
import '../core/time_awareness.dart';
import '../theme/obsidian.dart';
import 'avatar_stage_view.dart';
import 'character_chat_view.dart';
import 'character_ui.dart';
import 'interrogation_view.dart';
import 'roundtable_view.dart';
import 'settings_view.dart';
import 'tier10_hud.dart';

/// THE ROOM — the main screen, rebuilt 2026-10-21 from Richard's
/// own frames as the cinematic hub of Freak Show AI / Rich Gang AI:
///
/// - Hero: his boardroom frame (assets/images/room_boardroom.png,
///   shipped from design_refs/2026-10-21_freak_show_characters/)
///   with the plaque line from that frame: "THE ROOM — Different
///   minds. Same room."
/// - Live strip: daemon state (real), session clock (real elapsed,
///   like the session timer in his frames), character count.
/// - The cast: every character as a card with its REAL current
///   emotion from the affect engine and its interaction count from
///   its self-model. Tap → one-to-one chat; camera icon → HeyGen
///   call screen (from the chat screen's app bar too).
/// - Actions: Roundtable, Deep Dream, Interrogation.
/// - Room controls (frame rate / performance director)
///   kept from the Milestone 7-8 wiring, in their own section.
///
/// Layout is a single scrolling column with a shrink-wrapped grid —
/// nothing is stacked in absolute positions, so cards cannot
/// overlap text at any width.
class TheRoom extends StatefulWidget {
  const TheRoom({super.key, this.crewOnly = false});

  final bool crewOnly;

  @override
  State<TheRoom> createState() => _TheRoomState();
}

class _TheRoomState extends State<TheRoom> {
  final _rate = RoomRateController();
  Map<String, dynamic>? _sceneState;
  CharacterRegistry? _registry;
  Timer? _clock;
  String _dreamResult = '';

  /// Setup checklist state: which service keys are SAVED (never
  /// the key values) and whether local Ollama answered its probe.
  /// "Saved" is stated as saved — a key is only proven when a real
  /// call succeeds, and this card does not pretend otherwise.
  final Map<String, bool> _keysSaved = {};
  bool? _ollamaUp;

  @override
  void initState() {
    super.initState();
    unawaited(_rate.apply(AppSettings.instance.frameRate));
    try {
      final decoded = jsonDecode(NativeBridge().sceneState());
      if (decoded is Map<String, dynamic>) _sceneState = decoded;
    } catch (_) {
      _sceneState = null;
    }
    unawaited(CharacterRegistry.load().then((r) async {
      if (MindStore.instance == null) await MindStore.boot(r);
      // Tier-10 HUD counts come from this real loaded registry and
      // keep configured characters distinct from registry-only ones.
      InferenceRouter.shared.tier10Controller?.updateRegistryCounts(
        total: r.all.length,
        configured: r.all.where((c) => c.isConfigured).length,
        registryOnly: r.all.where((c) => c.isRegistryOnly).length,
      );
      if (mounted) setState(() => _registry = r);
    }));
    // Real session clock.
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    unawaited(_loadSetup());
  }

  Future<void> _loadSetup() async {
    Future<bool> has(Future<String?> v) async {
      final s = await v;
      return s != null && s.isNotEmpty;
    }

    final results = <String, bool>{
      'nvidia': await has(SecureKeys.nvidiaKey),
      'openai': await has(SecureKeys.openAiKey),
      'gemini': await has(SecureKeys.geminiKey),
      'elevenlabs': await has(SecureKeys.elevenLabsKey),
      'heygen': await has(SecureKeys.heyGenKey),
      'liveavatar': await has(SecureKeys.liveAvatarKey),
    };
    final ollama = await InferenceRouter.shared.ollamaReachable();
    if (!mounted) return;
    setState(() {
      _keysSaved.addAll(results);
      _ollamaUp = ollama;
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _setRate(int fps) async {
    AppSettings.instance.update(() => AppSettings.instance.frameRate = fps);
    await _rate.apply(fps);
    if (mounted) setState(() {});
  }

  Future<void> _deepDream() async {
    final mind = MindStore.instance;
    final registry = _registry;
    if (mind == null || registry == null) return;
    setState(() => _dreamResult = 'Dreaming…');
    final report = await DeepDream().dreamAll(
      registry.all,
      affects: mind.affects,
      selves: mind.selves,
    );
    await mind.save();
    if (mounted) setState(() => _dreamResult = report.summary);
  }

  String get _sessionClock {
    final d = DateTime.now().difference(SessionClock.startedAt);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
  }

  /// Setup & health card: what is configured, what is missing,
  /// and one tap to the place that fixes it. Everything here is a
  /// real local check — key PRESENCE from secure storage (values
  /// are never read into the UI) and the router's real Ollama
  /// probe. Nothing is labelled "working" that wasn't exercised.
  Widget _setupCard(AppSettings settings) {
    final provider = settings.cloudProvider;
    final providerKeySaved = switch (provider) {
      'openai' => _keysSaved['openai'] ?? false,
      'gemini' => _keysSaved['gemini'] ?? false,
      _ => _keysSaved['nvidia'] ?? false,
    };
    final brainOk = providerKeySaved || (_ollamaUp ?? false);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
        decoration: BoxDecoration(
          color: Obsidian.panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Obsidian.gold.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('SETUP & HEALTH',
                style: TextStyle(
                    letterSpacing: 2,
                    fontSize: 12,
                    color: Obsidian.gold,
                    fontWeight: FontWeight.bold)),
            _setupRow(
              Icons.psychology_outlined,
              'Brain — ${provider.toUpperCase()}'
              '${providerKeySaved ? ' key saved (unverified)' : ' no key saved'}'
              ' • Ollama ${_ollamaUp == null ? 'checking…' : _ollamaUp! ? 'probe reachable (not a chat proof)' : 'not reachable'}',
              brainOk,
              unverified: providerKeySaved,
            ),
            _setupRow(
              Icons.record_voice_over_outlined,
              (_keysSaved['elevenlabs'] ?? false)
                  ? 'Voices — ElevenLabs key saved (unverified); '
                      'system TTS remains the fallback'
                  : 'Voices — system TTS active (add ElevenLabs for premium)',
              // Voice always works via system TTS; the check marks the
              // working fallback, never the unverified premium key.
              true,
              unverified: _keysSaved['elevenlabs'] ?? false,
            ),
            _setupRow(
              Icons.videocam_outlined,
              'Video calls — LiveAvatar '
              '${(_keysSaved['liveavatar'] ?? false) ? 'key saved (unverified; avatar ID still required per character)' : 'no key'}'
              ' • HeyGen '
              '${(_keysSaved['heygen'] ?? false) ? 'key saved (legacy, unverified)' : 'no key'}',
              (_keysSaved['liveavatar'] ?? false) ||
                  (_keysSaved['heygen'] ?? false),
              unverified: (_keysSaved['liveavatar'] ?? false) ||
                  (_keysSaved['heygen'] ?? false),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const SettingsView()),
                ),
                icon: const Icon(Icons.settings, size: 16),
                label: const Text('Open Settings'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _setupRow(IconData icon, String text, bool ok,
      {bool unverified = false}) {
    // A saved-but-unverified key never gets the check icon: the
    // label already says "(unverified)", and the icon must not
    // contradict it. Unverified rows get a neutral marker instead.
    final IconData mark =
        unverified ? Icons.help_outline : ok ? Icons.check_circle_outline : Icons.error_outline;
    final Color markColor = unverified
        ? Obsidian.muted
        : ok
            ? Obsidian.goldBright
            : Obsidian.red;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(children: [
        Icon(icon, size: 18, color: ok ? Obsidian.gold : Obsidian.muted),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 12)),
        ),
        Icon(mark, size: 16, color: markColor),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    var up = false;
    try {
      up = NativeBridge().isUp;
    } catch (_) {
      up = false;
    }
    final settings = AppSettings.instance;
    final performance = PerformanceDirector.direct(
      sceneState: _sceneState,
      quietHours: AppSettings.inQuietHours,
      killed: settings.ambientKilled,
      reducedMotion: MediaQuery.of(context).disableAnimations,
    );
    final mind = MindStore.instance;
    final registry = _registry;

    final body = ListView(
      padding: EdgeInsets.zero,
      children: [
        // ---------- HERO ----------
        Stack(
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.asset(
                'assets/images/room_boardroom.png',
                fit: BoxFit.cover,
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Obsidian.background.withValues(alpha: 0.92),
                    ],
                  ),
                ),
              ),
            ),
            const Positioned(
              left: 16,
              right: 16,
              bottom: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FREAK SHOW AI',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      color: Obsidian.cream,
                    ),
                  ),
                  Text(
                    'RICH GANG AI — THE ROOM',
                    style: TextStyle(
                      fontSize: 13,
                      letterSpacing: 3,
                      color: Obsidian.goldBright,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Different minds. Same room.',
                    style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Obsidian.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
        // ---------- LIVE STRIP ----------
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _chip(
                up ? '● DAEMON ONLINE' : '● DAEMON OFFLINE',
                up ? Obsidian.goldBright : Obsidian.red,
              ),
              _chip('SESSION $_sessionClock', Obsidian.cream),
              _chip(
                registry == null
                    ? 'CAST LOADING'
                    : '${registry.all.where((c) => c.isConfigured).length} '
                        'CONFIGURED • '
                        '${registry.all.where((c) => c.isRegistryOnly).length} '
                        'REGISTRY ONLY',
                Obsidian.cream,
              ),
              if (mind != null)
                _chip(
                  mind.restored
                      ? 'MIND RESTORED — they remember'
                      : 'MIND FRESH — first run',
                  Obsidian.gold,
                ),
            ],
          ),
        ),
        // ---------- ACTIONS ----------
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const RoundtableView()),
                  ),
                  icon: const Icon(Icons.groups),
                  label: const Text('Roundtable'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _deepDream,
                  icon: const Icon(Icons.bedtime_outlined),
                  label: const Text('Deep Dream'),
                ),
              ),
            ],
          ),
        ),
        // ---------- LABS — PREVIEW SURFACES ----------
        // The two surfaces below are reachable but deliberately NOT
        // flagship actions: the Stage shows a third-party demo model,
        // and Interrogation has no scene until Richard supplies one.
        // Keeping them here (instead of deleting) preserves the work
        // without promoting it.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('LABS — PREVIEW SURFACES',
                  style: TextStyle(
                      letterSpacing: 2,
                      fontSize: 12,
                      color: Obsidian.gold,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text(
                  'Previews only. The Stage shows a demo model, not a '
                  'product character; Interrogation needs scene data '
                  'supplied by the owner.',
                  style: TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => const AvatarStageView()),
                      ),
                      icon: const Icon(Icons.view_in_ar_outlined),
                      label: const Text('3D Stage (Demo Preview)'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => const InterrogationView()),
                      ),
                      icon: const Icon(Icons.search),
                      label: const Text('Interrogate (BYO Scene)'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_dreamResult.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Obsidian.panel,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(_dreamResult, style: const TextStyle(fontSize: 12)),
            ),
          ),
        // ---------- SETUP & HEALTH ----------
        _setupCard(settings),
        // ---------- TIER-10 ROUTING (real router telemetry) ----------
        // The controller belongs to InferenceRouter.shared: cloud
        // successes/failures measured by the router land here. Its
        // latency stays "not measured yet" until a routed call runs.
        if (InferenceRouter.shared.tier10Controller != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child:
                Tier10Hud(controller: InferenceRouter.shared.tier10Controller!),
          ),
        // ---------- CAST ----------
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 18, 16, 6),
          child: Text('THE CAST — CONFIGURED CHARACTERS',
              style: TextStyle(
                  letterSpacing: 2,
                  fontSize: 12,
                  color: Obsidian.gold,
                  fontWeight: FontWeight.bold)),
        ),
        if (registry == null)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Loading the cast…'),
          )
        else if (registry.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No characters loaded (assets/characters.json failed '
                'to load). The room does not invent a cast.'),
          )
        else ...[
          _configuredCastGrid(registry, mind),
          _registryOnlySection(registry),
        ],
        // ---------- ROOM CONTROLS (M7-8 wiring, kept) ----------
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('ROOM CONTROLS',
                  style: TextStyle(
                      letterSpacing: 2,
                      fontSize: 12,
                      color: Obsidian.gold,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Frame rate: ${_rate.target} FPS'),
              Text(performance.summary,
                  style: const TextStyle(color: Obsidian.muted, fontSize: 12)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('60'),
                    selected: AppSettings.instance.frameRate == 60,
                    onSelected: (_) => _setRate(60),
                  ),
                  ChoiceChip(
                    label: const Text('30 Cinematic'),
                    selected: AppSettings.instance.frameRate == 30,
                    onSelected: (_) => _setRate(30),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('THE ROOM'),
        actions: [
          IconButton(
            icon: const Icon(Icons.volume_off),
            tooltip: 'Silence ambient for 24 hours',
            onPressed: () => AppSettings.instance.tripKillSwitch(),
          ),
        ],
      ),
      body: Opacity(
        opacity: performance.opacity,
        child: body,
      ),
    );
  }

  Widget _configuredCastGrid(CharacterRegistry registry, MindStore? mind) {
    final configured = registry.all.where((c) => c.isConfigured).toList();
    if (configured.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No configured characters are available.'),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.76,
      ),
      itemCount: configured.length,
      itemBuilder: (_, i) => _configuredCastCard(configured[i], mind),
    );
  }

  Widget _configuredCastCard(CharacterDef c, MindStore? mind) {
    final emotion = mind?.affects.of(c.id).emotion.emotion ?? '—';
    final talks = mind?.selves.of(c.id).interactions ?? 0;
    return Card(
      color: Obsidian.panel,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          if (c.ageGated && !await AgeGate.ensureAuthorised(context, c)) {
            return;
          }
          if (!mounted) return;
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
                builder: (_) => CharacterChatView(character: c)),
          );
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (c.portrait != null)
              Image.asset(c.portrait!, fit: BoxFit.cover)
            else
              Container(
                color: characterAccent(c.id).withValues(alpha: 0.16),
                alignment: Alignment.topCenter,
                padding: const EdgeInsets.only(top: 28),
                child: CharacterAvatar(def: c, radius: 42),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                  stops: [0.42, 1],
                ),
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(c.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(c.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(fontSize: 11, color: Obsidian.cream)),
                  const SizedBox(height: 5),
                  Row(children: [
                    Icon(Icons.favorite,
                        size: 12, color: characterAccent(c.id)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(emotion,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11)),
                    ),
                    Text('$talks talks',
                        style: const TextStyle(
                            fontSize: 11, color: Obsidian.muted)),
                    if (c.ageGated)
                      const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Text('21+',
                            style: TextStyle(
                                fontSize: 11,
                                color: Obsidian.red,
                                fontWeight: FontWeight.bold)),
                      ),
                  ]),
                  if (c.voice.isUncast)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text('VOICE UNCAST — SYSTEM TTS',
                          style: TextStyle(
                              fontSize: 10,
                              color: Obsidian.goldBright,
                              fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _registryOnlySection(CharacterRegistry registry) {
    final entries = registry.all.where((c) => c.isRegistryOnly).toList();
    if (entries.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: ExpansionTile(
        title: Text('REGISTRY — NOT CONFIGURED (${entries.length})'),
        subtitle: const Text('Registry entries only. They are not presented as '
            'finished characters and do not open a finished-character '
            'chat from The Room.'),
        children: [
          for (final c in entries)
            ListTile(
              leading: CharacterAvatar(def: c, radius: 18),
              title: Text(c.displayName),
              subtitle: Text('${c.title} • REGISTRY ONLY — voice, affect & '
                  'portrait not configured'),
              trailing: c.ageGated
                  ? const Text('21+',
                      style: TextStyle(
                          color: Obsidian.red, fontWeight: FontWeight.bold))
                  : const Icon(Icons.lock_outline, size: 18),
              onTap: () => showDialog<void>(
                context: context,
                builder: (_) => AlertDialog(
                  title: Text(c.displayName),
                  content:
                      const Text('This is a registry-only entry. It has no '
                          'configured portrait, voice casting, or affect '
                          'baseline, so The Room does not present it as '
                          'a finished character.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.bold)),
    );
  }
}
