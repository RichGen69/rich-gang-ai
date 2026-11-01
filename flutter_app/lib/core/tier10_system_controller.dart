import 'package:flutter/foundation.dart';

import 'character.dart';

/// Execution state of the cloud/edge routing layer, mirroring the
/// Rust circuit breaker (rich_gang_ai_core/src/circuit_breaker.rs):
/// Closed ≈ [cloudSynchronized], Open ≈ [sovereignEdgeActive],
/// HalfOpen ≈ [failoverTesting].
enum Tier10ExecutionState {
  cloudSynchronized,
  sovereignEdgeActive,
  failoverTesting,
}

/// Telemetry for the Tier-10 routing layer — REAL measurements only
/// (Richard's standing rule: no mock data).
///
/// - [latencyMs] starts NULL: no latency has been measured yet, and
///   the UI must say exactly that. It is only ever set from a
///   [Duration] a caller actually measured around a real call. The
///   pasted Tier-10 snippets hardcoded 12.4 / 1.2 ms — those numbers
///   were invented and are deliberately NOT reproduced here.
/// - [activeAgentsCount] is supplied by the caller from the loaded
///   [CharacterRegistry] (see [Tier10SystemController.fromRegistry]);
///   it is never a hardcoded roster literal.
/// - There is no local edge LLM runtime in this build (Rust
///   edge_inference.rs returns an explicit error), so
///   [sovereignEdgeActive] means "cloud marked failed; the router's
///   fallback — local Ollama — is the active path", NOT "on-device
///   weights are running". The state is named for Richard's spec;
///   this comment and the HUD copy keep that distinction visible.
class Tier10SystemController extends ChangeNotifier {
  Tier10SystemController({
    int activeAgentsCount = 0,
    int configuredAgentsCount = 0,
    int registryOnlyAgentsCount = 0,
    this.failureThreshold = 3,
  })  : _activeAgentsCount = activeAgentsCount,
        _configuredAgentsCount = configuredAgentsCount,
        _registryOnlyAgentsCount = registryOnlyAgentsCount;

  /// Build a controller whose agent count comes from a real loaded
  /// registry — the only honest source for the number.
  factory Tier10SystemController.fromRegistry(
    CharacterRegistry registry, {
    int failureThreshold = 3,
  }) =>
      Tier10SystemController(
        activeAgentsCount: registry.all.length,
        configuredAgentsCount: registry.all.where((c) => c.isConfigured).length,
        registryOnlyAgentsCount:
            registry.all.where((c) => c.isRegistryOnly).length,
        failureThreshold: failureThreshold,
      );

  /// Consecutive cloud failures (or >250 ms latency signals, the
  /// Rust breaker's threshold) that trip the state to edge.
  final int failureThreshold;

  Tier10ExecutionState _currentState = Tier10ExecutionState.cloudSynchronized;
  double? _latencyMs;
  Object? _lastError;
  int _activeAgentsCount;
  int _configuredAgentsCount;
  int _registryOnlyAgentsCount;
  int _failureCount = 0;

  Tier10ExecutionState get currentState => _currentState;

  /// Last MEASURED cloud latency in milliseconds, or null when no
  /// call has been measured yet.
  double? get latencyMs => _latencyMs;

  int get activeAgentsCount => _activeAgentsCount;
  int get configuredAgentsCount => _configuredAgentsCount;
  int get registryOnlyAgentsCount => _registryOnlyAgentsCount;
  int get failureCount => _failureCount;
  Object? get lastError => _lastError;

  bool get isEdgeActive =>
      _currentState == Tier10ExecutionState.sovereignEdgeActive;

  /// Update the agent count when a registry (re)loads.
  void updateAgentCount(int count) {
    if (count == _activeAgentsCount) return;
    _activeAgentsCount = count;
    notifyListeners();
  }

  /// Update the total and disposition counts from one loaded
  /// registry, so the HUD cannot present the registry total as a
  /// configured/ready count.
  void updateRegistryCounts({
    required int total,
    required int configured,
    required int registryOnly,
  }) {
    if (total == _activeAgentsCount &&
        configured == _configuredAgentsCount &&
        registryOnly == _registryOnlyAgentsCount) {
      return;
    }
    _activeAgentsCount = total;
    _configuredAgentsCount = configured;
    _registryOnlyAgentsCount = registryOnly;
    notifyListeners();
  }

  /// Record a cloud call that succeeded, with the latency the
  /// caller actually measured. A latency above 250 ms is a failure
  /// SIGNAL (same rule as the Rust breaker): it is recorded as the
  /// measurement, and it increments the failure count instead of
  /// clearing it.
  void recordCloudSuccess(Duration latency) {
    _latencyMs = latency.inMicroseconds / 1000.0;
    if (latency.inMilliseconds > 250) {
      _failureCount++;
      if (_failureCount >= failureThreshold) {
        _currentState = Tier10ExecutionState.sovereignEdgeActive;
      }
      notifyListeners();
      return;
    }
    _failureCount = 0;
    _lastError = null;
    if (_currentState == Tier10ExecutionState.failoverTesting) {
      _currentState = Tier10ExecutionState.cloudSynchronized;
    }
    notifyListeners();
  }

  /// Record a cloud failure. Trips to the edge state once the
  /// failure threshold is reached; a failure during a recovery
  /// probe sends the state straight back to edge.
  void recordCloudFailure(Object error) {
    _lastError = error;
    _failureCount++;
    if (_currentState == Tier10ExecutionState.failoverTesting ||
        _failureCount >= failureThreshold) {
      _currentState = Tier10ExecutionState.sovereignEdgeActive;
    }
    notifyListeners();
  }

  /// Trip to the edge/fallback path immediately (e.g. the router
  /// fell back to local Ollama, or an operator forced it).
  void tripToEdge() {
    if (_currentState == Tier10ExecutionState.sovereignEdgeActive) {
      return;
    }
    _currentState = Tier10ExecutionState.sovereignEdgeActive;
    notifyListeners();
  }

  /// Begin probing cloud recovery from the edge state (the Rust
  /// breaker's HalfOpen). No-op from any other state.
  void beginRecoveryProbe() {
    if (_currentState != Tier10ExecutionState.sovereignEdgeActive) {
      return;
    }
    _currentState = Tier10ExecutionState.failoverTesting;
    notifyListeners();
  }

  /// Mark cloud as restored: back to synchronized, failures cleared.
  void restoreCloud() {
    _failureCount = 0;
    _lastError = null;
    if (_currentState == Tier10ExecutionState.cloudSynchronized) {
      notifyListeners();
      return;
    }
    _currentState = Tier10ExecutionState.cloudSynchronized;
    notifyListeners();
  }
}
