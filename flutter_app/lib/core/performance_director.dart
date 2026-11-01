/// Performance Director (build order step 3): translates the scene's
/// last ACCEPTED AffectFrame Delta — read live from Rust via
/// `rga_scene_state`, never invented here — into presentation
/// parameters for The Room.
///
/// Pure function of its inputs, so the mapping is testable and the
/// Room stays a dumb renderer. The restraint layer outranks the
/// performance: quiet hours and the kill switch force a dim, static
/// room no matter what the scene asks for, and reduced motion zeroes
/// shake outright.
class RoomPresentation {
  const RoomPresentation({
    required this.opacity,
    required this.shake,
    required this.summary,
  });

  /// Room opacity from the performance state (thermal dimming in
  /// The Room composes with this via min()).
  final double opacity;

  /// Camera-shake intensity the scene requested, after gating.
  /// 0 whenever motion is not allowed.
  final double shake;

  /// One factual line for the UI: the real light/affect values, or
  /// the reason the performance is at baseline / suspended.
  final String summary;
}

abstract final class PerformanceDirector {
  /// Light -> base opacity. The Delta's light was already validated
  /// against the Rust whitelist (warm|cold|dim|bright|neutral).
  static const _lightOpacity = <String, double>{
    'warm': 1.0,
    'bright': 1.0,
    'neutral': 0.95,
    'cold': 0.9,
    'dim': 0.7,
  };

  static RoomPresentation direct({
    required Map<String, dynamic>? sceneState,
    required bool quietHours,
    required bool killed,
    required bool reducedMotion,
  }) {
    if (killed) {
      return const RoomPresentation(
        opacity: 0.6,
        shake: 0,
        summary: 'Performance suspended — kill switch is on.',
      );
    }
    final delta = sceneState?['last_delta'];
    if (delta is! Map<String, dynamic>) {
      return const RoomPresentation(
        opacity: 1.0,
        shake: 0,
        summary: 'Performance: baseline — no frames accepted yet.',
      );
    }
    final stage = delta['stage'];
    final affect = delta['affect'];
    final light = stage is Map<String, dynamic> ? stage['light'] : null;
    var opacity = _lightOpacity[light] ?? 1.0;
    var shake = 0.0;
    if (stage is Map<String, dynamic> && stage['shake'] is num) {
      shake = (stage['shake'] as num).toDouble().clamp(0.0, 1.0);
    }
    if (reducedMotion) shake = 0;

    var suffix = '';
    if (quietHours) {
      // Canon: during quiet hours the room goes dim and static.
      opacity = opacity < 0.6 ? opacity : 0.6;
      shake = 0;
      suffix = ' (quiet hours — dimmed, static)';
    }

    String fmt(Object? v) =>
        v is num ? v.toDouble().toStringAsFixed(2) : '?';
    final valence = affect is Map<String, dynamic> ? affect['valence'] : null;
    final arousal = affect is Map<String, dynamic> ? affect['arousal'] : null;
    final accepted = sceneState?['accepted'];
    return RoomPresentation(
      opacity: opacity,
      shake: shake,
      summary: 'Performance: light=$light · valence ${fmt(valence)} · '
          'arousal ${fmt(arousal)} · frames $accepted$suffix',
    );
  }
}
