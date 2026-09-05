/*import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:flutter/material.dart';

Future<InputImage?> convertCameraImageToInputImage(CameraImage image, CameraController controller) async {
  try {
    final rotation = InputImageRotationValue.fromRawValue(
      controller.description.sensorOrientation,
    ) ?? InputImageRotation.rotation0deg;

    final bytes = _concatenatePlanes(image.planes);
    final metadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: InputImageFormat.nv21,
      bytesPerRow: image.planes.first.bytesPerRow,
    );

    return InputImage.fromBytes(bytes: bytes, metadata: metadata);
  } catch (_) {
    return null;
  }
}

Uint8List _concatenatePlanes(List<Plane> planes) {
  final allBytes = <int>[];
  for (final plane in planes) {
    allBytes.addAll(plane.bytes);
  }
  return Uint8List.fromList(allBytes);
}
 */