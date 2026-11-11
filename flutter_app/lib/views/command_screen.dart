import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import '../core/native_bridge.dart';
import '../theme/obsidian.dart';

/// Live readings from the Rust daemon, as raw JSON docs. The screen
/// parses each doc at render time; nothing is cached, and no value
/// on screen is ever invented — a doc that cannot be parsed, or
/// that carries an "error" key, renders as an explicit unavailable
/// line with the real reason.
class CommandReadings {
  const CommandReadings({
    required this.daemonVersion,
    required this.spawnJson,
    required this.intentJson,
    required this.reclaimJson,
    required this.ringJson,
    required this.topologyJson,
  });

  final String daemonVersion;
  final String spawnJson;
  final String intentJson;
  final String reclaimJson;
  final String ringJson;
  final String topologyJson;
}

/// The only way the Command screen reaches the daemon. The live
/// implementation calls NativeBridge; tests inject a fake. The seam
/// exists so the honest-behaviour tests can run in this VM, where
/// libdaemon.so cannot be loaded — it is not a mock-data path in
/// the shipped screen: the shipped screen always uses the live one.
abstract class CommandStateSource {
  Future<CommandReadings> read();
}

class LiveCommandStateSource implements CommandStateSource {
  NativeBridge? _bridge;

  NativeBridge get _native => _bridge ??= NativeBridge();

  @override
  Future<CommandReadings> read() async {
    final bridge = _native;
    return CommandReadings(
      daemonVersion: bridge.daemonVersion,
      spawnJson: bridge.spawnState(),
      intentJson: bridge.intentState(),
      reclaimJson: bridge.reclaimReport(),
      ringJson: bridge.ringState(),
      topologyJson: bridge.topologyState(),
    );
  }
}

/// Command — live daemon state (built 2026-11-09, Richard-approved
/// slice). The honest version of the WICK OS Command mockup: every
/// value comes from a live NativeBridge call at refresh time. The
/// mockup's uptime percentage, latency, and error rate are NOT
/// here — the NOT MEASURED strip below says so plainly, because
/// none of those is measured on-device.
class CommandScreen extends StatefulWidget {
  const CommandScreen({super.key, this.source});

  /// Test seam only. The shipped screen passes nothing and reads
  /// the live daemon.
  final CommandStateSource? source;

  @override
  State<CommandScreen> createState() => _CommandScreenState();
}

class _CommandScreenState extends State<CommandScreen> {
  final _liveSource = LiveCommandStateSource();

  CommandStateSource get _source => widget.source ?? _liveSource;

  bool _loading = true;
  String? _error;
  CommandReadings? _readings;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final readings = await _source.read();
      if (!mounted) return;
      setState(() {
        _readings = readings;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Map<String, dynamic>? _doc(String raw) {
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final readings = _readings;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Command — live daemon state'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh live daemon state',
            onPressed: _loading ? null : _refresh,
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          if (readings != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text('Daemon: ${readings.daemonVersion}',
                  style:
                      const TextStyle(fontSize: 12, color: Obsidian.muted)),
            ),
          _notMeasuredStrip(),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Reading live daemon state…'),
            )
          else if (_error != null)
            _errorCard()
          else if (readings != null) ...[
            _spawnSection(readings.spawnJson),
            _intentSection(readings.intentJson),
            _storeSection(readings.reclaimJson),
            _ringSection(readings.ringJson),
            _topologySection(readings.topologyJson),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  /// The anti-mockup label. Mandatory: this screen must never
  /// grow a latency, uptime, or error-rate figure until one is
  /// actually measured on-device.
  Widget _notMeasuredStrip() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Obsidian.panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Obsidian.red.withValues(alpha: 0.6)),
        ),
        child: const Text(
          'NOT MEASURED — this screen shows only live daemon state. '
          'No latency, uptime percentage, or error rate is shown here, '
          'because none of those is measured on-device.',
          style: TextStyle(fontSize: 13, color: Obsidian.cream),
        ),
      ),
    );
  }

  /// Same pattern as the P4-06 chat error card: the real error,
  /// never a generic failure line, with a Retry action.
  Widget _errorCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Card(
        color: Obsidian.panel,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_error ?? 'Unknown daemon error',
                  style:
                      const TextStyle(fontSize: 13, color: Obsidian.red)),
              const SizedBox(height: 8),
              Row(children: [
                TextButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Retry'),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> rows) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: Obsidian.panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Obsidian.gold.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    letterSpacing: 2,
                    fontSize: 12,
                    color: Obsidian.gold,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            ...rows,
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 13, color: Obsidian.muted)),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _note(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(text,
          style: const TextStyle(fontSize: 13, color: Obsidian.muted)),
    );
  }

  /// One section's rows, or a single unavailable line when the
  /// doc cannot be parsed, is missing a field, or carries a real
  /// error from Rust. The section never invents a value to fill
  /// the gap.
  List<Widget> _rowsFor(
    String raw,
    List<Widget> Function(Map<String, dynamic> doc) build,
  ) {
    final doc = _doc(raw);
    if (doc == null) {
      return [_note('Unavailable — the daemon reply could not be parsed.')];
    }
    final error = doc['error'];
    if (error != null) {
      return [_note('Unavailable — $error')];
    }
    return build(doc);
  }

  Widget _spawnSection(String raw) {
    return _section(
      'SPAWN BUDGET',
      _rowsFor(raw, (doc) {
        final max = doc['max'];
        final held = doc['held'];
        final free = doc['free'];
        if (max is! int || held is! int || free is! List) {
          return [
            _note('Unavailable — the spawn reply is missing its fields.')
          ];
        }
        final freeSlots = free.map((s) => s.toString()).join(', ');
        return [
          _row('Slots held', '$held of $max'),
          _row('Free slots', freeSlots.isEmpty ? 'none' : freeSlots),
        ];
      }),
    );
  }

  Widget _intentSection(String raw) {
    return _section(
      'INTENT QUEUE',
      _rowsFor(raw, (doc) {
        final depth = doc['depth'];
        final capacity = doc['capacity'];
        final full = doc['full'];
        if (depth is! int || capacity is! int || full is! bool) {
          return [
            _note('Unavailable — the intent reply is missing its fields.')
          ];
        }
        return [
          _row('Queued', '$depth of $capacity'),
          _row('Full', full ? 'yes' : 'no'),
        ];
      }),
    );
  }

  Widget _storeSection(String raw) {
    return _section(
      'STORE — RECLAIM REPORT',
      _rowsFor(raw, (doc) {
        final entries = doc['entries'];
        final persistent = doc['persistent'];
        final journalMode = doc['journal_mode'];
        final keys = doc['keys'];
        if (entries is! int ||
            persistent is! bool ||
            journalMode is! String ||
            keys is! List) {
          return [
            _note('Unavailable — the store reply is missing its fields.')
          ];
        }
        return [
          _row('Entries', '$entries'),
          _row('Persistent', persistent ? 'yes' : 'no'),
          _row('Journal mode', journalMode),
          _row('Keys in report', '${keys.length}'),
        ];
      }),
    );
  }

  Widget _ringSection(String raw) {
    return _section(
      'RING — SHARED MEMORY',
      _rowsFor(raw, (doc) {
        final enabled = doc['enabled'];
        if (enabled is! bool) {
          return [
            _note('Unavailable — the ring reply is missing its fields.')
          ];
        }
        if (!enabled) {
          return [
            _note('No ring configured — the daemon config named no '
                'ring_path, so there is no ring at all.')
          ];
        }
        final capacity = doc['capacity'];
        final pendingBytes = doc['pending_bytes'];
        final pendingMessages = doc['pending_messages'];
        if (capacity is! int ||
            pendingBytes is! int ||
            pendingMessages is! int) {
          return [
            _note('Unavailable — the ring reply is missing its fields.')
          ];
        }
        return [
          _row('Capacity', '$capacity bytes'),
          _row('Pending', '$pendingMessages messages ($pendingBytes bytes)'),
        ];
      }),
    );
  }

  Widget _topologySection(String raw) {
    return _section(
      'TOPOLOGY — CAUSAL STATE',
      _rowsFor(raw, (doc) {
        final nodes = doc['nodes'];
        final edges = doc['edges'];
        final order = doc['order'];
        if (nodes is! int || edges is! int || order is! List) {
          return [
            _note('Unavailable — the topology reply is missing its fields.')
          ];
        }
        final names = order.map((o) => o.toString()).toList();
        final shown = names.length > 8
            ? '${names.take(8).join(' → ')} … (${names.length} total)'
            : names.join(' → ');
        return [
          _row('Nodes', '$nodes'),
          _row('Edges', '$edges'),
          if (shown.isNotEmpty) _row('Order', shown),
        ];
      }),
    );
  }
}
