import 'dart:async';
import 'package:flutter/material.dart';
import '../core/character.dart';
import '../core/persistent_mind.dart';
import '../theme/obsidian.dart';
import 'character_chat_view.dart';
import 'character_ui.dart';

/// Pick a character to talk to — the Chat tab's front door.
/// Shows each agent's real current emotion and talk count from the
/// persistent mind, so returning to the app shows who has been
/// active and how they are feeling before you even open a chat.
class CharacterPicker extends StatefulWidget {
  const CharacterPicker({super.key});

  @override
  State<CharacterPicker> createState() => _CharacterPickerState();
}

class _CharacterPickerState extends State<CharacterPicker> {
  CharacterRegistry? _registry;

  @override
  void initState() {
    super.initState();
    unawaited(CharacterRegistry.load().then((r) async {
      if (MindStore.instance == null) await MindStore.boot(r);
      if (mounted) setState(() => _registry = r);
    }));
  }

  Future<void> _openCharacter(CharacterDef c) async {
    if (c.isRegistryOnly) {
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(c.displayName),
          content:
              const Text('This is a registry-only entry. It has no configured '
                  'portrait, voice casting, or affect baseline, so it '
                  'does not open as a finished character.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      return;
    }
    if (c.ageGated && !await AgeGate.ensureAuthorised(context, c)) {
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => CharacterChatView(character: c)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final registry = _registry;
    final mind = MindStore.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Talk to an agent')),
      body: registry == null
          ? const Center(child: Text('Loading the cast…'))
          : registry.isEmpty
              ? const Center(
                  child: Text('No characters loaded — the app does '
                      'not invent a cast.'))
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    for (final c in registry.all)
                      Card(
                        color: Obsidian.panel,
                        child: ListTile(
                          leading: CharacterAvatar(def: c),
                          title: Text(c.displayName),
                          subtitle: Text('${c.title} • '
                              '${c.roles.map((r) => r.name).join(', ')}'
                              '${c.isRegistryOnly ? ' • REGISTRY ONLY — voice, affect & portrait not configured' : mind == null ? '' : ' • feeling ${mind.affects.of(c.id).emotion.emotion}'}'),
                          trailing: c.ageGated
                              ? const Text('21+',
                                  style: TextStyle(
                                      color: Obsidian.red,
                                      fontWeight: FontWeight.bold))
                              : const Icon(Icons.chevron_right),
                          onTap: () => _openCharacter(c),
                        ),
                      ),
                  ],
                ),
    );
  }
}
