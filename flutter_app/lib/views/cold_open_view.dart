import 'dart:async';

import 'package:flutter/material.dart';

import '../core/native_bridge.dart';
import '../theme/obsidian.dart';

/// The decaying cold open (build order step 1): a brief launch
/// sequence over The Room — brand mark, then the daemon's REAL status.
/// It shows no content of its own: the status line is read from the
/// live NativeBridge, and if the daemon is down it says so.
///
/// Tap anywhere to skip. The caller decides whether it runs at all
/// and for how long (AppSettings.coldOpenDuration) — this widget only
/// plays what it is given and calls [onDone] exactly once.
class ColdOpenView extends StatefulWidget {
  const ColdOpenView({
    super.key,
    required this.duration,
    required this.onDone,
  });

  final Duration duration;
  final VoidCallback onDone;

  @override
  State<ColdOpenView> createState() => _ColdOpenViewState();
}

class _ColdOpenViewState extends State<ColdOpenView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _doneTimer;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..forward();
    // Hold the final frame briefly so the status line is readable,
    // then hand over to The Room.
    _doneTimer = Timer(widget.duration + const Duration(milliseconds: 350),
        _finish);
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    widget.onDone();
  }

  @override
  void dispose() {
    _doneTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  String get _statusLine {
    final bridge = NativeBridge();
    if (!bridge.isUp) return 'DAEMON OFFLINE';
    try {
      return 'DAEMON ONLINE · ${bridge.daemonVersion}';
    } catch (_) {
      return 'DAEMON ONLINE';
    }
  }

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    return GestureDetector(
      onTap: _finish,
      child: Container(
        color: Obsidian.background,
        child: Center(
          child: FadeTransition(
            opacity: fade,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('◆',
                    style:
                        TextStyle(color: Obsidian.goldBright, fontSize: 34)),
                const SizedBox(height: 14),
                const Text(
                  'RICH GANG AI',
                  style: TextStyle(
                    color: Obsidian.cream,
                    fontSize: 22,
                    letterSpacing: 6,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Container(width: 120, height: 1, color: Obsidian.gold),
                const SizedBox(height: 12),
                Text(
                  _statusLine,
                  style: const TextStyle(
                    color: Obsidian.muted,
                    fontSize: 11,
                    letterSpacing: 3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
