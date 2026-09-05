
import 'dart:math';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // جایگزین فایربیس
import 'metrics_manager.dart';

double convertPixelsToCm({
  required double pixelValue,
  required double referencePixelValue,
  required double knownValueCm,
}) {
  final pixelsPerCm = referencePixelValue / knownValueCm;
  return pixelValue / pixelsPerCm;
}

class Measurement {
  final double shoulderWidthCm;
  final double verticalDistanceCm;
  Measurement(this.shoulderWidthCm, this.verticalDistanceCm);
}

class HumpPostureMonitor {
  final PoseDetector _poseDetector;
  final _metrics = MetricsManager();

  static const _knownShoulderWidthCm = 40.0;
  static const _referenceShoulderWidthPx = 150.0;

  double? _divisor;

  HumpPostureMonitor()
      : _poseDetector = PoseDetector(
    options: PoseDetectorOptions(mode: PoseDetectionMode.stream),
  );

  Future<Measurement?> measure(InputImage image) async {
    final poses = await _poseDetector.processImage(image);
    if (poses.isEmpty) return null;
    final pose = poses.first;

    final l = pose.landmarks, r = pose.landmarks;
    final leftShoulder = l[PoseLandmarkType.leftShoulder];
    final rightShoulder = r[PoseLandmarkType.rightShoulder];
    if (leftShoulder == null || rightShoulder == null) return null;

    final midY = (leftShoulder.y + rightShoulder.y) / 2;
    final shoulderPx = (rightShoulder.x - leftShoulder.x).abs();
    final shoulderCm = convertPixelsToCm(
      pixelValue: shoulderPx,
      referencePixelValue: _referenceShoulderWidthPx,
      knownValueCm: _knownShoulderWidthCm,
    );

    double landmarkY;
    final le = pose.landmarks[PoseLandmarkType.leftEar];
    final re = pose.landmarks[PoseLandmarkType.rightEar];
    if (le != null && re != null) {
      landmarkY = (le.y + re.y) / 2;
    } else {
      final nose = pose.landmarks[PoseLandmarkType.nose];
      if (nose == null) return null;
      landmarkY = nose.y;
    }
    final verticalPx = (landmarkY - midY).abs();
    final verticalCm = convertPixelsToCm(
      pixelValue: verticalPx,
      referencePixelValue: _referenceShoulderWidthPx,
      knownValueCm: _knownShoulderWidthCm,
    );

    return Measurement(shoulderCm, verticalCm);
  }

  Future<void> loadDivisor() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) return;

    try {
      final response = await supabase
          .from('users')
          .select('hunchDivisor')
          .eq('id', user.id)
          .single();

      if (response['hunchDivisor'] != null) {
        _divisor = (response['hunchDivisor'] as num).toDouble();
      }
    } catch (e) {
      print("Error loading hunch divisor from Supabase: $e");
    }
  }

  Future<String> analyzePosture(InputImage img) async {
    if (_divisor == null) await loadDivisor();
    if (_divisor == null) return 'Not calibrated';

    final m = await measure(img);
    if (m == null) return 'Detection failed';

    if (m.verticalDistanceCm < (m.shoulderWidthCm / _divisor!)) {
      _metrics.start('hunch');
      return 'Warning: Hunched Back Detected!';
    } else {
      _metrics.stop('hunch');
      return 'Good Posture.';
    }
  }

  Future<void> dispose() => _poseDetector.close();
}
