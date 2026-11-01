import 'package:flutter_displaymode/flutter_displaymode.dart';

enum ThermalState { nominal, fair, serious, severe, critical }

/// Frame-rate policy: steady beats high.
/// Default 60 FPS. Cinematic = 30 FPS (user setting). Thermal Severe or
/// Critical drops to 30 automatically, without notifying the user.
/// Never 120.
///
/// ACTUAL SOLUTION (docs/VERIFY.md) — the API previously quoted for this,
/// `RefreshRate.setPreferredRate`, does not exist in any package.
/// The real, verified API is package `flutter_displaymode`:
///   `FlutterDisplayMode.supported`  -> Future<List<DisplayMode>>
///   `FlutterDisplayMode.active`     -> Future<DisplayMode>
///   `FlutterDisplayMode.setPreferredMode(DisplayMode)`
///   `FlutterDisplayMode.setLowRefreshRate()`
/// The hint is advisory — the OS may ignore it. The UI must look correct
/// at 30, 60 and 90 FPS.
class RoomRateController {
  int _target = 60;
  int get target => _target;

  ThermalState _lastThermal = ThermalState.nominal;
  ThermalState get lastThermal => _lastThermal;

  bool get shadersSuspendedForThermal =>
      _lastThermal == ThermalState.severe ||
      _lastThermal == ThermalState.critical;

  /// Apply a target frame rate (only 30 or 60 are ever requested).
  ///
  /// Mode selection, in order:
  /// 1. A supported mode at the ACTIVE mode's resolution whose refresh
  ///    rate rounds to the target. (Picking by rate alone — the earlier
  ///    draft — could silently switch the display resolution.)
  /// 2. Any supported mode whose refresh rate rounds to the target.
  /// 3. For 30 FPS only, `setLowRefreshRate()` as a last resort.
  /// A mode above 60 Hz is never selected, even if the panel offers one.
  Future<void> apply(int fps) async {
    _target = fps <= 30 ? 30 : 60;
    try {
      final modes = await FlutterDisplayMode.supported;
      final usable = modes
          .where((m) => m.refreshRate > 0 && m.refreshRate.round() <= 60)
          .toList();
      final atTarget =
          usable.where((m) => m.refreshRate.round() == _target).toList();
      if (atTarget.isNotEmpty) {
        DisplayMode chosen = atTarget.first;
        try {
          final active = await FlutterDisplayMode.active;
          final sameRes = atTarget.where(
              (m) => m.width == active.width && m.height == active.height);
          if (sameRes.isNotEmpty) chosen = sameRes.first;
        } catch (_) {
          // Active mode unknown: the rate-only match above still stands.
        }
        await FlutterDisplayMode.setPreferredMode(chosen);
      } else if (_target == 30) {
        await FlutterDisplayMode.setLowRefreshRate();
      }
    } catch (_) {
      // Advisory only. Failing to hint is not an app failure.
    }
  }

  /// Silent thermal fallback — no notification, no dialog. The room calms.
  /// Records the state so shader/ambient suspension (same thresholds in
  /// the spec) reads the same source of truth.
  Future<void> onThermal(ThermalState state) async {
    _lastThermal = state;
    if (state == ThermalState.severe || state == ThermalState.critical) {
      await apply(30);
    }
  }
}
