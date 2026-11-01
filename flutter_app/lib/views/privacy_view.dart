import 'package:flutter/material.dart';

/// Privacy — what actually leaves this device, in plain language.
///
/// The rows mirror the provider data-flow map in
/// `docs/SECURITY_REVIEW_2026-10-23.md` §3, which was built from
/// the call sites. If a provider flow changes, this screen and
/// that map must change together (checked again at P8 freeze).
class PrivacyView extends StatelessWidget {
  const PrivacyView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy — data flows')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Text(
            'Rich Gang AI runs on this device. Nothing in the list '
            'below is sent anywhere unless the named feature is '
            'used with the named provider configured. API keys stay '
            'in Keystore-backed secure storage on the device and '
            'are never sent to any provider except their own.',
          ),
          SizedBox(height: 16),
          _Flow(
            title: 'Cloud chat, Roundtable, dream text',
            destination: 'The cloud provider selected in Settings: NVIDIA, '
                'OpenAI, or Google Gemini.',
            payload: 'The full composed prompt: the character\'s persona '
                'definition, a block of recalled on-device memories '
                'when present, a web-search block when a search ran, '
                'and your message (or the Roundtable transcript).',
          ),
          _Flow(
            title: 'Ollama fallback / local-only tasks',
            destination: 'The Ollama base URL configured in Settings '
                '(default http://127.0.0.1:11434/v1 — this phone).',
            payload: 'The same composed prompt, sent to that '
                'endpoint instead of a cloud provider.',
          ),
          _Flow(
            title: 'ElevenLabs voice',
            destination: 'api.elevenlabs.io',
            payload: 'The reply text to synthesise, the character\'s '
                'voice ID, and prosody settings. Without an '
                'ElevenLabs key, voices use the phone\'s system TTS '
                'and nothing is sent.',
          ),
          _Flow(
            title: 'LiveAvatar video calls (FULL mode)',
            destination: 'api.liveavatar.com, plus the LiveKit '
                'media path LiveAvatar returns.',
            payload: 'A server-side Context built from the '
                'character definition (name, core/personality/'
                'speech style/interests, opening line); session '
                'requests carry avatar/context/voice IDs. Your '
                'microphone audio and the conversation are then '
                'handled on LiveAvatar\'s side — the in-app brain '
                'and memory are not part of a LiveAvatar call.',
          ),
          _Flow(
            title: 'Legacy HeyGen',
            destination: 'api.heygen.com',
            payload: 'On the legacy call path: API key, avatar/'
                'voice IDs, and the speak-task text. The HeyGen '
                'segment is disabled in this build (not live-call '
                'verified). The separate HeyGen video-generation '
                'client has no shipped workflow in this build.',
          ),
          _Flow(
            title: 'Web search',
            destination: 'DuckDuckGo Instant Answer '
                '(api.duckduckgo.com) and Wikipedia '
                '(en.wikipedia.org).',
            payload: 'The query text that triggered the search '
                'heuristic in a chat or Roundtable turn.',
          ),
          _Flow(
            title: 'Deepgram',
            destination: 'api.deepgram.com',
            payload: 'Nothing today. A Deepgram client (Nova-3 '
                'speech-to-text / Aura text-to-speech shapes) '
                'exists in the code but has no production caller '
                'in this build, so a saved Deepgram key is stored '
                'but unused.',
          ),
          _Flow(
            title: 'Crew Link (LiveKit)',
            destination: 'The LiveKit project URL configured in '
                'Settings.',
            payload: 'No shipped screen calls the Crew Link '
                'service today. When it is wired, joining a room '
                'sends an access token and microphone audio to '
                'that project.',
          ),
          SizedBox(height: 8),
          Text(
            'Stored on this device: character mind state (affect '
            'and self-models), Danny\'s ledger and self-upgrade '
            'state, per-character provider IDs, Stage model '
            'overrides, and settings. Settings offers "Remove all '
            'API keys" and "Reset local data" — see the wording '
            'there for exactly what each one removes.',
          ),
        ],
      ),
    );
  }
}

class _Flow extends StatelessWidget {
  const _Flow({
    required this.title,
    required this.destination,
    required this.payload,
  });

  final String title;
  final String destination;
  final String payload;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text('Goes to: $destination', style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 2),
          Text('What leaves: $payload', style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
