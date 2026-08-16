import 'dart:ui';

double calculateDistance(Rect boundingBox) {
  const knownFaceWidthCm = 14.0;
  const referenceBoundingBoxWidthPx = 100.0;
  const referenceDistanceCm = 30.0;

  final pixelsPerCm = referenceBoundingBoxWidthPx / knownFaceWidthCm;
  final detectedFaceWidthCm = boundingBox.width / pixelsPerCm;

  return referenceDistanceCm * (referenceBoundingBoxWidthPx / boundingBox.width);
}
