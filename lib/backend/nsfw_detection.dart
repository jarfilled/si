// lib/backend/nsfw_detection.dart

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:image/image.dart' as img;
import 'package:nsfw_detector_flutter/nsfw_detector_flutter.dart';

import '../services/background_service.dart';

class NSFWDetectionController {
  static final NSFWDetectionController _instance =
  NSFWDetectionController._internal();

  factory NSFWDetectionController() => _instance;

  NSFWDetectionController._internal();

  static const _screenshotChannel =
  MethodChannel('monitor/screenshot/capture');

  static const _controlChannel =
  MethodChannel('com.example.overlay/control');

  NsfwDetector? _detector;

  Timer? _detectionTimer;

  bool _isActive = false;
  bool _isProcessing = false;
  bool _isOverlayActive = false;

  // True whenever NSFW currently owns the overlay window (which, since
  // we always close-and-recreate rather than reuse, is true any time
  // _isOverlayActive is true).
  bool _ownsOverlay = false;

  bool _hasOverlayPermission = false;

  DateTime _lastShown =
  DateTime.now().subtract(
    const Duration(seconds: 10),
  );

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  Future<void> init() async {
    _detector ??= await NsfwDetector.load();

    _hasOverlayPermission =
    await FlutterOverlayWindow.isPermissionGranted();

    _controlChannel.setMethodCallHandler(
          (call) async {
        if (call.method == 'resumeDetection') {
          debugPrint(
            '[NSFW] Resuming detection via control channel',
          );

          // Fully tear down the overlay we created for the warning
          // (rather than just flipping local flags) so the background
          // service is told NSFW mode has ended and, if a posture
          // warning is still active, its click-through HUD can be
          // recreated on its next tick.
          await _closeOverlay();

          if (!_isActive) {
            start();
          }
        }
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Enable / disable
  // ---------------------------------------------------------------------------

  Future<bool> enable() async {
    await init();

    // Overlay permission is an Android app permission and should only
    // be requested if it is genuinely missing.
    if (!_hasOverlayPermission) {
      final granted =
      await FlutterOverlayWindow.requestPermission();

      _hasOverlayPermission = granted == true;
    }

    if (!_hasOverlayPermission) {
      debugPrint(
        '[NSFW] Overlay permission was not granted.',
      );

      return false;
    }

    start();

    return true;
  }

  Future<void> disable() async {
    stop();

    await _closeOverlay(
      forceClose: true,
    );
  }

  // ---------------------------------------------------------------------------
  // Start / stop
  // ---------------------------------------------------------------------------

  void start() {
    if (_isActive) return;

    if (!_hasOverlayPermission) {
      debugPrint(
        '[NSFW] Cannot start: overlay permission missing.',
      );
      return;
    }

    _isActive = true;

    _detectionTimer?.cancel();

    _detectionTimer = Timer.periodic(
      const Duration(seconds: 5),
          (_) => _captureAndDetect(),
    );

    debugPrint('[NSFW] Detection started');
  }

  void stop() {
    _isActive = false;

    _detectionTimer?.cancel();
    _detectionTimer = null;

    debugPrint('[NSFW] Detection stopped');
  }

  // ---------------------------------------------------------------------------
  // Screenshot + detection
  // ---------------------------------------------------------------------------

  Future<void> _captureAndDetect() async {
    if (!_isActive ||
        _isProcessing ||
        _detector == null ||
        !_hasOverlayPermission) {
      return;
    }

    _isProcessing = true;

    try {
      final b64 =
      await _screenshotChannel.invokeMethod<String>(
        'captureScreen',
      );

      if (b64 == null || !_isActive) {
        return;
      }

      final image =
      img.decodeImage(base64Decode(b64));

      if (image == null || !_isActive) {
        return;
      }

      final result =
      await _detector!.detectNSFWFromImage(image);

      debugPrint(
        '[NSFW] Detected: ${result?.isNsfw}',
      );

      final now = DateTime.now();

      if (result?.isNsfw == true &&
          !_isOverlayActive &&
          now.difference(_lastShown).inSeconds > 10) {
        _lastShown = now;

        await _showOverlay();
      }
    } on PlatformException catch (e) {
      debugPrint(
        '[NSFW] Platform detection error: '
            '${e.code}: ${e.message}',
      );
    } catch (e, stackTrace) {
      debugPrint(
        '[NSFW] Detection error: $e',
      );

      debugPrint(
        '$stackTrace',
      );
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
      // Tell the background service isolate immediately. It runs its
      // own overlay lifecycle loop off continuous posture/sensor
      // streams, so it can otherwise close this overlay out from under
      // us within milliseconds. Sending this first gives the
      // cross-isolate message the maximum time to land before that
      // loop's next tick.
      BackgroundMonitorService.setNsfwOverlayActive(true);

      // Whatever overlay might currently be showing (the posture HUD)
      // was created with OverlayFlag.clickThrough, so its dismiss
      // button would be untappable if we just reused it. The plugin
      // can't change a live overlay's flag, so always close whatever's
      // there and recreate it non-click-through instead of reusing it.
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
        visibility:
        NotificationVisibility.visibilityPublic,
        positionGravity: PositionGravity.auto,
      );

      _ownsOverlay = true;

      // Give the overlay isolate a moment to initialize.
      await Future<void>.delayed(
        const Duration(milliseconds: 150),
      );

      _isOverlayActive = true;

      // Tell the new OverlayHud instance to switch to NSFW mode.
      await FlutterOverlayWindow.shareData({
        'type': 'nsfw',
      });

      debugPrint(
        '[NSFW] NSFW HUD displayed',
      );

    } catch (e, stackTrace) {
      debugPrint(
        '[NSFW] Failed to show HUD: $e',
      );

      debugPrint(
        '$stackTrace',
      );

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
        // Tell the HUD that NSFW mode is over, then close the window.
        // We always own it while it's showing the warning (we never
        // reuse an existing overlay — see _showOverlay), so it's
        // always safe for us to close it here.
        await FlutterOverlayWindow.shareData({
          'type': 'none',
        });

        await FlutterOverlayWindow.closeOverlay();
      }
    } catch (e) {
      debugPrint(
        '[NSFW] Error closing HUD: $e',
      );
    } finally {
      _isOverlayActive = false;
      _ownsOverlay = false;

      // Let the background service know NSFW no longer owns the
      // overlay, so its posture loop can recreate a click-through HUD
      // if a posture warning is still active.
      BackgroundMonitorService.setNsfwOverlayActive(false);

      debugPrint(
        '[NSFW] NSFW HUD cleared',
      );
    }
  }
}