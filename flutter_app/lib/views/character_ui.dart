import 'package:flutter/material.dart';
import '../core/age_assurance.dart';
import '../core/character.dart';

/// Per-character accent — visual identity in The Room, chat, and
/// the roundtable. Assigned in code to match each frame's palette
/// (Sally's rainbow hair gets the spectrum treatment as a gradient
/// in the room; here a single accent per agent for chips/avatars).
Color characterAccent(String id) {
  switch (id) {
    case 'danny':
      return const Color(0xFFA5F3FC); // ice cyan — Dan's twin, brighter cut
    case 'dan':
      return const Color(0xFF22D3EE); // cyan, Dan's HUD in his frames
    case 'rich':
      return const Color(0xFFE3B341); // gold, the host / plaque
    case 'crazy_kelly':
      return const Color(0xFFEC4899); // neon pink, the Neon Wildcard
    case 'freddy':
      return const Color(0xFF94A3B8); // steel, the cyborg
    case 'tammy':
      return const Color(0xFFA78BFA); // violet, her crystal ball
    case 'sally':
      return const Color(0xFF4ADE80); // green-punk, her hair streak
    case 'leo':
      return const Color(0xFFFBBF24);
    case 'capricorn':
      return const Color(0xFF34D399);
    case 'aquarius':
      return const Color(0xFF60A5FA);
    default:
      return const Color(0xFFC9A24B);
  }
}

/// Initial-letter avatar disc. A drawn monogram, honestly a
/// monogram — the characters' photographic/3D avatars are HeyGen
/// Interactive Avatars (video call) and Richard's frame art (Room
/// hero), not a picture this widget pretends to be.
class CharacterAvatar extends StatelessWidget {
  const CharacterAvatar({super.key, required this.def, this.radius = 22});
  final CharacterDef def;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final accent = characterAccent(def.id);
    final portrait = def.portrait;
    if (portrait != null) {
      // The character's cinematic portrait (characters.json). The
      // monogram below remains the fallback for any roster entry
      // without one — never a stock or placeholder face.
      return CircleAvatar(
        radius: radius,
        backgroundColor: accent.withValues(alpha: 0.18),
        backgroundImage: AssetImage(portrait),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: accent.withValues(alpha: 0.18),
      child: Text(
        def.name.characters.first.toUpperCase(),
        style: TextStyle(
          color: accent,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.9,
        ),
      ),
    );
  }
}

/// UI adapter for the one fail-closed [AgeAssurance] boundary.
///
/// The previous implementation stored a SharedPreferences boolean
/// after a tap on "I am 21+". That was a confirmation notice, not
/// verification. This build configures no age-assurance vendor, so
/// a gated character stays locked here and at every other
/// enforcement point (chat send, call, Stage, picker, Roundtable).
class AgeGate {
  AgeGate._();

  /// Silent decision for enforcement points that render their own
  /// locked state.
  static Future<bool> isAuthorised(CharacterDef c) async {
    if (!c.ageGated) return true;
    final assurance = await AgeAssurance.load();
    return assurance.isAuthorised(c);
  }

  /// Decision plus the one explanatory dialog used by navigation
  /// entry points. Returns false for every gated character in this
  /// build because no verified vendor is configured.
  static Future<bool> ensureAuthorised(
      BuildContext context, CharacterDef c) async {
    if (!c.ageGated) return true;
    if (await isAuthorised(c)) return true;
    if (!context.mounted) return false;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('${c.displayName} is locked'),
        content: const Text('This character is 21+. This build has no verified '
            'age-assurance provider configured, and a self-'
            'confirmation is not verification — so this character '
            'remains locked.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
    return false;
  }

  /// Backwards-compatible name for existing callers; it now uses
  /// the fail-closed boundary above and never grants on a tap.
  static Future<bool> ensure(BuildContext context, CharacterDef c) =>
      ensureAuthorised(context, c);
}
