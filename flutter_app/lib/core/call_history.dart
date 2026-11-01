import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// CALL HISTORY (2026-10-25, Richard's direction: "make able to save
/// call history") — an on-device record of voice calls, per character.
///
/// WHAT IT STORES, exactly: for each call, the agent id, when it
/// started, when it ended (null while the call is still going), and
/// every spoken line in order (speaker, text, timestamp). Nothing
/// else. No audio is stored — lines are text, the same text the
/// call view already transcribes.
///
/// WHAT IT DOES NOT DO: it never invents a call, a line, or a
/// duration. A call with no end time reports no duration (it is
/// ongoing, not zero-length). A failed or malformed load returns an
/// empty history — the MindStore pattern — it never fabricates a
/// past call to fill the gap.
///
/// LIMITS, stated so they can't be mistaken for features: the
/// record keeps the most recent [maxCalls] calls (default 200, the
/// lie detector's cap); older calls roll off and are gone. Each
/// call keeps at most [maxLinesPerCall] lines (default 2000);
/// older lines in a very long call roll off. The history is
/// on-device only, in SharedPreferences under [storageKey], and a
/// data reset wipes it (it is in LocalDataReset's inventory).
/// WIRING (2026-10-30): AvatarCallView calls [startCall] when
/// a call starts and [endCall] when it ends. LiveAvatar calls
/// add their lines from a single post-call fetch of
/// GET /v1/sessions/{session_id}/transcript (see liveavatar.dart);
/// a failed fetch leaves the record as session metadata only,
/// never with invented lines. Legacy HeyGen calls add the lines
/// the in-app agent actually spoke, plus the user's typed lines.
/// Until a real call runs, this service holds only what tests
/// put into it — an honest empty state, not a demo history.
class CallLine {
  const CallLine({
    required this.speaker,
    required this.text,
    required this.at,
  });

  final String speaker;
  final String text;
  final DateTime at;

  Map<String, dynamic> toJson() => {
        'speaker': speaker,
        'text': text,
        'at': at.toIso8601String(),
      };

  static CallLine? fromJson(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;
    final speaker = raw['speaker'];
    final text = raw['text'];
    final at = raw['at'];
    if (speaker is! String || text is! String || at is! String) {
      return null;
    }
    final parsed = DateTime.tryParse(at);
    if (parsed == null) return null;
    return CallLine(speaker: speaker, text: text, at: parsed);
  }
}

class CallRecord {
  const CallRecord({
    required this.id,
    required this.agentId,
    required this.startedAt,
    required this.lines,
    this.endedAt,
  });

  final String id;
  final String agentId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final List<CallLine> lines;

  bool get ongoing => endedAt == null;

  /// Null while the call is ongoing — an unfinished call has no
  /// duration to report, and reporting zero would be a fabrication.
  Duration? get duration => endedAt?.difference(startedAt);

  Map<String, dynamic> toJson() => {
        'id': id,
        'agentId': agentId,
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt?.toIso8601String(),
        'lines': [for (final line in lines) line.toJson()],
      };

  static CallRecord? fromJson(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;
    final id = raw['id'];
    final agentId = raw['agentId'];
    final startedAt = raw['startedAt'];
    if (id is! String || agentId is! String || startedAt is! String) {
      return null;
    }
    final started = DateTime.tryParse(startedAt);
    if (started == null) return null;
    DateTime? ended;
    final endedRaw = raw['endedAt'];
    if (endedRaw is String) {
      ended = DateTime.tryParse(endedRaw);
      if (ended == null) return null;
    }
    final linesRaw = raw['lines'];
    if (linesRaw is! List) return null;
    final lines = <CallLine>[];
    for (final lineRaw in linesRaw) {
      final line = CallLine.fromJson(lineRaw);
      if (line == null) return null;
      lines.add(line);
    }
    return CallRecord(
      id: id,
      agentId: agentId,
      startedAt: started,
      endedAt: ended,
      lines: lines,
    );
  }
}

class CallHistory {
  CallHistory({this.maxCalls = 200, this.maxLinesPerCall = 2000});

  static const storageKey = 'call_history_v1';

  final int maxCalls;
  final int maxLinesPerCall;

  final List<CallRecord> _calls = [];

  List<CallRecord> get all => List.unmodifiable(_calls);

  List<CallRecord> callsFor(String agentId) =>
      _calls.where((c) => c.agentId == agentId).toList();

  CallRecord? byId(String id) {
    for (final call in _calls) {
      if (call.id == id) return call;
    }
    return null;
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(storageKey);
      if (raw == null) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final restored = <CallRecord>[];
      for (final item in decoded) {
        final record = CallRecord.fromJson(item);
        if (record == null) return; // Malformed: empty, never partial.
        restored.add(record);
      }
      _calls
        ..clear()
        ..addAll(restored);
    } catch (_) {
      _calls.clear();
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        storageKey,
        jsonEncode([for (final c in _calls) c.toJson()]),
      );
    } catch (_) {
      // Persistence failure degrades to in-memory only; the
      // in-memory record is still returned by the getters.
    }
  }

  void _enforceCaps() {
    while (_calls.length > maxCalls) {
      _calls.removeAt(0);
    }
  }

  /// Starts a call and returns its id. The id is the agent id plus
  /// the start timestamp — unique per call in practice, and
  /// readable in the stored JSON.
  Future<String> startCall(String agentId, {DateTime? at}) async {
    final started = at ?? DateTime.now();
    final id = 'call_${agentId}_${started.millisecondsSinceEpoch}';
    _calls.add(CallRecord(
      id: id,
      agentId: agentId,
      startedAt: started,
      lines: [],
    ));
    _enforceCaps();
    await _save();
    return id;
  }

  /// Appends one spoken line to an existing call. Lines for an
  /// unknown call id are dropped, not stored under a fabricated
  /// call — a line with no call is an error in the caller, and
  /// this service does not paper over it with invented state.
  /// Returns false when the call id was unknown.
  Future<bool> addLine(
    String callId,
    String speaker,
    String text, {
    DateTime? at,
  }) async {
    final index = _calls.indexWhere((c) => c.id == callId);
    if (index == -1) return false;
    final call = _calls[index];
    final lines = [...call.lines, CallLine(
      speaker: speaker,
      text: text,
      at: at ?? DateTime.now(),
    )];
    while (lines.length > maxLinesPerCall) {
      lines.removeAt(0);
    }
    _calls[index] = CallRecord(
      id: call.id,
      agentId: call.agentId,
      startedAt: call.startedAt,
      endedAt: call.endedAt,
      lines: lines,
    );
    await _save();
    return true;
  }

  /// Ends a call. Returns false when the call id was unknown or
  /// the call was already ended — ending twice does not rewrite
  /// the first end time.
  Future<bool> endCall(String callId, {DateTime? at}) async {
    final index = _calls.indexWhere((c) => c.id == callId);
    if (index == -1) return false;
    final call = _calls[index];
    if (call.endedAt != null) return false;
    _calls[index] = CallRecord(
      id: call.id,
      agentId: call.agentId,
      startedAt: call.startedAt,
      endedAt: at ?? DateTime.now(),
      lines: call.lines,
    );
    await _save();
    return true;
  }

  Future<bool> deleteCall(String callId) async {
    final before = _calls.length;
    _calls.removeWhere((c) => c.id == callId);
    if (_calls.length == before) return false;
    await _save();
    return true;
  }

  Future<void> clearAgent(String agentId) async {
    _calls.removeWhere((c) => c.agentId == agentId);
    await _save();
  }

  Future<void> clearAll() async {
    _calls.clear();
    await _save();
  }
}
