import 'dart:async';
import 'package:flutter/material.dart';
import '../core/inference_router.dart';
import '../core/local_data_reset.dart';
import '../core/native_bridge.dart';
import '../core/room_rate_controller.dart';
import '../core/secure_keys.dart';
import '../core/settings.dart';
import 'privacy_view.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final _key = TextEditingController();
  final _elevenKey = TextEditingController();
  final _heygenKey = TextEditingController();
  final _liveAvatarKey = TextEditingController();
  final _openAiKey = TextEditingController();
  final _geminiKey = TextEditingController();
  final _deepgramKey = TextEditingController();
  final _liveKitKey = TextEditingController();
  final _liveKitSecret = TextEditingController();
  late final TextEditingController _ollama =
      TextEditingController(text: AppSettings.instance.ollamaBaseUrl);
  late final TextEditingController _liveKitUrl =
      TextEditingController(text: AppSettings.instance.liveKitUrl);
  late final TextEditingController _liveKitTokenEndpoint =
      TextEditingController(text: AppSettings.instance.liveKitTokenEndpoint);
  late final TextEditingController _heyGenAvatarId =
      TextEditingController(text: AppSettings.instance.heyGenAvatarId);
  late final TextEditingController _heyGenVoiceId =
      TextEditingController(text: AppSettings.instance.heyGenVoiceId);
  String _msg = '';

  @override
  void dispose() {
    _key.dispose();
    _elevenKey.dispose();
    _heygenKey.dispose();
    _liveAvatarKey.dispose();
    _openAiKey.dispose();
    _geminiKey.dispose();
    _deepgramKey.dispose();
    _liveKitKey.dispose();
    _liveKitSecret.dispose();
    _liveKitUrl.dispose();
    _liveKitTokenEndpoint.dispose();
    _heyGenAvatarId.dispose();
    _heyGenVoiceId.dispose();
    _ollama.dispose();
    super.dispose();
  }

  /// One obscure key field + save button, used by every cloud API
  /// below. Saving reports success/failure in the shared _msg line;
  /// keys go to Keystore-backed secure storage via SecureKeys only.
  Widget _apiKeyField({
    required TextEditingController controller,
    required String label,
    required String helper,
    required Future<void> Function(String) save,
    required String savedMessage,
    Future<void> Function()? clear,
    String? note,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          obscureText: true,
          decoration: InputDecoration(labelText: label, helperText: helper),
        ),
        ElevatedButton(
          onPressed: () async {
            try {
              await save(controller.text);
              setState(() => _msg = savedMessage);
            } catch (e) {
              setState(() => _msg = '$e');
            }
          },
          child: Text('Save $label'),
        ),
        if (clear != null)
          OutlinedButton(
            onPressed: () async {
              try {
                await clear();
                controller.clear();
                setState(() => _msg = '$label removed');
              } catch (e) {
                setState(() => _msg = '$e');
              }
            },
            child: Text('Remove $label'),
          ),
        if (note != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(note,
                style: const TextStyle(fontSize: 12, color: Colors.redAccent)),
          ),
        const SizedBox(height: 12),
      ],
    );
  }

  Future<void> _confirmRemoveAllKeys() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove all API keys?'),
        content: const Text('Every provider credential in secure storage is '
            'deleted: NVIDIA, ElevenLabs, HeyGen, OpenAI, Gemini, '
            'Deepgram, LiveAvatar, and the LiveKit key/secret pair. '
            'Providers then fail explicitly for a missing key '
            'until a new key is saved.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep keys')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Remove all keys')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await LocalDataReset.removeAllApiKeys();
      if (mounted) setState(() => _msg = 'All API keys removed');
    } catch (e) {
      if (mounted) setState(() => _msg = '$e');
    }
  }

  Future<void> _confirmResetLocalData() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reset local data?'),
        content: const Text('Deletes the on-device preference data this app '
            'inventories: character mind state, Danny\'s ledger '
            'and self-upgrade state, the discernment record, '
            'age-assurance state, the launch counter, and '
            'per-character provider/Stage IDs. API keys are NOT '
            'removed by this action (use "Remove all API keys"). '
            'State already loaded into memory clears on the next '
            'app start.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep data')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Reset local data')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final removed = await LocalDataReset.clearPreferences();
      // The daemon's durable runtime-provenance keys (P6) live in
      // the Rust store, not preferences; delete them too when the
      // daemon is up. If it is offline there is no store session
      // to clean in this run, and the message says only what was
      // actually removed.
      try {
        NativeBridge().storeDelete('runtime.last_boot_at');
        NativeBridge().storeDelete('runtime.config_schema');
      } catch (_) {}
      if (mounted) {
        setState(
            () => _msg = 'Local data reset ($removed preference keys removed; '
                'takes full effect on next app start)');
      }
    } catch (e) {
      if (mounted) setState(() => _msg = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppSettings.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Trust dial'),
          SegmentedButton<TrustDial>(
            segments: const [
              ButtonSegment(value: TrustDial.silent, label: Text('Silent')),
              ButtonSegment(value: TrustDial.standard, label: Text('Standard')),
              ButtonSegment(value: TrustDial.theater, label: Text('Theater')),
            ],
            selected: {s.trustDial},
            onSelectionChanged: (v) =>
                setState(() => s.update(() => s.trustDial = v.first)),
          ),
          const SizedBox(height: 16),
          const Text('Frame rate'),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 60, label: Text('60')),
              ButtonSegment(value: 30, label: Text('30 Cinematic')),
            ],
            selected: {s.frameRate},
            onSelectionChanged: (v) {
              setState(() => s.update(() => s.frameRate = v.first));
              // Actually hint the OS, not just store the value (M7).
              unawaited(RoomRateController().apply(v.first));
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ollama,
            decoration: const InputDecoration(
              labelText: 'Ollama base URL',
              helperText: 'Cleartext is allowed only for 127.0.0.1, localhost '
                  'and 10.0.2.2 (emulator host). A LAN IP over http:// '
                  'will be refused — use an on-device/Termux server '
                  'or an HTTPS endpoint.',
            ),
            onSubmitted: (v) => s.update(() => s.ollamaBaseUrl = v),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _key,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'NVIDIA API key (nvapi-...)',
              helperText: 'Stored in Keystore-backed secure storage only',
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await SecureKeys.setNvidiaKey(_key.text);
                // A fresh key must not inherit the old key's back-off.
                InferenceRouter.shared.clearNvidiaCooldown();
                setState(() => _msg = 'Key saved');
              } catch (e) {
                setState(() => _msg = '$e');
              }
            },
            child: const Text('Save key'),
          ),
          OutlinedButton(
            onPressed: () async {
              try {
                await SecureKeys.clearNvidiaKey();
                InferenceRouter.shared.clearNvidiaCooldown();
                _key.clear();
                setState(() => _msg = 'NVIDIA key removed');
              } catch (e) {
                setState(() => _msg = '$e');
              }
            },
            child: const Text('Remove NVIDIA key'),
          ),
          if (_msg.isNotEmpty) Text(_msg),
          const SizedBox(height: 24),
          const Text('Character voices & video calls',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _elevenKey,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'ElevenLabs API key (agent voices)',
              helperText: 'Keystore secure storage only. Without it, agents '
                  'use the phone\'s system TTS and say so.',
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await SecureKeys.setElevenLabsKey(_elevenKey.text);
                setState(() => _msg = 'ElevenLabs key saved');
              } catch (e) {
                setState(() => _msg = '$e');
              }
            },
            child: const Text('Save ElevenLabs key'),
          ),
          OutlinedButton(
            onPressed: () async {
              try {
                await SecureKeys.clearElevenLabsKey();
                _elevenKey.clear();
                setState(() => _msg = 'ElevenLabs key removed');
              } catch (e) {
                setState(() => _msg = '$e');
              }
            },
            child: const Text('Remove ElevenLabs key'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _heygenKey,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'HeyGen API key (avatar video calls)',
              helperText: 'Keystore secure storage only. LEGACY: the HeyGen '
                  'call segment is disabled in this build (not '
                  'live-call verified), and the separate video-'
                  'generation client has no shipped workflow in '
                  'this build.',
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await SecureKeys.setHeyGenKey(_heygenKey.text);
                setState(() => _msg = 'HeyGen key saved');
              } catch (e) {
                setState(() => _msg = '$e');
              }
            },
            child: const Text('Save HeyGen key'),
          ),
          OutlinedButton(
            onPressed: () async {
              try {
                await SecureKeys.clearHeyGenKey();
                _heygenKey.clear();
                setState(() => _msg = 'HeyGen key removed');
              } catch (e) {
                setState(() => _msg = '$e');
              }
            },
            child: const Text('Remove HeyGen key'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _liveAvatarKey,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'LiveAvatar API key (realtime avatar calls)',
              helperText: 'LiveAvatar is HeyGen\'s production realtime '
                  'platform — a SEPARATE account, plan and key from '
                  'HeyGen (liveavatar.com). The legacy HeyGen '
                  'streaming endpoint currently answers 404 in '
                  'pre-flight checks; LiveAvatar is the working '
                  'path. Avatar ids are set per character on the '
                  'call screen.',
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await SecureKeys.setLiveAvatarKey(_liveAvatarKey.text);
                setState(() => _msg = 'LiveAvatar key saved');
              } catch (e) {
                setState(() => _msg = '$e');
              }
            },
            child: const Text('Save LiveAvatar key'),
          ),
          OutlinedButton(
            onPressed: () async {
              try {
                await SecureKeys.clearLiveAvatarKey();
                _liveAvatarKey.clear();
                setState(() => _msg = 'LiveAvatar key removed');
              } catch (e) {
                setState(() => _msg = '$e');
              }
            },
            child: const Text('Remove LiveAvatar key'),
          ),
          const SizedBox(height: 24),
          const Text('Cloud APIs',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Cloud provider (chat & broadcast tasks)'),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'nvidia', label: Text('NVIDIA')),
              ButtonSegment(value: 'openai', label: Text('OpenAI')),
              ButtonSegment(value: 'gemini', label: Text('Gemini')),
            ],
            selected: {s.cloudProvider},
            onSelectionChanged: (v) =>
                setState(() => s.update(() => s.cloudProvider = v.first)),
          ),
          const SizedBox(height: 4),
          Text(
            'OpenAI model: ${s.openAiModel} · Gemini model: '
            '${s.geminiModel}. Local-only tasks never leave the device; '
            'Ollama is the fallback for every cloud provider.',
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 12),
          _apiKeyField(
            controller: _openAiKey,
            label: 'OpenAI API key',
            helper: 'Keystore secure storage only. Powers the OpenAI '
                'provider incl. GPT-6 Astra (model above).',
            save: SecureKeys.setOpenAiKey,
            savedMessage: 'OpenAI key saved',
            clear: SecureKeys.clearOpenAiKey,
          ),
          _apiKeyField(
            controller: _geminiKey,
            label: 'Gemini API key',
            helper: 'Keystore secure storage only.',
            save: SecureKeys.setGeminiKey,
            savedMessage: 'Gemini key saved',
            clear: SecureKeys.clearGeminiKey,
          ),
          _apiKeyField(
            controller: _deepgramKey,
            label: 'Deepgram API key',
            helper: 'Keystore secure storage only. Speech-to-text '
                '(Nova-3) and Aura text-to-speech.',
            save: SecureKeys.setDeepgramKey,
            savedMessage: 'Deepgram key saved',
            clear: SecureKeys.clearDeepgramKey,
            note: 'NOT WIRED IN THIS BUILD: the Deepgram client has '
                'no production caller, so this key is stored but '
                'unused. Nothing is sent to Deepgram.',
          ),
          const Text('HeyGen video generation',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text(
            'NOT WIRED IN THIS BUILD: the HeyGen video-generation '
            'client has no production caller. The IDs below are '
            'session settings only and start nothing.',
            style: TextStyle(fontSize: 12, color: Colors.redAccent),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _heyGenAvatarId,
            decoration: const InputDecoration(
              labelText: 'HeyGen avatar_id (video generation)',
              helperText: 'From your HeyGen library — used by the '
                  'video-generation client, separate from call avatars.',
            ),
            onSubmitted: (v) => s.update(() => s.heyGenAvatarId = v.trim()),
          ),
          TextField(
            controller: _heyGenVoiceId,
            decoration: const InputDecoration(
              labelText: 'HeyGen voice_id (video generation)',
            ),
            onSubmitted: (v) => s.update(() => s.heyGenVoiceId = v.trim()),
          ),
          const SizedBox(height: 16),
          const Text('LiveKit (Crew Link voice rooms)',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _liveKitUrl,
            decoration: const InputDecoration(
              labelText: 'LiveKit project URL (wss://...)',
              helperText: 'Not a secret. Joining also needs the Crew '
                  'Link switch on, below.',
            ),
            onSubmitted: (v) => s.update(() => s.liveKitUrl = v.trim()),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _liveKitTokenEndpoint,
            decoration: const InputDecoration(
              labelText: 'LiveKit token endpoint (optional, server-minted)',
              helperText: 'When set, Crew Link fetches tokens from '
                  'this endpoint (POST {room, identity} → {token}) '
                  'and the on-device secret below is not used. When '
                  'empty, tokens are minted ON-DEVICE with the '
                  'secret — a private-build risk (SEC-01): a '
                  'shipped product must use a server endpoint or '
                  'exclude Crew Link.',
            ),
            onSubmitted: (v) =>
                s.update(() => s.liveKitTokenEndpoint = v.trim()),
          ),
          const SizedBox(height: 4),
          const Text(
            'No shipped screen calls the Crew Link service today; '
            'these fields are stored for the flagged, paired-only '
            'workflow and join nothing by themselves.',
            style: TextStyle(fontSize: 12, color: Colors.redAccent),
          ),
          const SizedBox(height: 8),
          _apiKeyField(
            controller: _liveKitKey,
            label: 'LiveKit API key',
            helper: 'Keystore secure storage only.',
            save: SecureKeys.setLiveKitApiKey,
            savedMessage: 'LiveKit API key saved',
            clear: SecureKeys.clearLiveKit,
          ),
          _apiKeyField(
            controller: _liveKitSecret,
            label: 'LiveKit API secret',
            helper: 'Keystore secure storage only. Signs access tokens '
                'on-device — see the note in the LiveKit service.',
            save: SecureKeys.setLiveKitApiSecret,
            savedMessage: 'LiveKit secret saved',
            clear: SecureKeys.clearLiveKit,
            note: 'Removing either LiveKit field removes the '
                'key/secret pair.',
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Ambient features'),
            subtitle: const Text('Default off. Gated by the trust dial, '
                'quiet hours, DND and the kill switch.'),
            value: s.ambientEnabled,
            onChanged: (v) =>
                setState(() => s.update(() => s.ambientEnabled = v)),
          ),
          SwitchListTile(
            title: const Text('Crew Link'),
            subtitle: const Text('Flagged, paired devices only. No device '
                'is paired, so turning this on connects nothing yet — '
                'pairing is a separate step.'),
            value: s.crewLinkEnabled,
            onChanged: (v) =>
                setState(() => s.update(() => s.crewLinkEnabled = v)),
          ),
          const SizedBox(height: 16),
          const Text('Privacy & data',
              style: TextStyle(fontWeight: FontWeight.bold)),
          ListTile(
            title: const Text('Privacy — what leaves this device'),
            subtitle: const Text('Every provider data flow in plain language: '
                'destination and payload, including the flows '
                'that send nothing in this build.'),
            trailing: const Icon(Icons.privacy_tip_outlined),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const PrivacyView()),
            ),
          ),
          ListTile(
            title: const Text('Remove all API keys'),
            subtitle:
                const Text('Deletes every provider credential from secure '
                    'storage. Providers then fail explicitly for a '
                    'missing key.'),
            trailing: const Icon(Icons.key_off_outlined),
            onTap: _confirmRemoveAllKeys,
          ),
          ListTile(
            title: const Text('Reset local data'),
            subtitle:
                const Text('Deletes inventoried on-device preference data '
                    '(mind state, Danny stores, IDs, age-assurance '
                    'state). Keys are kept. Takes full effect on the '
                    'next app start.'),
            trailing: const Icon(Icons.delete_sweep_outlined),
            onTap: _confirmResetLocalData,
          ),
          ListTile(
            title: const Text('Affect grammar (GBNF)'),
            subtitle: const Text(
                'The schema a local engine is held to for AffectFrames'),
            trailing: const Icon(Icons.description_outlined),
            onTap: () {
              String text;
              try {
                text = NativeBridge().affectGrammar();
                if (text.isEmpty) text = 'Grammar unavailable.';
              } catch (e) {
                text = 'Daemon library unavailable: $e';
              }
              unawaited(showDialog<void>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Affect grammar (GBNF)'),
                  content: SingleChildScrollView(
                    child: SelectableText(text,
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 11)),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ));
            },
          ),
          ListTile(
            title: const Text('Kill switch'),
            subtitle: Text(s.ambientKilled
                ? 'Ambient silenced (24h window active)'
                : 'Silence all ambient for 24 hours'),
            trailing: const Icon(Icons.volume_off),
            onTap: () => setState(() => s.tripKillSwitch()),
          ),
        ],
      ),
    );
  }
}
