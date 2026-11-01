import 'package:flutter/material.dart';
import 'core/settings.dart';
import 'views/character_picker.dart';
import 'views/cold_open_view.dart';
import 'views/dream_broadcast_view.dart';
import 'views/roundtable_view.dart';
import 'views/settings_view.dart';
import 'views/the_room.dart';

/// Bottom navigation (2026-10-21 character build): The Room is the
/// main screen — Richard's instruction — then Chat (pick an agent),
/// Table (the roundtable: agents talking to each other), Memory
/// (dream broadcast), Settings.
class AppScaffold extends StatefulWidget {
  const AppScaffold({super.key});

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  int _index = 0;

  /// Decaying cold open (build order step 1): decided once, on the
  /// first build, from AppSettings.coldOpenDuration. Duration.zero
  /// (Silent, decayed past launch 3, quiet hours, kill switch, or
  /// reduced motion) means it never appears.
  Duration? _coldOpen;
  bool _coldOpenDone = false;

  static const _pages = <Widget>[
    TheRoom(),
    CharacterPicker(),
    RoundtableView(),
    DreamBroadcastView(),
    SettingsView(),
  ];

  @override
  Widget build(BuildContext context) {
    _coldOpen ??= AppSettings.instance.coldOpenDuration(
      reducedMotion: MediaQuery.of(context).disableAnimations,
    );
    final showColdOpen = !_coldOpenDone && _coldOpen! > Duration.zero;
    return Scaffold(
      body: Stack(
        children: [
          // IndexedStack preserves each destination's state when
          // Richard switches tabs; only the selected page is visible.
          IndexedStack(index: _index, children: _pages),
          if (showColdOpen)
            Positioned.fill(
              child: ColdOpenView(
                duration: _coldOpen!,
                onDone: () => setState(() => _coldOpenDone = true),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.meeting_room_outlined), label: 'Room'),
          BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline), label: 'Chat'),
          BottomNavigationBarItem(
              icon: Icon(Icons.groups_outlined), label: 'Table'),
          BottomNavigationBarItem(
              icon: Icon(Icons.bookmark_outline), label: 'Memory'),
          BottomNavigationBarItem(icon: Icon(Icons.tune), label: 'Settings'),
        ],
      ),
    );
  }
}
