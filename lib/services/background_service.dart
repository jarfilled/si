import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    hide NotificationVisibility;
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../backend/email_reporter.dart';
import '../backend/metrics_manager.dart';
import '../backend/wrist_posture_monitor.dart';
import '../backend/health_data_repository.dart';
import 'local_monitoring_store.dart';
import 'monitoring_sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _cameraControl = MethodChannel('com.s_health/camera_control');
const _distanceStream = EventChannel('com.s_health/distance_stream');
const _postureStream = EventChannel('com.s_health/posture_stream');
const _hunchStream = EventChannel('com.s_health/hunch_stream');
const _lightStream = EventChannel('com.s_health/light_stream');

const _hunchDivisorPreferenceKey = 'hunch_divisor';
const _monitoringModePreferenceKey = 'monitoring_mode';

const double _tooCloseThresholdCm = 20.0;
const double _lowLightThresholdLux = 100.0;

class BackgroundMonitorService {
  static bool _initialized = false;

  static void setNsfwOverlayActive(bool active) {
    FlutterBackgroundService().invoke(
      'setNsfwOverlayActive',
      {'active': active},
    );
  }

  static Future<void> initialize() async {
    if (_initialized) return;

    final service = FlutterBackgroundService();

    const channel = AndroidNotificationChannel(
      'monitor_service',
      'Monitoring Service',
      description: 'سرویس مانیتورینگ وضعیت نشستن در حال اجراست',
      importance: Importance.low,
    );

    final notifications = FlutterLocalNotificationsPlugin();

    await notifications
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'monitor_service',
        initialNotificationTitle: 'S Health App',
        initialNotificationContent: 'در حال مانیتورینگ وضعیت شما...',
        foregroundServiceNotificationId: 888,
        foregroundServiceTypes: [
          AndroidForegroundType.camera,
          AndroidForegroundType.specialUse,
        ],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );

    _initialized = true;
  }

  static Future<void> setMonitoringMode(String mode) async {
    if (mode != 'passive' && mode != 'overlay') {
      throw ArgumentError.value(
        mode,
        'mode',
        'Monitoring mode must be either passive or overlay.',
      );
    }

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _monitoringModePreferenceKey,
      mode,
    );

    FlutterBackgroundService().invoke(
      'setMonitoringMode',
      {'mode': mode},
    );
  }

  static Future<void> saveHunchDivisor(double divisor) async {
    if (!divisor.isFinite || divisor <= 0) {
      throw ArgumentError.value(
        divisor,
        'divisor',
        'hunch_divisor must be a positive finite number.',
      );
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_hunchDivisorPreferenceKey, divisor);
  }

  static void start() {
    unawaited(FlutterBackgroundService().startService());
  }

  static void stop() {
    FlutterBackgroundService().invoke('stopService');
  }

  static Stream<Map<String, dynamic>?> get statusStream {
    return FlutterBackgroundService().on('status');
  }

  static Future<bool> get isRunning {
    return FlutterBackgroundService().isRunning();
  }
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  debugPrint('[BackgroundService] BG_SERVICE_BOOT_V4');

  // Local storage is initialized before Supabase on purpose.
  // Monitoring must continue even when the network is unavailable.
  final localStore = LocalMonitoringStore.instance;
  await localStore.init();

  try {
    await Supabase.initialize(
      url: 'https://rdlxrnnvebkmldqoedpf.supabase.co',
      anonKey: 'sb_publishable_TURWbpzn8fbkv304X0KP3Q_69o-3vka',
    );

    debugPrint(
      '[BackgroundService] Supabase initialized in background isolate',
    );
  } catch (e) {
    // This is non-fatal. Events remain in Hive until a later sync succeeds.
    debugPrint(
      '[BackgroundService] Supabase initialization failed: $e',
    );
  }

  final metrics = MetricsManager();
  final healthRepository = HealthDataRepository.instance;

  final syncService = MonitoringSyncService(
    store: localStore,
    repository: healthRepository,
  );

  metrics.setHealthEventCallback(
        ({
      required String eventType,
      required DateTime startedAt,
      required DateTime endedAt,
      required double durationSeconds,
    }) async {
      await localStore.enqueueHealthEvent(
        userId: healthRepository.userId,
        eventType: eventType,
        startedAt: startedAt,
        endedAt: endedAt,
        durationSeconds: durationSeconds,
      );

      // This only triggers a network flush when the local queue reaches
      // the threshold. Otherwise the normal 15-minute sync handles it.
      unawaited(syncService.flushIfNeeded());
    },
  );

  StreamSubscription? distanceSub;
  StreamSubscription? postureSub;
  StreamSubscription? hunchSub;
  StreamSubscription? wristSub;
  StreamSubscription? lightSub;

  WristPostureMonitor? wristMonitor;

  Timer? pushTimer;
  Timer? emailTimer;

  const userTimezone = 'Asia/Tehran';

  Future<void> updateDailyMetrics() async {
    final now = DateTime.now();

    await healthRepository.updateDailyMetrics(
      date: DateTime(
        now.year,
        now.month,
        now.day,
      ),
      timezone: userTimezone,
    );
  }

  // We deliberately do not call calculate_daily_metrics every 5 minutes.
  // First attempt to synchronize local data, then calculate today's compact
  // daily row at service startup.
  await syncService.flush();
  await updateDailyMetrics();

  var stopped = false;
  var nsfwOverlayActive = false;
  var monitoringMode = 'passive';

  final prefs = await SharedPreferences.getInstance();

  monitoringMode =
      prefs.getString(_monitoringModePreferenceKey) ?? 'passive';

  final overlayState = <String, dynamic>{
    'type': 'hud',
    'tooClose': false,
    'neck': false,
    'wrist': false,
    'hunch': false,
    'lowLight': false,
    'wristTilt': 0.0,
    'hunchRatio': 0.0,
    'lightLux': 0.0,
  };

  DateTime lastOverlayTime =
  DateTime.now().subtract(const Duration(seconds: 2));

  Future<void> overlayQueue = Future<void>.value();

  bool hasActiveWarning() {
    return overlayState['tooClose'] == true ||
        overlayState['neck'] == true ||
        overlayState['wrist'] == true ||
        overlayState['hunch'] == true ||
        overlayState['lowLight'] == true;
  }

  bool hasNoActiveWarning() => !hasActiveWarning();

  void queueOverlayUpdate() {
    final stateSnapshot = Map<String, dynamic>.from(overlayState);

    overlayQueue = overlayQueue.then((_) async {
      if (stopped) return;

      if (monitoringMode != 'overlay') {
        if (!nsfwOverlayActive) {
          await Future<void>.delayed(
            const Duration(milliseconds: 150),
          );

          if (!nsfwOverlayActive) {
            try {
              if (await FlutterOverlayWindow.isActive()) {
                await FlutterOverlayWindow.closeOverlay();
              }
            } catch (error) {
              debugPrint(
                '[BackgroundService] Failed to close passive overlay: $error',
              );
            }
          }
        }

        return;
      }

      try {
        final active = await FlutterOverlayWindow.isActive();

        if (hasActiveWarning()) {
          if (!active) {
            final now = DateTime.now();

            if (now.difference(lastOverlayTime).inSeconds >= 1) {
              await FlutterOverlayWindow.showOverlay(
                height: 800,
                alignment: OverlayAlignment.center,
                flag: OverlayFlag.clickThrough,
                visibility: NotificationVisibility.visibilityPublic,
                positionGravity: PositionGravity.auto,
              );

              lastOverlayTime = now;
            }
          }

          if (await FlutterOverlayWindow.isActive()) {
            await FlutterOverlayWindow.shareData(
              stateSnapshot,
            );
          }
        } else if (active) {
          await FlutterOverlayWindow.shareData(
            stateSnapshot,
          );

          await Future<void>.delayed(
            const Duration(milliseconds: 100),
          );

          if (hasNoActiveWarning() &&
              !nsfwOverlayActive &&
              await FlutterOverlayWindow.isActive()) {
            await FlutterOverlayWindow.closeOverlay();
          }
        }
      } catch (error) {
        debugPrint(
          '[BackgroundService] Overlay update failed: $error',
        );
      }
    });
  }

  void setOverlayFlag(
      String key,
      bool value, {
        double? wristTilt,
        double? hunchRatio,
        double? lightLux,
      }) {
    final flagChanged = overlayState[key] != value;
    final wristChanged =
        wristTilt != null && overlayState['wristTilt'] != wristTilt;
    final hunchChanged =
        hunchRatio != null && overlayState['hunchRatio'] != hunchRatio;
    final lightChanged =
        lightLux != null && overlayState['lightLux'] != lightLux;

    if (wristTilt != null) overlayState['wristTilt'] = wristTilt;
    if (hunchRatio != null) overlayState['hunchRatio'] = hunchRatio;
    if (lightLux != null) overlayState['lightLux'] = lightLux;

    overlayState[key] = value;

    if (flagChanged ||
        wristChanged ||
        hunchChanged ||
        lightChanged ||
        value) {
      queueOverlayUpdate();
    }
  }

  Future<void> shutdown() async {
    if (stopped) {
      return;
    }

    stopped = true;

    // First end active episodes. Their final events are written locally.
    try {
      await metrics.flushActiveEvents();
      debugPrint(
        '[BackgroundService] Active health events flushed to local storage.',
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[BackgroundService] Failed to flush active events: $error',
      );
      debugPrint('$stackTrace');
    }

    // Then try one final batch upload. Offline data remains in Hive.
    try {
      await syncService.flush();
      debugPrint(
        '[BackgroundService] Final monitoring sync completed.',
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[BackgroundService] Final monitoring sync failed: $error',
      );
      debugPrint('$stackTrace');
    }

    // Recalculate today's compact aggregate only once at shutdown.
    try {
      await updateDailyMetrics();
    } catch (e) {
      debugPrint(
        '[BackgroundService] Final daily metrics update failed: $e',
      );
    }

    await distanceSub?.cancel();
    await postureSub?.cancel();
    await hunchSub?.cancel();
    await wristSub?.cancel();
    await lightSub?.cancel();

    await wristMonitor?.dispose();

    pushTimer?.cancel();
    emailTimer?.cancel();
    syncService.dispose();

    try {
      await _cameraControl.invokeMethod('stopCamera');
      await _cameraControl.invokeMethod('stopLightMonitor');
    } catch (error) {
      debugPrint(
        '[BackgroundService] Shutdown error (native services): $error',
      );
    }

    try {
      if (await FlutterOverlayWindow.isActive()) {
        await FlutterOverlayWindow.shareData({
          'type': 'hud',
          'tooClose': false,
          'neck': false,
          'wrist': false,
          'hunch': false,
          'lowLight': false,
          'wristTilt': 0.0,
          'hunchRatio': 0.0,
          'lightLux': 0.0,
        });

        await FlutterOverlayWindow.closeOverlay();
      }
    } catch (error) {
      debugPrint(
        '[BackgroundService] Shutdown overlay error: $error',
      );
    }
  }

  service.on('setNsfwOverlayActive').listen((event) {
    nsfwOverlayActive = event?['active'] == true;

    debugPrint(
      '[BackgroundService] NSFW overlay active: $nsfwOverlayActive',
    );
  });

  service.on('setMonitoringMode').listen((event) async {
    final requestedMode = event?['mode']?.toString();

    if (requestedMode != 'passive' &&
        requestedMode != 'overlay') {
      return;
    }

    monitoringMode = requestedMode ?? monitoringMode;

    debugPrint(
      '[BackgroundService] Monitoring mode changed: '
          '$monitoringMode',
    );

    if (monitoringMode == 'passive') {
      try {
        if (await FlutterOverlayWindow.isActive()) {
          await FlutterOverlayWindow.closeOverlay();
        }
      } catch (error) {
        debugPrint(
          '[BackgroundService] Failed to close overlay: $error',
        );
      }
    } else {
      queueOverlayUpdate();
    }
  });

  service.on('stopService').listen((_) async {
    await shutdown();
    service.stopSelf();
  });

  // ---- Start native camera & light services ----
  try {
    final hunchDivisor = prefs.getDouble(_hunchDivisorPreferenceKey);

    if (hunchDivisor == null ||
        !hunchDivisor.isFinite ||
        hunchDivisor <= 0) {
      debugPrint(
        'startCamera skipped: hunch_divisor is missing or invalid.',
      );
    } else {
      await _cameraControl.invokeMethod(
        'startCamera',
        {'hunch_divisor': hunchDivisor},
      );

      debugPrint(
        'Camera started with hunch_divisor: $hunchDivisor',
      );
    }
  } catch (e) {
    debugPrint('startCamera failed: $e');
  }

  try {
    debugPrint(
      '[BackgroundService] Requesting startLightMonitor via MethodChannel',
    );

    await _cameraControl.invokeMethod('startLightMonitor');
  } catch (error) {
    debugPrint(
      '[BackgroundService] startLightMonitor failed: $error',
    );
  }

  // ---- Wrist posture monitor ----
  wristMonitor = WristPostureMonitor();

  wristSub = wristMonitor.stateStream.listen(
        (state) {
      if (state.isPoor) {
        metrics.start('wrist');
      } else {
        unawaited(metrics.stop('wrist'));
      }

      setOverlayFlag(
        'wrist',
        state.isPoor,
        wristTilt: state.tilt,
      );
    },
    onError: (Object error) {
      unawaited(metrics.stop('wrist'));
      setOverlayFlag(
        'wrist',
        false,
        wristTilt: 0.0,
      );
      debugPrint(
        '[BackgroundService] Wrist stream error: $error',
      );
    },
  );

  // ---- Distance (camera-based) ----
  distanceSub = _distanceStream.receiveBroadcastStream().listen(
        (raw) {
      if (raw is! num) return;

      final distance = raw.toDouble();
      final tooClose =
          distance > 0 && distance < _tooCloseThresholdCm;

      if (tooClose) {
        metrics.start('tooClose');
      } else {
        unawaited(metrics.stop('tooClose'));
      }

      setOverlayFlag('tooClose', tooClose);
    },
    onError: (Object error) {
      unawaited(metrics.stop('tooClose'));
      setOverlayFlag('tooClose', false);

      debugPrint(
        '[BackgroundService] Distance stream error: $error',
      );
    },
  );

  // ---- Neck posture (face detection) ----
  postureSub = _postureStream.receiveBroadcastStream().listen(
        (raw) {
      if (raw is! Map) return;

      final data = Map<dynamic, dynamic>.from(raw);
      final status =
          data['status']?.toString().toLowerCase() ?? 'good';

      final neckPoor = status == 'poor';

      if (neckPoor) {
        metrics.start('neck');
      } else {
        unawaited(metrics.stop('neck'));
      }

      setOverlayFlag('neck', neckPoor);
    },
    onError: (Object error) {
      unawaited(metrics.stop('neck'));
      setOverlayFlag('neck', false);

      debugPrint(
        '[BackgroundService] Posture stream error: $error',
      );
    },
  );

  // ---- Hunch posture (pose detection) ----
  hunchSub = _hunchStream.receiveBroadcastStream().listen(
        (raw) {
      if (raw is! Map) return;

      final data = Map<dynamic, dynamic>.from(raw);

      final isHunching =
          data['is_hunching'] == true ||
              data['hunchPoor'] == true ||
              data['poor'] == true;

      final ratio = data['hunch_ratio'] is num
          ? (data['hunch_ratio'] as num).toDouble()
          : 0.0;

      if (isHunching) {
        metrics.start('hunch');
      } else {
        unawaited(metrics.stop('hunch'));
      }

      setOverlayFlag(
        'hunch',
        isHunching,
        hunchRatio: ratio,
      );
    },
    onError: (Object error) {
      unawaited(metrics.stop('hunch'));
      setOverlayFlag(
        'hunch',
        false,
        hunchRatio: 0.0,
      );

      debugPrint(
        '[BackgroundService] Hunch stream error: $error',
      );
    },
  );

  // ---- Ambient light via native EventChannel ----
  debugPrint(
    '[BackgroundService] Subscribing to native ambient light stream '
        '(com.s_health/light_stream)',
  );

  lightSub = _lightStream.receiveBroadcastStream().listen(
        (raw) {
      if (raw is! Map) return;

      final data = Map<dynamic, dynamic>.from(raw);

      final lux = data['lightLux'] is num
          ? (data['lightLux'] as num).toDouble()
          : 0.0;

      final sensorUnavailableOrZero = lux <= 0;

      final isLowLight =
          !sensorUnavailableOrZero &&
              lux > 0 &&
              lux < _lowLightThresholdLux;

      debugPrint(
        '[BackgroundService] Ambient light event: '
            'lux=$lux, '
            'isLowLight=$isLowLight, '
            'sensorUnavailableOrZero=$sensorUnavailableOrZero',
      );

      if (sensorUnavailableOrZero) {
        unawaited(metrics.stop('lowLight'));

        setOverlayFlag(
          'lowLight',
          false,
          lightLux: lux,
        );
      } else {
        if (isLowLight) {
          metrics.start('lowLight');
        } else {
          unawaited(metrics.stop('lowLight'));
        }

        setOverlayFlag(
          'lowLight',
          isLowLight,
          lightLux: lux,
        );
      }

      service.invoke('ambientLightDebug', {
        'lightLux': lux,
        'isLowLight': isLowLight,
        'sensorUnavailableOrZero': sensorUnavailableOrZero,
        'ts': DateTime.now().toIso8601String(),
      });
    },
    onError: (Object error) {
      unawaited(metrics.stop('lowLight'));
      setOverlayFlag(
        'lowLight',
        false,
        lightLux: 0.0,
      );

      debugPrint(
        '[BackgroundService] Ambient light stream error: $error',
      );
    },
  );

  // ---- Network sync ----
  // The sync service performs at most one scheduled flush every 15 minutes.
  // It also flushes early when the local event queue reaches 25 events.
  syncService.start();

  // ---- Daily report email ----
  emailTimer = Timer.periodic(
    const Duration(minutes: 1),
        (_) {
      final now = DateTime.now();

      if (now.hour == 13 && now.minute == 0) {
        final email = Supabase.instance.client.auth.currentUser?.email;

        if (email != null && email.isNotEmpty) {
          unawaited(
            EmailReporter.sendDailyReport(email),
          );
        }
      }
    },
  );

  // ---- Status pushes to the UI ----
  pushTimer = Timer.periodic(
    const Duration(seconds: 1),
        (_) {
      final report = metrics.getDailyReport();

      service.invoke('status', {
        'running': true,
        'timestamp': DateTime.now().toIso8601String(),
        'hunch': report['hunch']?.inSeconds ?? 0,
        'neck': report['neck']?.inSeconds ?? 0,
        'wrist': report['wrist']?.inSeconds ?? 0,
        'tooClose': report['tooClose']?.inSeconds ?? 0,
        'lowLight': report['lowLight']?.inSeconds ?? 0,
        'wristPoor': overlayState['wrist'],
        'wristTilt': overlayState['wristTilt'],
        'hunchPoor': overlayState['hunch'],
        'lowLightPoor': overlayState['lowLight'],
        'lightLux': overlayState['lightLux'],
      });
    },
  );

  metrics.addListener(() {
    service.invoke('status', {
      'running': true,
      'metrics': metrics.toSeconds(),
      'timestamp': DateTime.now().toIso8601String(),
      'wristPoor': overlayState['wrist'],
      'wristTilt': overlayState['wristTilt'],
      'hunchPoor': overlayState['hunch'],
      'lowLightPoor': overlayState['lowLight'],
      'lightLux': overlayState['lightLux'],
    });
  });
}
