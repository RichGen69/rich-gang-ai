import 'package:flutter/material.dart';

import '../core/tier10_system_controller.dart';
import '../theme/obsidian.dart';

/// Compact Tier-10 telemetry card (2026-10-21), mounted by
/// The Room below its SETUP & HEALTH card.
///
/// This widget takes a real [Tier10SystemController] (fed by
/// InferenceRouter when a caller injects one) and renders only what
/// that controller actually knows:
///
/// - state: cloud synchronized / sovereign edge active / failover
///   testing (recovery probe),
/// - latency: the last MEASURED latency, or "not measured yet" —
///   never a placeholder number,
/// - agents: the count the controller was given from the loaded
///   CharacterRegistry,
/// - failures: the real consecutive-failure count.
///
/// "Sovereign Edge Active" here means the router's fallback path
/// (local Ollama) is active — see tier10_system_controller.dart.
/// No local LLM runtime is linked in this build, and this card does
/// not claim one is running.
class Tier10Hud extends StatelessWidget {
  const Tier10Hud({super.key, required this.controller});

  final Tier10SystemController controller;

  String get _stateLabel => switch (controller.currentState) {
        Tier10ExecutionState.cloudSynchronized => 'Cloud Synchronized',
        Tier10ExecutionState.sovereignEdgeActive =>
          'Sovereign Edge Active (Ollama fallback — no local LLM runtime linked)',
        Tier10ExecutionState.failoverTesting =>
          'Failover Testing (recovery probe)',
      };

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final latency = controller.latencyMs;
        return Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: Obsidian.panel,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Obsidian.gold.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('TIER-10 ROUTING',
                  style: TextStyle(
                      letterSpacing: 2,
                      fontSize: 12,
                      color: Obsidian.gold,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('State: $_stateLabel', style: const TextStyle(fontSize: 12)),
              Text(
                latency == null
                    ? 'Latency: not measured yet'
                    : 'Latency (last measured): '
                        '${latency.toStringAsFixed(1)} ms',
                style: const TextStyle(fontSize: 12),
              ),
              Text(
                  'Configured characters: '
                  '${controller.configuredAgentsCount} • Registry-only: '
                  '${controller.registryOnlyAgentsCount} • Total: '
                  '${controller.activeAgentsCount}',
                  style: const TextStyle(fontSize: 12)),
              Text('Consecutive cloud failures: ${controller.failureCount}',
                  style: const TextStyle(fontSize: 12)),
            ],
          ),
        );
      },
    );
  }
}
