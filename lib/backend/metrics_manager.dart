import 'dart:async';

import 'package:flutter/foundation.dart';

typedef HealthEventCallback = Future<void> Function({
required String eventType,
required DateTime startedAt,
required DateTime endedAt,
required double durationSeconds,
});

class MetricsManager extends ChangeNotifier {
  static final MetricsManager _instance = MetricsManager._internal();

  factory MetricsManager() => _instance;

  MetricsManager._internal();

  static const Duration minimumRecordedEventDuration =
  Duration(milliseconds: 1500);

  final Map<String, Stopwatch> _timers = {
    'tooClose': Stopwatch(),
    'hunch': Stopwatch(),
    'neck': Stopwatch(),
    'wrist': Stopwatch(),
    'lowLight': Stopwatch(),
  };

  final Map<String, Duration> _accumulated = {
    'tooClose': Duration.zero,
    'hunch': Duration.zero,
    'neck': Duration.zero,
    'wrist': Duration.zero,
    'lowLight': Duration.zero,
  };

  final Map<String, DateTime?> _startedAt = {
    'tooClose': null,
    'hunch': null,
    'neck': null,
    'wrist': null,
    'lowLight': null,
  };

  final Stopwatch _screenTime = Stopwatch();

  HealthEventCallback? _onHealthEvent;

  void setHealthEventCallback(HealthEventCallback? callback) {
    _onHealthEvent = callback;
  }

  String _getEventType(String type) {
    switch (type) {
      case 'tooClose':
        return 'too_close';
      case 'lowLight':
        return 'low_light';
      case 'hunch':
        return 'hunch';
      case 'neck':
        return 'neck';
      case 'wrist':
        return 'wrist';
      default:
        return type;
    }
  }

  void start(String type) {
    final timer = _timers[type];
    if (timer == null || timer.isRunning) {
      return;
    }

    timer
      ..reset()
      ..start();

    _startedAt[type] = DateTime.now().toUtc();
    notifyListeners();
  }

  Future<void> stop(String type) async {
    final timer = _timers[type];

    if (timer == null || !timer.isRunning) {
      return;
    }

    timer.stop();

    final elapsed = timer.elapsed;
    final startedAt = _startedAt[type];
    final endedAt = DateTime.now().toUtc();

    timer.reset();
    _startedAt[type] = null;

    // Very short detector flickers are not meaningful monitoring events.
    // They are intentionally excluded from both totals and persistence.
    if (elapsed < minimumRecordedEventDuration) {
      notifyListeners();
      return;
    }

    _accumulated[type] = _accumulated[type]! + elapsed;

    if (startedAt != null && _onHealthEvent != null) {
      final durationSeconds = elapsed.inMilliseconds / 1000.0;

      try {
        await _onHealthEvent!(
          eventType: _getEventType(type),
          startedAt: startedAt,
          endedAt: endedAt,
          durationSeconds: durationSeconds,
        );

        debugPrint(
          '[MetricsManager] Queued event: '
              '${_getEventType(type)} '
              '${durationSeconds.toStringAsFixed(3)}s',
        );
      } catch (e, stackTrace) {
        debugPrint('[MetricsManager] Failed to queue health event: $e');
        debugPrint('$stackTrace');
      }
    }

    notifyListeners();
  }

  Future<void> flushActiveEvents() async {
    final activeTypes = _timers.entries
        .where((entry) => entry.value.isRunning)
        .map((entry) => entry.key)
        .toList();

    for (final type in activeTypes) {
      await stop(type);
    }
  }

  bool isActive(String type) => _timers[type]?.isRunning ?? false;

  void startScreenTime() {
    if (!_screenTime.isRunning) {
      _screenTime.start();
      notifyListeners();
    }
  }

  void stopScreenTime() {
    if (_screenTime.isRunning) {
      _screenTime.stop();
      notifyListeners();
    }
  }

  Duration getScreenTime() => _screenTime.elapsed;

  Map<String, Duration> getDailyReport() {
    final report = <String, Duration>{};

    for (final key in _accumulated.keys) {
      final running = _timers[key]?.isRunning == true
          ? _timers[key]!.elapsed
          : Duration.zero;

      report[key] = _accumulated[key]! + running;
    }

    return report;
  }

  Map<String, int> toSeconds() {
    return getDailyReport().map(
          (key, value) => MapEntry(key, value.inSeconds),
    );
  }

  void reset() {
    for (final key in _accumulated.keys) {
      _accumulated[key] = Duration.zero;
      _timers[key]?.reset();
      _startedAt[key] = null;
    }

    _screenTime.reset();
    notifyListeners();
  }
}
