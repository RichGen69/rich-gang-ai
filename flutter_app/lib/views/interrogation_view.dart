import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/lie_detector.dart';
import '../core/native_bridge.dart';
import '../theme/obsidian.dart';

/// Interrogation — Milestone 9, playable, FULLY DATA-DRIVEN.
///
/// This view contains no scene content of its own: no witness names, no
/// questions, no contradictions, no win condition tied to a story. The
/// witnesses, their facts, and every statement come from the Rust fact
/// table (rga_witnesses / rga_witness_facts / rga_witness_statement),
/// which is loaded from the daemon config's "facts" key — scene data
/// Richard supplies (docs/SCENE_FORMAT.md). The assistant-authored
/// built-in scene was removed 2026-10-21 under his no-mock-data rule.
///
/// With no scene loaded, this view shows its empty state. Play consists
/// of collecting statements; contradiction-spotting is the player's
/// job, cross-referencing the transcript — the app invents nothing.
///
/// LIE DETECTOR (2026-10-23): below the interrogation, the detector
/// surface (core/lie_detector.dart). Statements collected in play are
/// run through it automatically, and any statement can be checked
/// manually. Its labelling line is shown verbatim: it detects
/// contradictions against recorded facts and the speaker's own prior
/// statements — it cannot detect lies that leave no contradiction,
/// and it reads no body signals. No gauges, no needles, no scores:
/// per-claim verdicts with the cited fact or prior statement, and a
/// credibility ledger of plain counts.
class InterrogationView extends StatefulWidget {
  const InterrogationView({super.key});

  @override
  State<InterrogationView> createState() => _InterrogationViewState();
}

class _InterrogationViewState extends State<InterrogationView> {
  List<String> _witnesses = const [];
  String? _witness;
  final _known = <String, List<String>>{}; // witness -> fact ids loaded
  final _asked = <String>{}; // "witness:factId"
  final _transcript = <String>[];
  String? _error;
  bool _loaded = false;

  // Lie Detector state: the shared service (booted with the mind
  // store, acquired lazily here if that boot never ran), the last
  // readout, and the manual-check form.
  LieDetector? _detector;
  StatementReport? _lastReport;
  final _speakerCtrl = TextEditingController();
  final _statementCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    try {
      final doc =
          jsonDecode(NativeBridge().witnesses()) as Map<String, dynamic>;
      _witnesses = ((doc['witnesses'] as List<dynamic>?) ?? const [])
          .map((e) => e.toString())
          .toList();
      for (final w in _witnesses) {
        final fdoc = jsonDecode(NativeBridge().witnessFacts(w))
            as Map<String, dynamic>;
        _known[w] = ((fdoc['facts'] as List<dynamic>?) ?? const [])
            .map((f) => (f as Map<String, dynamic>)['id'] as String)
            .toList();
      }
      if (_witnesses.isNotEmpty) _witness = _witnesses.first;
    } catch (e) {
      _error = 'daemon offline: $e';
    }
    _loaded = true;
    unawaited(_acquireDetector());
  }

  @override
  void dispose() {
    _speakerCtrl.dispose();
    _statementCtrl.dispose();
    super.dispose();
  }

  Future<void> _acquireDetector() async {
    final d = await LieDetector.acquire();
    // The daemon is up by the time a view opens (main.dart boots
    // it before runApp), so refresh the fact table now — the
    // detector's boot-time table may predate the daemon.
    d.refreshFacts();
    if (!mounted) return;
    setState(() {
      _detector = d;
      if (_speakerCtrl.text.isEmpty && _witness != null) {
        _speakerCtrl.text = _witness!;
      }
    });
  }

  /// Run a statement through the detector and keep the readout.
  /// The check itself is synchronous and deterministic; only the
  /// record's save is async, and it is fire-and-forget by the
  /// service's own best-effort discipline.
  StatementReport? _runDetector(String speaker, String text) {
    final d = _detector;
    if (d == null) return null;
    final report = d.checkStatement(speaker: speaker, text: text);
    unawaited(d.save());
    return report;
  }

  void _checkManual() {
    final speaker = _speakerCtrl.text.trim();
    final text = _statementCtrl.text.trim();
    if (speaker.isEmpty || text.isEmpty) return;
    final report = _runDetector(speaker, text);
    if (report == null) return;
    setState(() {
      _lastReport = report;
      _statementCtrl.clear();
    });
  }

  void _ask(String factId) {
    final w = _witness;
    if (w == null) return;
    final key = '$w:$factId';
    if (_asked.contains(key)) return;
    try {
      final doc = jsonDecode(NativeBridge().witnessStatement(w, factId))
          as Map<String, dynamic>;
      if (doc['error'] != null) {
        setState(() => _transcript.add('$w: I don\'t know anything about that.'));
        return;
      }
      final stmt = doc['statement'].toString();
      // Statements collected in play go through the detector as
      // this witness's statements — checked against the fact
      // table and against everything they said before.
      final report = _runDetector(w, stmt);
      setState(() {
        _asked.add(key);
        _transcript.add('${w.toUpperCase()}: $stmt');
        if (report != null) _lastReport = report;
      });
    } catch (e) {
      setState(() => _transcript.add('error: $e'));
    }
  }

  int get _totalFacts =>
      _known.values.fold(0, (sum, facts) => sum + facts.length);
  bool get _complete =>
      _totalFacts > 0 && _asked.length >= _totalFacts;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Interrogation')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Obsidian.red)),
          if (_loaded && _error == null && _witnesses.isEmpty) ...[
            const Text('No interrogation scene is loaded.',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Obsidian.goldBright)),
            const SizedBox(height: 8),
            const Text(
                'This mode runs entirely on scene data supplied in the '
                'daemon config ("facts" key, loaded from '
                'assets/daemon_config.json). No scene ships built into '
                'the app, and nothing here is pre-filled. Add your scene '
                'data — format in docs/SCENE_FORMAT.md — and restart the '
                'app to play it.'),
          ],
          if (_witnesses.isNotEmpty && _witness != null) ...[
            SegmentedButton<String>(
              segments: [
                for (final w in _witnesses)
                  ButtonSegment(value: w, label: Text(w)),
              ],
              selected: {_witness!},
              onSelectionChanged: (v) => setState(() => _witness = v.first),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final id in _known[_witness] ?? const <String>[])
                  ActionChip(
                    label: Text('Ask about ${id.replaceAll('_', ' ')}'),
                    onPressed: _asked.contains('$_witness:$id')
                        ? null
                        : () => _ask(id),
                  ),
              ],
            ),
            const Divider(height: 32),
            for (final line in _transcript) Text(line),
            const Divider(height: 32),
            Text(
              _complete
                  ? 'All statements collected (${_asked.length} of '
                      '$_totalFacts). Cross-reference the transcript — '
                      'any contradictions are in what they told you.'
                  : 'Statements collected: ${_asked.length} of $_totalFacts.',
              style: const TextStyle(
                  color: Obsidian.goldBright, fontWeight: FontWeight.bold),
            ),
          ],
          // ---- Lie Detector -------------------------------------
          const Divider(height: 40),
          const Text('Lie Detector',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Obsidian.goldBright,
                  fontSize: 18)),
          const SizedBox(height: 4),
          const Text(LieDetector.labellingLine),
          const SizedBox(height: 8),
          if (_detector == null)
            const Text('Loading the statement record…')
          else if (!_detector!.hasFacts)
            const Text(
                'NO FACTS AVAILABLE — the daemon holds no recorded '
                'witness facts (no scene data supplied), so fact '
                'checks are idle. Statements are still recorded and '
                'checked against each speaker\'s own prior '
                'statements.'),
          if (_detector != null) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _speakerCtrl,
              decoration: const InputDecoration(
                  labelText: 'Speaker',
                  hintText: 'Who said it — a witness name, or any name'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _statementCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: 'Statement to check',
                  hintText: 'What they said, verbatim'),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: _checkManual,
                child: const Text('Check statement'),
              ),
            ),
          ],
          if (_lastReport != null) ...[
            const Divider(height: 32),
            Text(_lastReport!.readout()),
          ],
          if (_detector != null && _detector!.speakers.isNotEmpty) ...[
            const Divider(height: 32),
            const Text('Credibility ledger',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Obsidian.goldBright)),
            const Text('A consistency history — the running counts '
                'of each speaker\'s checked claims over the retained '
                'record. Not a lie probability, not a trust score.'),
            const SizedBox(height: 4),
            for (final c in _detector!.allCredibility) Text(c.describe()),
          ],
        ],
      ),
    );
  }
}
