/// Client-side sliding-window limiter for the NVIDIA endpoint.
/// Cap 38 RPM: 2 under the ~40 RPM free-tier ceiling for headroom
/// (terms are not published as a hard contract - see docs/VERIFY.md).
class RpmLimiter {
  RpmLimiter({this.cap = 38, this.window = const Duration(seconds: 60)});

  final int cap;
  final Duration window;
  final List<DateTime> _hits = <DateTime>[];

  /// Records a call if budget remains. When this returns false the caller
  /// must route to Ollama BEFORE making the NVIDIA call.
  bool acquire() {
    final now = DateTime.now();
    _hits.removeWhere((t) => now.difference(t) >= window);
    if (_hits.length >= cap) return false;
    _hits.add(now);
    return true;
  }
}
