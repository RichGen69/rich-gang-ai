import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rich_gang_ai/core/call_history.dart';

/// Call history locks (2026-10-25): a call record holds the agent,
/// start/end times, and spoken lines in order; an ongoing call
/// reports NO duration (never zero); lines for an unknown call are
/// dropped rather than stored under a fabricated call; ending twice
/// keeps the first end time; a malformed stored record loads as an
/// empty history, never a partial one; and the record caps at the
/// most recent calls with older ones rolled off.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('a finished call round-trips with lines in order and a duration',
      () async {
    final history = CallHistory();
    await history.load();
    final started = DateTime.utc(2026, 10, 25, 13, 0);
    final id = await history.startCall('sally', at: started);
    expect(await history.addLine(id, 'user', 'Hey Sally.',
        at: started.add(const Duration(seconds: 1))), isTrue);
    expect(await history.addLine(id, 'sally', 'Hey. I am here.',
        at: started.add(const Duration(seconds: 2))), isTrue);
    expect(await history.endCall(id,
        at: started.add(const Duration(minutes: 3))), isTrue);

    final call = history.byId(id)!;
    expect(call.agentId, 'sally');
    expect(call.ongoing, isFalse);
    expect(call.duration, const Duration(minutes: 3));
    expect(call.lines.map((l) => l.text).toList(),
        ['Hey Sally.', 'Hey. I am here.']);
    expect(call.lines.map((l) => l.speaker).toList(), ['user', 'sally']);

    // Persistence: a fresh instance loads the same record back.
    final reloaded = CallHistory();
    await reloaded.load();
    final again = reloaded.byId(id)!;
    expect(again.duration, const Duration(minutes: 3));
    expect(again.lines.length, 2);
  });

  test('an ongoing call reports no duration, and ending twice keeps '
      'the first end time', () async {
    final history = CallHistory();
    final started = DateTime.utc(2026, 10, 25, 14, 0);
    final id = await history.startCall('carl', at: started);
    expect(history.byId(id)!.duration, isNull);
    expect(history.byId(id)!.ongoing, isTrue);
    expect(await history.endCall(id,
        at: started.add(const Duration(minutes: 1))), isTrue);
    expect(await history.endCall(id,
        at: started.add(const Duration(minutes: 9))), isFalse);
    expect(history.byId(id)!.duration, const Duration(minutes: 1));
  });

  test('lines for an unknown call are dropped, not fabricated',
      () async {
    final history = CallHistory();
    expect(await history.addLine('nope', 'user', 'Hello?'), isFalse);
    expect(history.all, isEmpty);
    expect(await history.endCall('nope'), isFalse);
    expect(await history.deleteCall('nope'), isFalse);
  });

  test('calls filter per agent, and delete/clear remove only their '
      'own scope', () async {
    final history = CallHistory();
    final a = await history.startCall('babs');
    final b = await history.startCall('carl');
    await history.endCall(a);
    expect(history.callsFor('babs').map((c) => c.id), [a]);
    expect(history.callsFor('carl').map((c) => c.id), [b]);
    expect(await history.deleteCall(a), isTrue);
    expect(history.callsFor('babs'), isEmpty);
    expect(history.callsFor('carl').map((c) => c.id), [b]);
    await history.clearAgent('carl');
    expect(history.all, isEmpty);
  });

  test('the cap rolls off the oldest calls', () async {
    final history = CallHistory(maxCalls: 3);
    final ids = <String>[];
    for (var i = 0; i < 4; i++) {
      ids.add(await history.startCall('mop',
          at: DateTime.utc(2026, 10, 25, 15, i)));
    }
    expect(history.all.map((c) => c.id).toList(), ids.sublist(1));
  });

  test('a malformed stored record loads as empty, never partial',
      () async {
    SharedPreferences.setMockInitialValues({
      CallHistory.storageKey: '[{"id": 42}]',
    });
    final history = CallHistory();
    await history.load();
    expect(history.all, isEmpty);
  });

  test('a malformed JSON blob loads as empty', () async {
    SharedPreferences.setMockInitialValues({
      CallHistory.storageKey: 'not json at all',
    });
    final history = CallHistory();
    await history.load();
    expect(history.all, isEmpty);
  });
}
