// lib/backend/nsfw_detection.dart

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:nsfw_detector_flutter/nsfw_detector_flutter.dart';

import '../services/background_service.dart';

class NSFWDetectionController {
  static final NSFWDetectionController _instance =
      NSFWDetectionController._internal();

  factory NSFWDetectionController() => _instance;

  NSFWDetectionController._internal();

  static const _screenshotChannel =
      MethodChannel('monitor/screenshot/capture');

  Timer? _detectionTimer;

  bool _isActive = false;
  bool _isProcessing = false;
  bool _isOverlayActive = false;

  bool _ownsOverlay = false;
  bool _hasOverlayPermission = false;

  // Incremented every time a detection run starts/stops. Any screenshot or
  // model result belonging to an older run is ignored.
  int _runGeneration = 0;

  DateTime _lastShown = DateTime.now().subtract(
    const Duration(seconds: 10),
  );

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  Future<void> init() async {
    _hasOverlayPermission =
        await FlutterOverlayWindow.isPermissionGranted();
  }

  // ---------------------------------------------------------------------------
  // Enable / disable
  // ---------------------------------------------------------------------------

  Future<bool> enable() async {
    await init();

    if (!_hasOverlayPermission) {
      final granted =
          await FlutterOverlayWindow.requestPermission();

      _hasOverlayPermission = granted == true;
    }

    if (!_hasOverlayPermission) {
      debugPrint('[NSFW] Overlay permission was not granted.');
      return false;
    }

    start();
    return true;
  }

  Future<void> disable() async {
    stop();
    await _closeOverlay(forceClose: true);
  }

  // ---------------------------------------------------------------------------
  // Start / stop
  // ---------------------------------------------------------------------------

  void start() {
    if (_isActive) return;

    if (!_hasOverlayPermission) {
      debugPrint('[NSFW] Cannot start: overlay permission missing.');
      return;
    }

    _isActive = true;
    final generation = ++_runGeneration;

    _detectionTimer?.cancel();
    _detectionTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _captureAndDetect(generation),
    );

    debugPrint('[NSFW] Detection started');
  }

  void stop() {
    _isActive = false;
    ++_runGeneration;

    _detectionTimer?.cancel();
    _detectionTimer = null;

    debugPrint('[NSFW] Detection stopped');
  }

  // ---------------------------------------------------------------------------
  // Screenshot + detection
  // ---------------------------------------------------------------------------

  Future<void> _captureAndDetect(int generation) async {
    if (!_isActive ||
        generation != _runGeneration ||
        _isProcessing ||
        !_hasOverlayPermission) {
      return;
    }

    // There is no value in taking another screenshot while the NSFW warning is
    // already covering the screen. More importantly, this keeps the screenshot
    // capture/model pipeline completely idle while the user is dismissing it.
    if (_isOverlayActive) {
      if (!await FlutterOverlayWindow.isActive()) {
        _isOverlayActive = false;
        _ownsOverlay = false;
        BackgroundMonitorService.setNsfwOverlayActive(false);
      } else {
        return;
      }
    }

    _isProcessing = true;

    try {
      final b64 =
          await _screenshotChannel.invokeMethod<String>('captureScreen');

      if (b64 == null ||
          !_isActive ||
          generation != _runGeneration) {
        return;
      }

      // Keep the expensive model work off the UI isolate. The screenshot
      // capture itself remains every 5 seconds, as requested.
      final imageBytes = base64Decode(b64);

      if (imageBytes.isEmpty ||
          !_isActive ||
          generation != _runGeneration) {
        return;
      }

      final result =
          await NsfwDetector.detectBytesInBackground(imageBytes);

      if (!_isActive || generation != _runGeneration) {
        return;
      }

      debugPrint('[NSFW] Detected: ${result?.isNsfw}');

      final now = DateTime.now();

      if (result?.isNsfw == true &&
          !_isOverlayActive &&
          now.difference(_lastShown).inSeconds > 10) {
        _lastShown = now;
        await _showOverlay();
      }
    } on PlatformException catch (e) {
      debugPrint(
        '[NSFW] Platform detection error: ${e.code}: ${e.message}',
      );
    } catch (e, stackTrace) {
      debugPrint('[NSFW] Detection error: $e');
      debugPrint('$stackTrace');
    } finally {
      _isProcessing = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Overlay HUD
  // ---------------------------------------------------------------------------

  Future<void> _showOverlay() async {
    if (!_isActive ||
        !_hasOverlayPermission ||
        _isOverlayActive) {
      return;
    }

    try {
      BackgroundMonitorService.setNsfwOverlayActive(true);

      // The posture HUD uses a click-through window. Recreate it as a normal
      // window so the NSFW warning is fully interactive.
      if (await FlutterOverlayWindow.isActive()) {
        await FlutterOverlayWindow.closeOverlay();
        await Future<void>.delayed(
          const Duration(milliseconds: 100),
        );
      }

      await FlutterOverlayWindow.showOverlay(
        height: 800,
        alignment: OverlayAlignment.center,
        flag: OverlayFlag.defaultFlag,
        visibility: NotificationVisibility.visibilityPublic,
        positionGravity: PositionGravity.auto,
      );

      _ownsOverlay = true;

      await Future<void>.delayed(
        const Duration(milliseconds: 150),
      );

      _isOverlayActive = true;

      await FlutterOverlayWindow.shareData({
        'type': 'nsfw',
      });

      debugPrint('[NSFW] NSFW HUD displayed');
    } catch (e, stackTrace) {
      debugPrint('[NSFW] Failed to show HUD: $e');
      debugPrint('$stackTrace');

      _isOverlayActive = false;
      _ownsOverlay = false;
      BackgroundMonitorService.setNsfwOverlayActive(false);
    }
  }

  Future<void> _closeOverlay({
    bool forceClose = false,
  }) async {
    if (!_isOverlayActive && !forceClose) {
      return;
    }

    try {
      if (await FlutterOverlayWindow.isActive()) {
        await FlutterOverlayWindow.closeOverlay();
      }
    } catch (e) {
      debugPrint('[NSFW] Error closing HUD: $e');
    } finally {
      _isOverlayActive = false;
      _ownsOverlay = false;
      BackgroundMonitorService.setNsfwOverlayActive(false);
      debugPrint('[NSFW] NSFW HUD cleared');
    }
  }
}
