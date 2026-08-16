import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'face detection/face_detection_screen.dart';

class CamScreen extends StatelessWidget {
  final List<CameraDescription> cameras;
  const CamScreen({Key? key, required this.cameras}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // directly show your face detection screen
    return FaceDetectionScreen(cameras: cameras);
  }
}

