/// Real-time awareness for the agents.
///
/// A character that doesn't know what time it is, how long you've
/// been talking, or that you were gone for three days does not feel
/// present. This service builds the agent's temporal context from
/// the REAL device clock at the moment of the prompt — nothing is
/// cached from build time, and nothing is estimated:
///
/// - now (clock + date + weekday, from the OS calendar),
/// - part of day (morning / afternoon / evening / late night),
/// - session elapsed time (Richard's Nexus frame shows a live
///   SESSION timer — this is the data behind that readout),
/// - time since the agent last interacted (from the persisted
///   self-model; "first conversation ever" when there is none).
class TimeContext {
  const TimeContext({
    required this.now,
    required this.sessionStartedAt,
    required this.lastInteractionAt,
  });

  final DateTime now;
  final DateTime? sessionStartedAt;
  final DateTime? lastInteractionAt;

  static const _weekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday',
    'Saturday', 'Sunday',
  ];
  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July',
    'August', 'September', 'October', 'November', 'December',
  ];

  String get daySegment {
    final h = now.hour;
    if (h < 5) return 'late night';
    if (h < 12) return 'morning';
    if (h < 17) return 'afternoon';
    if (h < 22) return 'evening';
    return 'late night';
  }

  String get clockLine {
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    return '$hh:$mm on ${_weekdays[now.weekday - 1]}, '
        '${_months[now.month - 1]} ${now.day}, ${now.year}';
  }

  Duration? get sessionElapsed =>
      sessionStartedAt == null ? null : now.difference(sessionStartedAt!);

  Duration? get sinceLastInteraction => lastInteractionAt == null
      ? null
      : now.difference(lastInteractionAt!);

  static String humanDuration(Duration d) {
    if (d.inDays >= 2) return '${d.inDays} days';
    if (d.inDays == 1) return 'a day';
    if (d.inHours >= 2) return '${d.inHours} hours';
    if (d.inHours == 1) return 'an hour';
    if (d.inMinutes >= 2) return '${d.inMinutes} minutes';
    if (d.inMinutes == 1) return 'a minute';
    return 'moments';
  }

  /// The block injected into prompts. Every line is computed from
  /// the values above; a missing value omits its line rather than
  /// guessing.
  String promptBlock() {
    final lines = <String>[
      'REAL-TIME AWARENESS: It is $clockLine ($daySegment). '
          'You know the current time and date; use them naturally '
          'when relevant and never claim a different time.',
    ];
    final elapsed = sessionElapsed;
    if (elapsed != null) {
      lines.add('This session has been running for '
          '${humanDuration(elapsed)}.');
    }
    final gap = sinceLastInteraction;
    if (lastInteractionAt == null) {
      lines.add(
          'This is your first recorded interaction in this memory.');
    } else if (gap != null && gap.inMinutes >= 30) {
      lines.add('Richard last spoke with this room '
          '${humanDuration(gap)} ago — you noticed the gap.');
    }
    return lines.join(' ');
  }
}

/// Session clock for the app: one start instant per process run.
class SessionClock {
  SessionClock._();
  static final DateTime startedAt = DateTime.now();
  static TimeContext context({DateTime? lastInteractionAt}) =>
      TimeContext(
        now: DateTime.now(),
        sessionStartedAt: startedAt,
        lastInteractionAt: lastInteractionAt,
      );
}
