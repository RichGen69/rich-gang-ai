import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/native_bridge.dart';
import '../theme/obsidian.dart';

/// Memory — Milestone 10 plus local recall.
/// "Run dream cycle" calls rga_dream_broadcast in Rust: the daemon
/// advances its tick and returns a factual consolidation report (real
/// tick, real memory count, real stored texts — no invented narration).
/// No audio, no images, nothing autoplays. The search box queries the
/// same local store via rga_recall. Recall is LEXICAL: Rust scores
/// hashed token overlap (cosine over lexical hash vectors), not
/// semantic similarity — there is no embedding model in this build,
/// and the score shown is labelled accordingly.
class DreamBroadcastView extends StatefulWidget {
  const DreamBroadcastView({super.key});

  @override
  State<DreamBroadcastView> createState() => _DreamBroadcastViewState();
}

class _DreamBroadcastViewState extends State<DreamBroadcastView> {
  final _broadcasts = <(int, String)>[]; // (tick, text), newest first
  final _search = TextEditingController();
  List<(String, double)> _hits = const [];
  String? _error;
  bool _busy = false;

  void _runCycle() {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final doc = jsonDecode(NativeBridge().dreamBroadcast())
          as Map<String, dynamic>;
      if (doc['error'] != null) {
        _error = doc['error'].toString();
      } else {
        _broadcasts.insert(
          0,
          ((doc['tick'] as num).toInt(), doc['broadcast'].toString()),
        );
        _error = null;
      }
    } catch (e) {
      _error = 'daemon offline: $e';
    }
    setState(() => _busy = false);
  }

  void _recall() {
    final q = _search.text.trim();
    if (q.isEmpty) return;
    try {
      final doc =
          jsonDecode(NativeBridge().recall(q)) as Map<String, dynamic>;
      final results = (doc['results'] as List<dynamic>? ?? [])
          .map((r) {
            final m = r as Map<String, dynamic>;
            return (m['payload'].toString(), (m['score'] as num).toDouble());
          })
          .toList();
      setState(() => _hits = results);
    } catch (e) {
      setState(() => _error = 'recall failed: $e');
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Memory')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ElevatedButton(
            onPressed: _busy ? null : _runCycle,
            child: const Text('Run dream cycle'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child:
                  Text(_error!, style: const TextStyle(color: Obsidian.red)),
            ),
          const SizedBox(height: 16),
          if (_broadcasts.isEmpty)
            const Text('No broadcasts yet.')
          else
            for (final (tick, text) in _broadcasts)
              Card(
                color: Obsidian.panel,
                child: ListTile(
                  title: Text('Dream cycle $tick'),
                  subtitle: Text(text),
                ),
              ),
          const Divider(height: 32),
          const Text('Recall a memory (lexical match)',
              style: TextStyle(fontWeight: FontWeight.bold)),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                      hintText: 'Search local memories'),
                  onSubmitted: (_) => _recall(),
                ),
              ),
              IconButton(onPressed: _recall, icon: const Icon(Icons.search)),
            ],
          ),
          for (final (payload, score) in _hits)
            ListTile(
              dense: true,
              title: Text(payload),
              trailing: Text(score.toStringAsFixed(2)),
            ),
        ],
      ),
    );
  }
}
