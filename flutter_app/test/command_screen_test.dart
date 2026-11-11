import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rich_gang_ai/views/command_screen.dart';

/// Locks the honest behaviour of the real Command screen
/// (2026-11-09, Richard-approved slice): live daemon state only,
/// a mandatory NOT MEASURED strip, no fake mockup figures, and an
/// explicit error card with Retry when the daemon cannot be read.
///
/// The widget tests inject a fake CommandStateSource — the seam
/// exists so these tests can run in this VM, where libdaemon.so
/// cannot be loaded. The shipped screen always uses the live
/// source; the fake lives only in this test file.
class _FakeSource implements CommandStateSource {
  _FakeSource({this.failFirst = false});

  final bool failFirst;
  var _failed = false;

  @override
  Future<CommandReadings> read() async {
    if (failFirst && !_failed) {
      _failed = true;
      throw StateError('daemon not booted');
    }
    return const CommandReadings(
      daemonVersion: 'test-daemon 0.1.0',
      spawnJson: '{"max":3,"held":1,"free":[0,2]}',
      intentJson: '{"depth":2,"capacity":64,"full":false}',
      reclaimJson:
          '{"entries":5,"persistent":true,"journal_mode":"wal",'
          '"keys":["a","b","c","d","e"]}',
      ringJson:
          '{"enabled":true,"capacity":4096,"head":10,"tail":4,'
          '"pending_bytes":128,"pending_messages":1}',
      topologyJson: '{"nodes":4,"edges":3,"order":["a","b","c","d"]}',
    );
  }
}

void main() {
  testWidgets('Command screen shows live values and the NOT MEASURED strip',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: CommandScreen(source: _FakeSource())),
    );
    await tester.pumpAndSettle();

    // The anti-mockup label is mandatory.
    expect(find.textContaining('NOT MEASURED'), findsOneWidget);
    expect(find.textContaining('none of those is measured on-device'),
        findsOneWidget);
    // Every section renders its live values — real numbers, not
    // the mockup's uptime/latency/error-rate figures.
    expect(find.textContaining('1 of 3'), findsOneWidget);
    expect(find.textContaining('2 of 64'), findsOneWidget);
    expect(find.textContaining('1 messages (128 bytes)'), findsOneWidget);
    expect(find.text('Daemon: test-daemon 0.1.0'), findsOneWidget);
    // The mockup's fake figures appear nowhere on the screen.
    expect(find.textContaining('99.9%'), findsNothing);
    expect(find.textContaining('0.0%'), findsNothing);
  });

  testWidgets('daemon error shows the real error with Retry, and Retry '
      'recovers', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: CommandScreen(source: _FakeSource(failFirst: true))),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('daemon not booted'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.textContaining('daemon not booted'), findsNothing);
    expect(find.textContaining('1 of 3'), findsOneWidget);
  });

  test('Command screen source locks: live bindings, strip, no fake figures',
      () {
    final screen =
        File('lib/views/command_screen.dart').readAsStringSync();
    expect(screen, contains('NOT MEASURED'));
    for (final method in [
      'spawnState()',
      'intentState()',
      'reclaimReport()',
      'ringState()',
      'topologyState()',
    ]) {
      expect(screen, contains(method),
          reason: 'Command screen must read live state via $method');
    }
    expect(screen, isNot(contains('99.9%')),
        reason: 'mockup uptime figure must never appear');
    expect(screen, isNot(contains('0.0%')),
        reason: 'mockup error-rate figure must never appear');
  });

  test('The Room links to the Command screen', () {
    final room = File('lib/views/the_room.dart').readAsStringSync();
    expect(room, contains('CommandScreen'));
    expect(room, contains('Command — live daemon state'));
  });
}
