import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:permission_handler/permission_handler.dart';

class AppPermissionManager {
  const AppPermissionManager._();

  static Future<bool> ensureMonitoringPermissions() async {
    final camera = await Permission.camera.request();

    debugPrint(
      '[Permissions] Camera permission: $camera',
    );

    if (!camera.isGranted) {
      if (camera.isPermanentlyDenied || camera.isRestricted) {
        await openAppSettings();
      }
      return false;
    }

    // Android 13+ notification permission is requested separately.
    // A denied notification permission should not prevent the camera service
    // from starting, but we still ask for it so the foreground-service
    // notification is visible to the user.
    final notification = await Permission.notification.request();

    debugPrint(
      '[Permissions] Notification permission: $notification',
    );

    return true;
  }

  static Future<bool> ensureOverlayPermission() async {
    final alreadyGranted =
        await FlutterOverlayWindow.isPermissionGranted();

    if (alreadyGranted) {
      return true;
    }

    final result =
        await FlutterOverlayWindow.requestPermission();

    final granted = result == true ||
        await FlutterOverlayWindow.isPermissionGranted();

    debugPrint(
      '[Permissions] Overlay permission: $granted',
    );

    return granted;
  }

  static Future<bool> ensureMicrophonePermission() async {
    final microphone =
        await Permission.microphone.request();

    debugPrint(
      '[Permissions] Microphone permission: $microphone',
    );

    if (!microphone.isGranted) {
      if (microphone.isPermanentlyDenied ||
          microphone.isRestricted) {
        await openAppSettings();
      }

      return false;
    }

    return true;
  }
}
