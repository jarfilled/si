import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    hide NotificationVisibility;
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../backend/email_reporter.dart';
import '../backend/health_data_repository.dart';
import '../backend/metrics_manager.dart';
import '../backend/monitoring_audio_manager.dart';
import '../backend/wrist_posture_monitor.dart';
import 'local_monitoring_store.dart';
import 'monitoring_sync_service.dart';

// ============================================================================
// NATIVE CHANNELS
// ============================================================================

const _cameraControl =
MethodChannel('com.s_health/camera_control');

const _distanceStream =
EventChannel('com.s_health/distance_stream');

const _postureStream =
EventChannel('com.s_health/posture_stream');

const _hunchStream =
EventChannel('com.s_health/hunch_stream');

const _lightStream =
EventChannel('com.s_health/light_stream');

// ============================================================================
// PREFERENCES
// ============================================================================

const _hunchDivisorPreferenceKey = 'hunch_divisor';
const _monitoringModePreferenceKey = 'monitoring_mode';
const _monitoringSoundEnabledPreferenceKey =
    'monitoring_sound_enabled';

// ============================================================================
// THRESHOLDS
// ============================================================================

const double _tooCloseThresholdCm = 20.0;
const double _lowLightThresholdLux = 100.0;

// ============================================================================
// SERVICE CONTROLLER
// ============================================================================

class BackgroundMonitorService {
  static bool _initialized = false;

  // --------------------------------------------------------------------------
  // NSFW OVERLAY STATE
  // --------------------------------------------------------------------------

  static void setNsfwOverlayActive(bool active) {
    FlutterBackgroundService().invoke(
      'setNsfwOverlayActive',
      {
        'active': active,
      },
    );
  }

  // --------------------------------------------------------------------------
  // SOUND SETTING
  // --------------------------------------------------------------------------

  static Future<void> setMonitoringSoundEnabled(
      bool enabled,
      ) async {
    final prefs =
    await SharedPreferences.getInstance();

    await prefs.setBool(
      _monitoringSoundEnabledPreferenceKey,
      enabled,
    );

    // This is critical:
    //
    // The monitoring service is running in a different isolate, so merely
    // changing SharedPreferences does not notify it immediately.
    FlutterBackgroundService().invoke(
      'setMonitoringSoundEnabled',
      {
        'enabled': enabled,
      },
    );

    debugPrint(
      '[BackgroundMonitorService] '
          'Monitoring sound enabled = $enabled',
    );
  }

  // --------------------------------------------------------------------------
  // INITIALIZE
  // --------------------------------------------------------------------------

  static Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    final service =
    FlutterBackgroundService();

    const channel =
    AndroidNotificationChannel(
      'monitor_service',
      'Monitoring Service',
      description:
      'سرویس مانیتورینگ وضعیت نشستن در حال اجراست',
      importance: Importance.low,
    );

    final notifications =
    FlutterLocalNotificationsPlugin();

    await notifications
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration:
      AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId:
        'monitor_service',
        initialNotificationTitle:
        'S Health App',
        initialNotificationContent:
        'در حال مانیتورینگ وضعیت شما...',
        foregroundServiceNotificationId:
        888,
        foregroundServiceTypes: [
          AndroidForegroundType.camera,
          AndroidForegroundType.specialUse,
        ],
      ),
      iosConfiguration:
      IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );

    _initialized = true;
  }

  // --------------------------------------------------------------------------
  // MONITORING MODE
  // --------------------------------------------------------------------------

  static Future<void> setMonitoringMode(
      String mode,
      ) async {
    if (mode != 'passive' &&
        mode != 'overlay') {
      throw ArgumentError.value(
        mode,
        'mode',
        'Monitoring mode must be either passive or overlay.',
      );
    }

    final prefs =
    await SharedPreferences.getInstance();

    await prefs.setString(
      _monitoringModePreferenceKey,
      mode,
    );

    FlutterBackgroundService().invoke(
      'setMonitoringMode',
      {
        'mode': mode,
      },
    );
  }

  // --------------------------------------------------------------------------
  // HUNCH CALIBRATION
  // --------------------------------------------------------------------------

  static Future<void> saveHunchDivisor(
      double divisor,
      ) async {
    if (!divisor.isFinite ||
        divisor <= 0) {
      throw ArgumentError.value(
        divisor,
        'divisor',
        'hunch_divisor must be a positive finite number.',
      );
    }

    final prefs =
    await SharedPreferences.getInstance();

    await prefs.setDouble(
      _hunchDivisorPreferenceKey,
      divisor,
    );
  }

  // --------------------------------------------------------------------------
  // SERVICE CONTROL
  // --------------------------------------------------------------------------

  static void start() {
    unawaited(
      FlutterBackgroundService()
          .startService(),
    );
  }

  static void stop() {
    FlutterBackgroundService().invoke(
      'stopService',
    );
  }

  static Stream<Map<String, dynamic>?>
  get statusStream {
    return FlutterBackgroundService()
        .on('status');
  }

  static Future<bool> get isRunning {
    return FlutterBackgroundService()
        .isRunning();
  }
}

// ============================================================================
// IOS BACKGROUND ENTRY POINT
// ============================================================================

@pragma('vm:entry-point')
Future<bool> onIosBackground(
    ServiceInstance service,
    ) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  return true;
}

// ============================================================================
// BACKGROUND SERVICE ENTRY POINT
// ============================================================================

@pragma('vm:entry-point')
void onStart(
    ServiceInstance service,
    ) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  debugPrint(
    '[BackgroundService] BG_SERVICE_BOOT_V6',
  );

  // ==========================================================================
  // LOCAL STORAGE
  // ==========================================================================

  final localStore =
      LocalMonitoringStore.instance;

  await localStore.init();

  // ==========================================================================
  // SUPABASE
  // ==========================================================================

  try {
    await Supabase.initialize(
      url:
      'https://rdlxrnnvebkmldqoedpf.supabase.co',
      anonKey:
      'sb_publishable_TURWbpzn8fbkv304X0KP3Q_69o-3vka',
    );

    debugPrint(
      '[BackgroundService] '
          'Supabase initialized in background isolate',
    );
  } catch (e) {
    debugPrint(
      '[BackgroundService] '
          'Supabase initialization failed: $e',
    );
  }

  // ==========================================================================
  // CORE SERVICES
  // ==========================================================================

  final metrics =
  MetricsManager();

  final healthRepository =
      HealthDataRepository.instance;

  final audioManager =
      MonitoringAudioManager.instance;

  await audioManager.initialize();

  final syncService =
  MonitoringSyncService(
    store: localStore,
    repository: healthRepository,
  );

  // ==========================================================================
  // HEALTH EVENT CALLBACK
  // ==========================================================================

  metrics.setHealthEventCallback(
        ({
      required String eventType,
      required DateTime startedAt,
      required DateTime endedAt,
      required double durationSeconds,
    }) async {
      await localStore.enqueueHealthEvent(
        userId:
        healthRepository.userId,
        eventType: eventType,
        startedAt: startedAt,
        endedAt: endedAt,
        durationSeconds: durationSeconds,
      );

      unawaited(
        syncService.flushIfNeeded(),
      );
    },
  );

  // ==========================================================================
  // STREAMS / TIMERS
  // ==========================================================================

  StreamSubscription?
  distanceSub;

  StreamSubscription?
  postureSub;

  StreamSubscription?
  hunchSub;

  StreamSubscription?
  wristSub;

  StreamSubscription?
  lightSub;

  WristPostureMonitor?
  wristMonitor;

  Timer? pushTimer;
  Timer? emailTimer;

  const userTimezone =
      'Asia/Tehran';

  // ==========================================================================
  // DAILY METRICS
  // ==========================================================================

  Future<void>
  updateDailyMetrics() async {
    final now =
    DateTime.now();

    await healthRepository
        .updateDailyMetrics(
      date: DateTime(
        now.year,
        now.month,
        now.day,
      ),
      timezone:
      userTimezone,
    );
  }

  await syncService.flush();
  await updateDailyMetrics();

  // ==========================================================================
  // SERVICE STATE
  // ==========================================================================

  bool stopped = false;
  bool nsfwOverlayActive = false;

  String monitoringMode = 'passive';

  bool monitoringSoundEnabled =
  true;

  final prefs =
  await SharedPreferences.getInstance();

  monitoringMode =
      prefs.getString(
        _monitoringModePreferenceKey,
      ) ??
          'passive';

  monitoringSoundEnabled =
      prefs.getBool(
        _monitoringSoundEnabledPreferenceKey,
      ) ??
          true;

  debugPrint(
    '[BackgroundService] '
        'Initial sound state: '
        '$monitoringSoundEnabled',
  );

  // ==========================================================================
  // WARNING STATES
  // ==========================================================================
  //
  // These are deliberately separate from overlayState.
  //
  // They prevent the audio system from replaying a sound every time a sensor
  // sends another "still poor" event.
  // ==========================================================================

  final warningState =
  <String, bool>{
    'tooClose': false,
    'neck': false,
    'wrist': false,
    'hunch': false,
    'lowLight': false,
  };

  // ==========================================================================
  // OVERLAY STATE
  // ==========================================================================

  final overlayState =
  <String, dynamic>{
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
  DateTime.now()
      .subtract(
    const Duration(
      seconds: 2,
    ),
  );

  Future<void> overlayQueue =
  Future<void>.value();

  // ==========================================================================
  // WARNING STATE TRANSITION
  // ==========================================================================

  void updateWarningState(
      String type,
      bool active,
      ) {
    final previous =
        warningState[type] ?? false;

    warningState[type] =
        active;

    // No transition:
    //
    // true -> true
    //
    // Do NOT retrigger the sound.
    if (previous == active) {
      return;
    }

    if (active) {
      if (monitoringSoundEnabled) {
        debugPrint(
          '[BackgroundService] '
              'AUDIO START: $type',
        );

        // No await here. The detector should not be blocked by audio playback.
        unawaited(
          audioManager.trigger(type),
        );
      } else {
        debugPrint(
          '[BackgroundService] '
              'Sound disabled; ignoring: $type',
        );
      }
    } else {
      debugPrint(
        '[BackgroundService] '
            'AUDIO CLEAR: $type',
      );

      audioManager.clear(type);
    }
  }

  // ==========================================================================
  // OVERLAY HELPERS
  // ==========================================================================

  bool hasActiveWarning() {
    return overlayState['tooClose'] == true ||
        overlayState['neck'] == true ||
        overlayState['wrist'] == true ||
        overlayState['hunch'] == true ||
        overlayState['lowLight'] == true;
  }

  bool hasNoActiveWarning() {
    return !hasActiveWarning();
  }

  void queueOverlayUpdate() {
    final snapshot =
    Map<String, dynamic>.from(
      overlayState,
    );

    overlayQueue =
        overlayQueue.then(
              (_) async {
            if (stopped) {
              return;
            }

            // Passive mode = no posture HUD.
            if (monitoringMode != 'overlay') {
              if (!nsfwOverlayActive) {
                try {
                  if (await FlutterOverlayWindow
                      .isActive()) {
                    await FlutterOverlayWindow
                        .closeOverlay();
                  }
                } catch (error) {
                  debugPrint(
                    '[BackgroundService] '
                        'Failed to close passive overlay: $error',
                  );
                }
              }

              return;
            }

            try {
              final active =
              await FlutterOverlayWindow
                  .isActive();

              if (hasActiveWarning()) {
                if (!active) {
                  final now =
                  DateTime.now();

                  if (now
                      .difference(
                    lastOverlayTime,
                  )
                      .inSeconds >=
                      1) {
                    await FlutterOverlayWindow
                        .showOverlay(
                      height: 1800,
                      width: 1200,
                      alignment:
                      OverlayAlignment.center,
                      flag:
                      OverlayFlag.clickThrough,
                      visibility:
                      NotificationVisibility
                          .visibilityPublic,
                      positionGravity:
                      PositionGravity.auto,
                    );

                    lastOverlayTime = now;
                  }
                }

                if (await FlutterOverlayWindow
                    .isActive()) {
                  await FlutterOverlayWindow
                      .shareData(snapshot);
                }
              } else if (active) {
                await FlutterOverlayWindow
                    .shareData(snapshot);

                await Future<void>.delayed(
                  const Duration(
                    milliseconds: 100,
                  ),
                );

                if (hasNoActiveWarning() &&
                    !nsfwOverlayActive &&
                    await FlutterOverlayWindow
                        .isActive()) {
                  await FlutterOverlayWindow
                      .closeOverlay();
                }
              }
            } catch (error) {
              debugPrint(
                '[BackgroundService] '
                    'Overlay update failed: $error',
              );
            }
          },
        );
  }

  // ==========================================================================
  // OVERLAY FLAG
  // ==========================================================================

  void setOverlayFlag(
      String key,
      bool value, {
        double? wristTilt,
        double? hunchRatio,
        double? lightLux,
      }) {
    final flagChanged =
        overlayState[key] != value;

    final wristChanged =
        wristTilt != null &&
            overlayState['wristTilt'] !=
                wristTilt;

    final hunchChanged =
        hunchRatio != null &&
            overlayState['hunchRatio'] !=
                hunchRatio;

    final lightChanged =
        lightLux != null &&
            overlayState['lightLux'] !=
                lightLux;

    if (wristTilt != null) {
      overlayState['wristTilt'] =
          wristTilt;
    }

    if (hunchRatio != null) {
      overlayState['hunchRatio'] =
          hunchRatio;
    }

    if (lightLux != null) {
      overlayState['lightLux'] =
          lightLux;
    }

    overlayState[key] =
        value;

    if (flagChanged ||
        wristChanged ||
        hunchChanged ||
        lightChanged ||
        value) {
      queueOverlayUpdate();
    }
  }

  // ==========================================================================
  // SHUTDOWN
  // ==========================================================================

  Future<void> shutdown() async {
    if (stopped) {
      return;
    }

    stopped = true;

    try {
      await metrics.flushActiveEvents();

      debugPrint(
        '[BackgroundService] '
            'Active health events flushed.',
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[BackgroundService] '
            'Failed to flush active events: $error',
      );
      debugPrint('$stackTrace');
    }

    try {
      await syncService.flush();

      debugPrint(
        '[BackgroundService] '
            'Final monitoring sync completed.',
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[BackgroundService] '
            'Final monitoring sync failed: $error',
      );
      debugPrint('$stackTrace');
    }

    try {
      await updateDailyMetrics();
    } catch (e) {
      debugPrint(
        '[BackgroundService] '
            'Final daily metrics update failed: $e',
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

    // Clear all audio states.
    audioManager.clear('tooClose');
    audioManager.clear('neck');
    audioManager.clear('wrist');
    audioManager.clear('hunch');
    audioManager.clear('lowLight');

    try {
      await _cameraControl.invokeMethod(
        'stopCamera',
      );

      await _cameraControl.invokeMethod(
        'stopLightMonitor',
      );
    } catch (error) {
      debugPrint(
        '[BackgroundService] '
            'Native shutdown error: $error',
      );
    }

    try {
      if (await FlutterOverlayWindow
          .isActive()) {
        await FlutterOverlayWindow
            .shareData({
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

        await FlutterOverlayWindow
            .closeOverlay();
      }
    } catch (error) {
      debugPrint(
        '[BackgroundService] '
            'Overlay shutdown error: $error',
      );
    }

    debugPrint(
      '[BackgroundService] '
          'Service shutdown complete.',
    );
  }

  // ==========================================================================
  // NSFW OVERLAY STATE
  // ==========================================================================

  service
      .on('setNsfwOverlayActive')
      .listen((event) {
    nsfwOverlayActive =
        event?['active'] == true;

    debugPrint(
      '[BackgroundService] '
          'NSFW overlay active: '
          '$nsfwOverlayActive',
    );
  });

  // ==========================================================================
  // LIVE SOUND SETTING
  // ==========================================================================

  service
      .on('setMonitoringSoundEnabled')
      .listen((event) {
    final enabled =
        event?['enabled'] == true;

    final previous =
        monitoringSoundEnabled;

    monitoringSoundEnabled =
        enabled;

    debugPrint(
      '[BackgroundService] '
          'Sound setting changed: '
          '$previous -> $enabled',
    );

    if (!enabled) {
      // Immediately stop all active sounds.
      audioManager.clear('tooClose');
      audioManager.clear('neck');
      audioManager.clear('wrist');
      audioManager.clear('hunch');
      audioManager.clear('lowLight');

      return;
    }

    // Sound was turned ON while a warning is already active.
    //
    // Fire exactly once for each currently active warning.
    if (!previous && enabled) {
      for (final entry
      in warningState.entries) {
        if (entry.value) {
          debugPrint(
            '[BackgroundService] '
                'Sound enabled while active: '
                '${entry.key}',
          );

          unawaited(
            audioManager.trigger(
              entry.key,
            ),
          );
        }
      }
    }
  });

  // ==========================================================================
  // MONITORING MODE
  // ==========================================================================

  service
      .on('setMonitoringMode')
      .listen((event) async {
    final requestedMode =
    event?['mode']?.toString();

    if (requestedMode != 'passive' &&
        requestedMode != 'overlay') {
      return;
    }

    monitoringMode = requestedMode!;


    debugPrint(
      '[BackgroundService] '
          'Monitoring mode changed: '
          '$monitoringMode',
    );

    if (monitoringMode ==
        'passive') {
      try {
        if (await FlutterOverlayWindow
            .isActive()) {
          await FlutterOverlayWindow
              .closeOverlay();
        }
      } catch (error) {
        debugPrint(
          '[BackgroundService] '
              'Failed to close overlay: $error',
        );
      }
    } else {
      queueOverlayUpdate();
    }
  });

  // ==========================================================================
  // STOP SERVICE
  // ==========================================================================

  service
      .on('stopService')
      .listen((_) async {
    await shutdown();

    await service.stopSelf();
  });

  // ==========================================================================
  // CAMERA
  // ==========================================================================

  try {
    final hunchDivisor =
    prefs.getDouble(
      _hunchDivisorPreferenceKey,
    );

    if (hunchDivisor == null ||
        !hunchDivisor.isFinite ||
        hunchDivisor <= 0) {
      debugPrint(
        '[BackgroundService] '
            'startCamera skipped: invalid hunch divisor.',
      );
    } else {
      await _cameraControl
          .invokeMethod(
        'startCamera',
        {
          'hunch_divisor':
          hunchDivisor,
        },
      );

      debugPrint(
        '[BackgroundService] '
            'Camera started with divisor '
            '$hunchDivisor',
      );
    }
  } catch (e) {
    debugPrint(
      '[BackgroundService] '
          'startCamera failed: $e',
    );
  }

  // ==========================================================================
  // AMBIENT LIGHT MONITOR
  // ==========================================================================

  try {
    debugPrint(
      '[BackgroundService] '
          'Starting ambient light monitor',
    );

    await _cameraControl
        .invokeMethod(
      'startLightMonitor',
    );
  } catch (error) {
    debugPrint(
      '[BackgroundService] '
          'startLightMonitor failed: $error',
    );
  }

  // ==========================================================================
  // WRIST POSTURE
  // ==========================================================================

  wristMonitor =
      WristPostureMonitor();

  wristSub =
      wristMonitor!.stateStream.listen(
            (state) {
          final poor =
              state.isPoor;

          if (poor) {
            metrics.start('wrist');
          } else {
            unawaited(
              metrics.stop('wrist'),
            );
          }

          // Audio transition and visual transition happen from the exact same
          // detector result.
          updateWarningState(
            'wrist',
            poor,
          );

          setOverlayFlag(
            'wrist',
            poor,
            wristTilt:
            state.tilt,
          );
        },
        onError: (Object error) {
          unawaited(
            metrics.stop('wrist'),
          );

          updateWarningState(
            'wrist',
            false,
          );

          setOverlayFlag(
            'wrist',
            false,
            wristTilt: 0.0,
          );

          debugPrint(
            '[BackgroundService] '
                'Wrist stream error: $error',
          );
        },
      );

  // ==========================================================================
  // DISTANCE / TOO CLOSE
  // ==========================================================================

  distanceSub =
      _distanceStream
          .receiveBroadcastStream()
          .listen(
            (raw) {
          if (raw is! num) {
            return;
          }

          final distance =
          raw.toDouble();

          final tooClose =
              distance > 0 &&
                  distance <
                      _tooCloseThresholdCm;

          if (tooClose) {
            metrics.start(
              'tooClose',
            );
          } else {
            unawaited(
              metrics.stop(
                'tooClose',
              ),
            );
          }

          updateWarningState(
            'tooClose',
            tooClose,
          );

          setOverlayFlag(
            'tooClose',
            tooClose,
          );
        },
        onError: (Object error) {
          unawaited(
            metrics.stop(
              'tooClose',
            ),
          );

          updateWarningState(
            'tooClose',
            false,
          );

          setOverlayFlag(
            'tooClose',
            false,
          );

          debugPrint(
            '[BackgroundService] '
                'Distance stream error: $error',
          );
        },
      );

  // ==========================================================================
  // NECK POSTURE
  // ==========================================================================

  postureSub =
      _postureStream
          .receiveBroadcastStream()
          .listen(
            (raw) {
          if (raw is! Map) {
            return;
          }

          final data =
          Map<dynamic, dynamic>.from(
            raw,
          );

          final status =
              data['status']
                  ?.toString()
                  .toLowerCase() ??
                  'good';

          final neckPoor =
              status == 'poor';

          if (neckPoor) {
            metrics.start('neck');
          } else {
            unawaited(
              metrics.stop('neck'),
            );
          }

          updateWarningState(
            'neck',
            neckPoor,
          );

          setOverlayFlag(
            'neck',
            neckPoor,
          );
        },
        onError: (Object error) {
          unawaited(
            metrics.stop('neck'),
          );

          updateWarningState(
            'neck',
            false,
          );

          setOverlayFlag(
            'neck',
            false,
          );

          debugPrint(
            '[BackgroundService] '
                'Posture stream error: $error',
          );
        },
      );

  // ==========================================================================
  // HUNCH POSTURE
  // ==========================================================================

  hunchSub =
      _hunchStream
          .receiveBroadcastStream()
          .listen(
            (raw) {
          if (raw is! Map) {
            return;
          }

          final data =
          Map<dynamic, dynamic>.from(
            raw,
          );

          final isHunching =
              data['is_hunching'] == true ||
                  data['hunchPoor'] == true ||
                  data['poor'] == true;

          final ratio =
          data['hunch_ratio']
          is num
              ? (data['hunch_ratio']
          as num)
              .toDouble()
              : 0.0;

          if (isHunching) {
            metrics.start('hunch');
          } else {
            unawaited(
              metrics.stop('hunch'),
            );
          }

          updateWarningState(
            'hunch',
            isHunching,
          );

          setOverlayFlag(
            'hunch',
            isHunching,
            hunchRatio:
            ratio,
          );
        },
        onError: (Object error) {
          unawaited(
            metrics.stop('hunch'),
          );

          updateWarningState(
            'hunch',
            false,
          );

          setOverlayFlag(
            'hunch',
            false,
            hunchRatio: 0.0,
          );

          debugPrint(
            '[BackgroundService] '
                'Hunch stream error: $error',
          );
        },
      );

  // ==========================================================================
  // AMBIENT LIGHT
  // ==========================================================================

  debugPrint(
    '[BackgroundService] '
        'Subscribing to light stream',
  );

  lightSub =
      _lightStream
          .receiveBroadcastStream()
          .listen(
            (raw) {
          if (raw is! Map) {
            return;
          }

          final data =
          Map<dynamic, dynamic>.from(
            raw,
          );

          final lux =
          data['lightLux'] is num
              ? (data['lightLux']
          as num)
              .toDouble()
              : 0.0;

          final sensorUnavailable =
              lux <= 0;

          final lowLight =
              !sensorUnavailable &&
                  lux < _lowLightThresholdLux;

          debugPrint(
            '[BackgroundService] '
                'Light lux=$lux '
                'lowLight=$lowLight',
          );

          if (sensorUnavailable) {
            unawaited(
              metrics.stop('lowLight'),
            );

            updateWarningState(
              'lowLight',
              false,
            );
          } else {
            if (lowLight) {
              metrics.start(
                'lowLight',
              );
            } else {
              unawaited(
                metrics.stop(
                  'lowLight',
                ),
              );
            }

            updateWarningState(
              'lowLight',
              lowLight,
            );
          }

          setOverlayFlag(
            'lowLight',
            lowLight,
            lightLux: lux,
          );

          service.invoke(
            'ambientLightDebug',
            {
              'lightLux': lux,
              'isLowLight': lowLight,
              'sensorUnavailableOrZero':
              sensorUnavailable,
              'ts':
              DateTime.now()
                  .toIso8601String(),
            },
          );
        },
        onError: (Object error) {
          unawaited(
            metrics.stop('lowLight'),
          );

          updateWarningState(
            'lowLight',
            false,
          );

          setOverlayFlag(
            'lowLight',
            false,
            lightLux: 0.0,
          );

          debugPrint(
            '[BackgroundService] '
                'Ambient light stream error: $error',
          );
        },
      );

  // ==========================================================================
  // NETWORK SYNC
  // ==========================================================================

  syncService.start();

  // ==========================================================================
  // DAILY EMAIL
  // ==========================================================================

  emailTimer =
      Timer.periodic(
        const Duration(
          minutes: 1,
        ),
            (_) {
          final now =
          DateTime.now();

          if (now.hour == 13 &&
              now.minute == 0) {
            final email =
                Supabase
                    .instance
                    .client
                    .auth
                    .currentUser
                    ?.email;

            if (email != null &&
                email.isNotEmpty) {
              unawaited(
                EmailReporter
                    .sendDailyReport(
                  email,
                ),
              );
            }
          }
        },
      );

  // ==========================================================================
  // STATUS PUSHES
  // ==========================================================================

  pushTimer =
      Timer.periodic(
        const Duration(
          seconds: 1,
        ),
            (_) {
          final report =
          metrics.getDailyReport();

          service.invoke(
            'status',
            {
              'running': true,
              'timestamp':
              DateTime.now()
                  .toIso8601String(),

              'hunch':
              report['hunch']
                  ?.inSeconds ??
                  0,

              'neck':
              report['neck']
                  ?.inSeconds ??
                  0,

              'wrist':
              report['wrist']
                  ?.inSeconds ??
                  0,

              'tooClose':
              report['tooClose']
                  ?.inSeconds ??
                  0,

              'lowLight':
              report['lowLight']
                  ?.inSeconds ??
                  0,

              'wristPoor':
              overlayState['wrist'],

              'wristTilt':
              overlayState['wristTilt'],

              'hunchPoor':
              overlayState['hunch'],

              'lowLightPoor':
              overlayState['lowLight'],

              'lightLux':
              overlayState['lightLux'],

              'monitoringSoundEnabled':
              monitoringSoundEnabled,
            },
          );
        },
      );

  // ==========================================================================
  // METRICS STATUS LISTENER
  // ==========================================================================

  metrics.addListener(
        () {
      service.invoke(
        'status',
        {
          'running': true,
          'metrics':
          metrics.toSeconds(),
          'timestamp':
          DateTime.now()
              .toIso8601String(),

          'wristPoor':
          overlayState['wrist'],

          'wristTilt':
          overlayState['wristTilt'],

          'hunchPoor':
          overlayState['hunch'],

          'lowLightPoor':
          overlayState['lowLight'],

          'lightLux':
          overlayState['lightLux'],

          'monitoringSoundEnabled':
          monitoringSoundEnabled,
        },
      );
    },
  );
}