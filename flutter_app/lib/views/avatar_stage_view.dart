import 'dart:async';
import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/age_assurance.dart';
import '../core/avatar_stage.dart';
import '../core/character.dart';
import '../core/persistent_mind.dart';
import '../core/voice_engine.dart';
import '../theme/obsidian.dart';
import 'character_ui.dart';

/// THE STAGE — 3D avatars for the character agents.
///
/// Rendering is real glTF (model_viewer_plus / Google model-viewer)
/// and the animation is driven by the StageDirector from the
/// focused agent's REAL affect state and speaking state.
///
/// Asset honesty, in the open on this screen:
/// - No 3D models OF Richard's characters exist yet, so every
///   character starts in a labelled no-model state with the two
///   ways to give it one (bundled config, or a URL/path override
///   saved on-device).
/// - The DEMO robot bundled with the app (RobotExpressive, three.js
///   examples) proves the pipeline end-to-end and is labelled as a
///   demo everywhere — it is never presented as a character.
/// - Speaking-time animation uses an estimated utterance duration
///   (TTS APIs don't report a unified "finished" moment); the
///   estimate only affects how long the talk clip plays.
class AvatarStageView extends StatefulWidget {
  const AvatarStageView({super.key, this.initialCharacterId});
  final String? initialCharacterId;

  @override
  State<AvatarStageView> createState() => _AvatarStageViewState();
}

class _AvatarStageViewState extends State<AvatarStageView> {
  CharacterDef? _focused;
  bool _demoMode = false;
  String? _overrideSrc;
  String? _clip;
  bool _speaking = false;
  bool _followEmotion = true;
  bool _ageChecked = true;
  bool _ageAuthorised = true;
  final _line = TextEditingController();
  final _srcField = TextEditingController();
  final _voice = VoiceEngine();
  Timer? _speakTimer;

  MindStore? get _mind => MindStore.instance;

  /// The registry this view loaded itself — the character rail
  /// must render from it, not from MindStore alone: if the mind
  /// boot failed, the rail used to degrade to just the demo robot
  /// even though the cast had loaded fine.
  CharacterRegistry? _registry;

  @override
  void initState() {
    super.initState();
    unawaited(_init());
  }

  Future<void> _init() async {
    final registry = await CharacterRegistry.load();
    _registry = registry;
    if (_mind == null && !registry.isEmpty) {
      await MindStore.boot(registry);
    }
    if (!mounted) return;
    setState(() {
      _focused = registry.byId(widget.initialCharacterId ?? '') ??
          (registry.all.isNotEmpty ? registry.all.first : null);
    });
    await _loadOverride();
    _refreshClip();
    await _refreshFocusedAge();
  }

  Future<void> _refreshFocusedAge() async {
    final f = _focused;
    if (f == null || !f.ageGated) {
      if (mounted) {
        setState(() {
          _ageChecked = true;
          _ageAuthorised = true;
        });
      }
      return;
    }
    if (mounted) setState(() => _ageChecked = false);
    final assurance = await AgeAssurance.load();
    if (!mounted) return;
    setState(() {
      _ageAuthorised = assurance.isAuthorised(f);
      _ageChecked = true;
    });
  }

  @override
  void dispose() {
    _speakTimer?.cancel();
    _line.dispose();
    _srcField.dispose();
    super.dispose();
  }

  Future<void> _loadOverride() async {
    final f = _focused;
    if (f == null) return;
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString('avatar3d_src_${f.id}');
    if (mounted) {
      setState(() {
        _overrideSrc = (v != null && v.trim().isNotEmpty) ? v.trim() : null;
        _srcField.text = v ?? '';
      });
    }
  }

  Future<void> _saveOverride() async {
    final f = _focused;
    if (f == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('avatar3d_src_${f.id}', _srcField.text.trim());
    await _loadOverride();
    _refreshClip();
  }

  /// The effective 3D config for the current focus (demo or
  /// character), or null when the character has no model.
  Avatar3DConfig? get _config {
    if (_demoMode) return demoAvatarConfig;
    final f = _focused;
    if (f == null) return null;
    if (_overrideSrc != null) {
      return Avatar3DConfig(
        modelSrc: _overrideSrc!,
        animations: f.avatar3d?.animations ?? const {},
      );
    }
    final c = f.avatar3d;
    return (c != null && c.hasModel) ? c : null;
  }

  String get _emotion => _demoMode
      ? 'demo'
      : (_focused == null
          ? '—'
          : _mind?.affects.of(_focused!.id).emotion.emotion ?? '—');

  void _refreshClip() {
    final cfg = _config;
    if (cfg == null) {
      setState(() => _clip = null);
      return;
    }
    setState(() {
      _clip = StageDirector.pickClip(
        cfg,
        emotion: _followEmotion ? _emotion : 'idle',
        speaking: _speaking,
      );
    });
  }

  void _gesture(String slot) {
    final cfg = _config;
    if (cfg == null) return;
    setState(() => _clip = cfg.animations[slot] ?? cfg.animations['idle']);
  }

  Future<void> _speakLine() async {
    final f = _focused;
    final text = _line.text.trim();
    if (f == null || text.isEmpty || _speaking) return;
    if (f.ageGated && !_ageAuthorised) return;
    final mind = _mind;
    setState(() => _speaking = true);
    _refreshClip();
    try {
      if (mind != null) {
        await _voice.speak(f, mind.affects.of(f.id).current, text);
      }
    } catch (_) {
      // Voice failure is surfaced by the chat surfaces; on the
      // stage we just end the talk animation.
    }
    // Estimated utterance hold (~14 chars/sec of speech).
    final holdMs = (text.length / 14 * 1000).clamp(1500, 15000).toInt();
    _speakTimer?.cancel();
    _speakTimer = Timer(Duration(milliseconds: holdMs), () {
      if (mounted) {
        setState(() => _speaking = false);
        _refreshClip();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_focused?.ageGated == true && (!_ageChecked || !_ageAuthorised)) {
      return Scaffold(
        appBar: AppBar(title: const Text('THE STAGE — 3D')),
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
    final cfg = _config;
    final registry = _registry ?? _mind?.registry;
    return Scaffold(
      appBar: AppBar(title: const Text('THE STAGE — 3D')),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ---------- STAGE ----------
          Container(
            color: const Color(0xFF050607),
            child: AspectRatio(
              aspectRatio: 4 / 3.4,
              child: cfg == null
                  ? _noModelState()
                  : Stack(
                      children: [
                        ModelViewer(
                          key: ValueKey(cfg.modelSrc),
                          src: cfg.modelSrc,
                          alt: _demoMode
                              ? 'Stage demo robot (sample model)'
                              : '3D model of ${_focused?.name}',
                          backgroundColor: const Color(0xFF050607),
                          animationName: _clip,
                          autoPlay: true,
                          cameraControls: true,
                          autoRotate: !_speaking,
                          shadowIntensity: 1,
                          shadowSoftness: 1,
                          exposure: 1.15,
                        ),
                        Positioned(
                          left: 10,
                          top: 8,
                          child: _tag(_demoMode
                              ? 'DEMO MODEL — sample robot, not a character'
                              : '${_focused!.displayName.toUpperCase()} — LIVE'),
                        ),
                        Positioned(
                          right: 10,
                          top: 8,
                          child: _tag(_clip == null
                              ? 'clip: model default'
                              : 'clip: $_clip'),
                        ),
                        Positioned(
                          left: 10,
                          bottom: 8,
                          child: _tag(_demoMode
                              ? 'drag to orbit • pinch to zoom'
                              : 'feeling: $_emotion'
                                  '${_speaking ? ' • speaking' : ''}'),
                        ),
                      ],
                    ),
            ),
          ),
          // ---------- FOCUS RAIL ----------
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Text('ON STAGE',
                style: TextStyle(
                    letterSpacing: 2,
                    fontSize: 12,
                    color: Obsidian.gold,
                    fontWeight: FontWeight.bold)),
          ),
          SizedBox(
            height: 74,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: [
                _railItem(
                  label: 'Demo Robot',
                  sub: 'pipeline demo',
                  selected: _demoMode,
                  onTap: () => setState(() {
                    _demoMode = true;
                    _refreshClip();
                  }),
                  child: const Icon(Icons.smart_toy_outlined,
                      color: Obsidian.goldBright),
                ),
                if (registry != null)
                  for (final c in registry.all)
                    _railItem(
                      label: c.name,
                      sub: (c.avatar3d?.hasModel ?? false)
                          ? '3D ready'
                          : 'no model yet',
                      selected: !_demoMode && _focused?.id == c.id,
                      onTap: () async {
                        setState(() {
                          _demoMode = false;
                          _focused = c;
                        });
                        await _loadOverride();
                        _refreshClip();
                        await _refreshFocusedAge();
                      },
                      child: CharacterAvatar(def: c, radius: 16),
                    ),
              ],
            ),
          ),
          if (!_demoMode && _focused != null) ...[
            // ---------- CHARACTER STAGE CONTROLS ----------
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text('${_focused!.displayName} is feeling $_emotion',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    const Text('Follow emotion',
                        style: TextStyle(fontSize: 12)),
                    Switch(
                      value: _followEmotion,
                      onChanged: (v) {
                        setState(() => _followEmotion = v);
                        _refreshClip();
                      },
                    ),
                  ]),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _line,
                        decoration: InputDecoration(
                          hintText:
                              'Line for ${_focused!.name} to say on stage',
                        ),
                        onSubmitted: (_) => _speakLine(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _speakLine,
                      child: const Text('Speak'),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  const Text('MODEL SOURCE OVERRIDE (this device)',
                      style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 1.5,
                          color: Obsidian.muted)),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _srcField,
                        decoration: const InputDecoration(
                          hintText: 'https://…/model.glb or assets/… path',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _saveOverride,
                      child: const Text('Save'),
                    ),
                  ]),
                ],
              ),
            ),
          ],
          // ---------- GESTURES ----------
          if (cfg != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final g in stageGestures.entries)
                    ActionChip(
                      label: Text(g.key),
                      onPressed: () => _gesture(g.value),
                    ),
                  ActionChip(
                    label: const Text('Current emotion'),
                    onPressed: _refreshClip,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _noModelState() {
    final f = _focused;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (f != null) CharacterAvatar(def: f, radius: 34),
            const SizedBox(height: 12),
            Text(
              f == null
                  ? 'Loading the cast…'
                  : '${f.displayName} has no 3D model yet.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Give this agent a body: add a GLB in characters.json '
              '(avatar3d.model_src + its clip names), or paste a model '
              'URL below and Save. Until then the stage will not '
              'pretend the demo robot is this character.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Obsidian.muted),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => setState(() {
                _demoMode = true;
                _refreshClip();
              }),
              icon: const Icon(Icons.smart_toy_outlined),
              label: const Text('Preview the pipeline — demo robot'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _railItem({
    required String label,
    required String sub,
    required bool selected,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 92,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: selected ? Obsidian.panel : Colors.transparent,
            border:
                Border.all(color: selected ? Obsidian.gold : Obsidian.muted),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              child,
              const SizedBox(height: 4),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.bold)),
              Text(sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: Obsidian.muted)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style: const TextStyle(fontSize: 10, color: Obsidian.cream)),
    );
  }
}
