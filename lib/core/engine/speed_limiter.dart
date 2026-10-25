import 'dart:async';

/// Task-wide token bucket. `bytesPerSecond <= 0` means unlimited.
///
/// ADM distributes the global limit across connections by sleeping after each
/// read; a shared bucket gives the same observable behaviour while staying
/// fair when the number of connections changes.
class SpeedLimiter {
  SpeedLimiter(int bytesPerSecond)
    : _rate = bytesPerSecond,
      _tokens = bytesPerSecond > 0 ? bytesPerSecond.toDouble() : 0;

  final int _rate;
  double _tokens;
  DateTime _last = DateTime.now();
  bool _waiting = false;

  bool get enabled => _rate > 0;

  Future<void> consume(int bytes) async {
    if (!enabled || bytes <= 0) return;
    final now = DateTime.now();
    final elapsed = now.difference(_last).inMicroseconds / 1000000.0;
    _last = now;
    _tokens += elapsed * _rate;
    final capacity = _rate.toDouble();
    if (_tokens > capacity) _tokens = capacity;
    _tokens -= bytes;
    if (_tokens >= 0) return;

    // Avoid piling up sleeps when several connections go over budget at once.
    if (_waiting) return;
    _waiting = true;
    try {
      final deficit = -_tokens;
      final waitMs = (deficit / _rate * 1000).ceil().clamp(1, 1000);
      await Future.delayed(Duration(milliseconds: waitMs));
      _last = DateTime.now();
      _tokens = 0;
    } finally {
      _waiting = false;
    }
  }
}
