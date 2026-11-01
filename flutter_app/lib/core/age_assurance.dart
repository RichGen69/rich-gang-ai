import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'character.dart';

/// Fail-closed age-assurance states from
/// `docs/AGE_ASSURANCE_DESIGN_2026-10-23.md`.
///
/// A stored record is not enough by itself: authorisation also
/// requires that a real vendor/method was configured when the
/// snapshot was loaded. This build configures no vendor, so every
/// 21+ character remains locked even if an old confirmation value
/// or a hand-written record is present.
enum AgeAssuranceState {
  unknown,
  verificationRequired,
  pending,
  verifiedAdult,
  denied,
  unavailable,
}

/// Immutable snapshot of the one age-assurance boundary.
///
/// Only the minimal record from the design is persisted: state,
/// verification time, vendor id, and an opaque vendor reference.
/// Date of birth and identity documents are never stored here.
class AgeAssurance {
  const AgeAssurance({
    required this.state,
    required this.vendorConfigured,
    this.verifiedAt,
    this.vendorId,
    this.vendorReference,
  });

  static const String preferenceKey = 'age_assurance_v1';

  final AgeAssuranceState state;
  final bool vendorConfigured;
  final DateTime? verifiedAt;
  final String? vendorId;
  final String? vendorReference;

  /// The only authorisation decision views and send paths may use.
  bool isAuthorised(CharacterDef character) {
    if (!character.ageGated) return true;
    return vendorConfigured &&
        state == AgeAssuranceState.verifiedAdult &&
        (vendorId ?? '').isNotEmpty;
  }

  static AgeAssuranceState _stateFromName(Object? value) {
    if (value is! String) return AgeAssuranceState.unavailable;
    for (final state in AgeAssuranceState.values) {
      if (state.name == value) return state;
    }
    return AgeAssuranceState.unavailable;
  }

  /// Load the stored record. [vendorConfigured] defaults to false
  /// because this build ships no verified age-assurance vendor.
  static Future<AgeAssurance> load({
    bool vendorConfigured = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(preferenceKey);
    if (raw == null || raw.isEmpty) {
      return AgeAssurance(
        state: vendorConfigured
            ? AgeAssuranceState.verificationRequired
            : AgeAssuranceState.unavailable,
        vendorConfigured: vendorConfigured,
      );
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return AgeAssurance(
          state: AgeAssuranceState.unavailable,
          vendorConfigured: vendorConfigured,
        );
      }
      final verifiedAtRaw = decoded['verified_at'];
      return AgeAssurance(
        state: _stateFromName(decoded['state']),
        vendorConfigured: vendorConfigured,
        verifiedAt:
            verifiedAtRaw is String ? DateTime.tryParse(verifiedAtRaw) : null,
        vendorId: decoded['vendor_id'] is String
            ? decoded['vendor_id'] as String
            : null,
        vendorReference: decoded['vendor_reference'] is String
            ? decoded['vendor_reference'] as String
            : null,
      );
    } catch (_) {
      return AgeAssurance(
        state: AgeAssuranceState.unavailable,
        vendorConfigured: vendorConfigured,
      );
    }
  }

  /// Persist a completed vendor verification. This is deliberately
  /// not called by any confirmation dialog in this build: no vendor
  /// flow exists yet, and a self-confirmation must never write this
  /// record.
  static Future<void> recordVerifiedForVendor({
    required String vendorId,
    required String vendorReference,
    required DateTime verifiedAt,
  }) async {
    if (vendorId.isEmpty || vendorReference.isEmpty) {
      throw ArgumentError('vendor verification requires an id and reference');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      preferenceKey,
      jsonEncode(<String, Object?>{
        'state': AgeAssuranceState.verifiedAdult.name,
        'verified_at': verifiedAt.toUtc().toIso8601String(),
        'vendor_id': vendorId,
        'vendor_reference': vendorReference,
      }),
    );
  }

  static Future<void> clearStoredRecord() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(preferenceKey);
  }
}
