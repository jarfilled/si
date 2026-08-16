import 'dart:math';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'metrics_manager.dart';

class NeckPostureMonitor {
  final FaceDetector _faceDetector;
  final _metrics = MetricsManager();

  NeckPostureMonitor(this._faceDetector);

  double calculateHeadTilt(Face face) {
    final leftEye = face.landmarks[FaceLandmarkType.leftEye]!.position;
    final rightEye = face.landmarks[FaceLandmarkType.rightEye]!.position;
    final nose = face.landmarks[FaceLandmarkType.noseBase]!.position;

    final eyeLine = (leftEye.x - rightEye.x).abs();
    final verticalLine = (nose.y - ((leftEye.y + rightEye.y) / 2)).abs();
    return atan2(verticalLine, eyeLine) * (180 / pi);
  }

  String checkNeckPosture(Face face) {
    final headTilt = calculateHeadTilt(face);
    if (headTilt > 33 || headTilt < 15) {
      _metrics.start('neck');
      return "Poor Neck Posture! Tilt: ${headTilt.toStringAsFixed(2)}°";
    } else {
      _metrics.stop('neck');
      return "Good Neck Posture. Tilt: ${headTilt.toStringAsFixed(2)}°";
    }
  }
}
