
import 'dart:async';
import 'dart:math';

import 'package:sensors_plus/sensors_plus.dart';

import 'metrics_manager.dart';

class WristPostureState {
  final bool isPoor;
  final double tilt;

  const WristPostureState({
    required this.isPoor,
    required this.tilt,
  });

  Map<String, dynamic> toMap() {
    return {
      'isPoor': isPoor,
      'tilt': tilt,
    };
  }

  @override
  String toString() {
    return 'WristPostureState(isPoor: $isPoor, tilt: $tilt)';
  }
}

class WristPostureMonitor {
  static const double poorUpperThreshold = 110.0;
  static const double poorLowerThreshold = 50.0;

  static const double moderateUpperThreshold = 95.0;
  static const double moderateLowerThreshold = -65.0;

  static const double filterAlpha = 0.2;

  final MetricsManager _metrics = MetricsManager();

  final StreamController<WristPostureState> _stateController =
  StreamController<WristPostureState>.broadcast();

  StreamSubscription<AccelerometerEvent>? _subscription;

  double _filteredTilt = 0.0;
  bool _isPoor = false;
  bool _disposed = false;

  WristPostureMonitor() {
    _subscription = accelerometerEventStream().listen(
      _handleAccelerometerEvent,
      onError: (Object error, StackTrace stackTrace) {
        // Do not mark the wrist as poor when the sensor itself fails.
        _emitState(isPoor: false, tilt: _filteredTilt);
      },
    );
  }

  Stream<WristPostureState> get stateStream => _stateController.stream;

  WristPostureState get currentState {
    return WristPostureState(
      isPoor: _isPoor,
      tilt: _filteredTilt,
    );
  }

  bool get isPoor => _isPoor;

  double get tilt => _filteredTilt;

  String get status {
    if (_isPoor) {
      return 'Poor Wrist Posture! Tilt: ${_filteredTilt.toStringAsFixed(1)}°';
    }

    if (_filteredTilt > moderateUpperThreshold ||
        _filteredTilt < moderateLowerThreshold) {
      return 'Moderate Wrist Tilt. Tilt: ${_filteredTilt.toStringAsFixed(1)}°';
    }

    return 'Good Wrist Posture. Tilt: ${_filteredTilt.toStringAsFixed(1)}°';
  }

  void _handleAccelerometerEvent(AccelerometerEvent event) {
    if (_disposed) return;

    final rawTilt = atan2(event.y, event.z) * (180 / pi);

    _filteredTilt =
        filterAlpha * rawTilt + (1 - filterAlpha) * _filteredTilt;

    final poorNow = _filteredTilt > poorUpperThreshold ||
        _filteredTilt < poorLowerThreshold;

    // Always emit the first state.
    // Afterwards, emit on state changes and periodically while poor.
    final stateChanged = poorNow != _isPoor;

    _isPoor = poorNow;

    if (poorNow) {
      _metrics.start('wrist');
    } else {
      _metrics.stop('wrist');
    }

    if (stateChanged || poorNow) {
      _emitState(
        isPoor: poorNow,
        tilt: _filteredTilt,
      );
    }
  }

  void _emitState({
    required bool isPoor,
    required double tilt,
  }) {
    if (_disposed || _stateController.isClosed) return;

    _stateController.add(
      WristPostureState(
        isPoor: isPoor,
        tilt: tilt,
      ),
    );
  }

  Future<void> dispose() async {
    if (_disposed) return;

    _disposed = true;

    await _subscription?.cancel();
    _subscription = null;

    _metrics.stop('wrist');

    await _stateController.close();
  }
}


