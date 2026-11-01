import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source-surface locks for the Execution Matrix reality work
/// (2026-10-31): every new Rust export must have a Dart binding in
/// NativeBridge, and the bindings must name the exact export. The
/// release gate separately proves every lookup resolves in the
/// staged .so; these tests lock the Dart side of that contract.
void main() {
  test('NativeBridge binds every new Execution Matrix export', () {
    final bridge =
        File('lib/core/native_bridge.dart').readAsStringSync();
    for (final export in [
      'rga_spawn_state',
      'rga_spawn_acquire',
      'rga_spawn_release',
      'rga_intent_state',
      'rga_intent_enqueue',
      'rga_intent_dequeue',
      'rga_reclaim_report',
      'rga_reclaim_delete',
      'rga_reclaim_trim',
    ]) {
      expect(bridge, contains("'$export'"),
          reason: 'missing Dart lookup for $export');
    }
    for (final method in [
      'spawnState()',
      'spawnAcquire()',
      'spawnRelease(',
      'intentState()',
      'intentEnqueue(',
      'intentDequeue()',
      'reclaimReport()',
      'reclaimDelete(',
      'reclaimTrim(',
    ]) {
      expect(bridge, contains(method),
          reason: 'missing Dart wrapper $method');
    }
  });

  test('Rust modules exist for the new surfaces', () {
    for (final module in [
      'spawn_budget.rs',
      'intent_queue.rs',
      'reclaim.rs',
    ]) {
      expect(
          File('../rich_gang_ai_core/src/$module').existsSync(), isTrue,
          reason: 'missing Rust module $module');
    }
  });
}
