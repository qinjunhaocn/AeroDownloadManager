import 'dart:math' as math;

/// Human readable byte size, e.g. `12.4 MB`.
String formatBytes(num bytes, {int decimals = 1}) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final digits = unit == 0 ? 0 : decimals;
  return '${value.toStringAsFixed(digits)} ${units[unit]}';
}

String formatSpeed(num bytesPerSecond) {
  if (bytesPerSecond <= 0) return '0 B/s';
  return '${formatBytes(bytesPerSecond)}/s';
}

String formatDuration(num milliseconds) {
  if (milliseconds <= 0 || milliseconds.isNaN) return '—';
  final totalSeconds = (milliseconds / 1000).round();
  if (totalSeconds < 1) return '<1s';
  final seconds = totalSeconds % 60;
  final minutes = (totalSeconds ~/ 60) % 60;
  final hours = totalSeconds ~/ 3600;
  if (hours > 0) {
    return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
  }
  if (minutes > 0) {
    return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
  }
  return '${seconds}s';
}

String formatPercent(double fraction) {
  if (fraction.isNaN) return '0%';
  final percent = (fraction.clamp(0.0, 1.0) * 100);
  if (percent >= 100) return '100%';
  return '${percent.toStringAsFixed(percent < 10 ? 1 : 0)}%';
}

String formatDateTime(DateTime? time) {
  if (time == null) return '—';
  String two(int v) => v.toString().padLeft(2, '0');
  return '${time.year}-${two(time.month)}-${two(time.day)} '
      '${two(time.hour)}:${two(time.minute)}';
}

/// ETA for a download. Returns null when it cannot be estimated.
Duration? etaFor(int remainingBytes, double bytesPerSecond) {
  if (remainingBytes <= 0 || bytesPerSecond <= 0) return null;
  final seconds = remainingBytes / bytesPerSecond;
  if (seconds.isInfinite || seconds > const Duration(days: 30).inSeconds) {
    return null;
  }
  return Duration(milliseconds: (seconds * 1000).round());
}

String shortPath(String path, {int max = 48}) {
  if (path.length <= max) return path;
  return '…${path.substring(path.length - math.min(max, path.length - 1))}';
}

String formatCount(int value) {
  if (value < 1000) return '$value';
  if (value < 1000000) return '${(value / 1000).toStringAsFixed(1)}k';
  return '${(value / 1000000).toStringAsFixed(1)}M';
}
