 /*
  import 'package:flutter/material.dart';
  import 'package:camera/camera.dart';
  import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
  import 'package:flutter_overlay_window/flutter_overlay_window.dart';
  import 'package:monitor/backend/neck_posture_monitor.dart';
  import 'package:monitor/backend/wrist_posture_monitor.dart';
  import 'package:monitor/backend/hunch_monitor.dart';

  import 'camera_utils.dart';
  import 'distance_calculator.dart';

  class FaceDetectionScreen extends StatefulWidget {
    final List<CameraDescription> cameras;

    const FaceDetectionScreen({Key? key, required this.cameras})
        : super(key: key);

    static Future<InputImage> captureOnce(List<CameraDescription> cameras) async {
      // 1) set up controller
      final controller = CameraController(
        cameras[0],
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller
          .initialize(); // initialize the camera :contentReference[oaicite:0]{index=0}

      // 2) take a picture
      final XFile file = await controller
          .takePicture(); // returns XFile :contentReference[oaicite:1]{index=1}

      // 3) dispose immediately to free resources
      await controller.dispose();

      // 4) wrap the file path in an InputImage for ML Kit
      return InputImage.fromFilePath(
          file.path); // :contentReference[oaicite:2]{index=2}
    }

    @override
    State<FaceDetectionScreen> createState() => _FaceDetectionScreenState();
  }

  class _FaceDetectionScreenState extends State<FaceDetectionScreen> {
    late CameraController _cameraController;
    late FaceDetector _faceDetector;
    late NeckPostureMonitor _neckPostureMonitor;
    late WristPostureMonitor _wristPostureMonitor;
    late HumpPostureMonitor _humpPostureMonitor;
    bool _isDetecting = false;
    String _lightLevelMessage = "Light level: Unknown";
    String _humpPostureMessage = "Back posture: Unknown";
    String _distanceMessage = "Position your face in front of the camera";
    String _neckPostureMessage = "Neck posture: Unknown";
    String _wristPostureMessage = "Wrist posture: Unknown";
    String _postureMessage = "Posture: Good";
    bool _isOverlayActive = false;

    @override
    void initState() {
      super.initState();
      _initializeCamera();
      _initializeFaceDetector();
      _initializePostureMonitors();
     // _initializeAmbientLightMonitor();
      _humpPostureMonitor = HumpPostureMonitor();
    }
    /*
    Future<void> _initializeAmbientLightMonitor() async {
      _ambientLightMonitor =
          AmbientLightMonitor(onLightLevelChanged: (String) {});
      await _ambientLightMonitor
          .initialize(); // Start listening to ambient light stream
    }
     */

    Future<void> _initializeCamera() async {

      final frontCamera = widget.cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => widget.cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.low,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController.initialize();

      _cameraController.startImageStream((cameraImage) async {
        if (!_isDetecting) {
          _isDetecting = true;
          await _processCameraImage(cameraImage);
          _isDetecting = false;
        }
      });

      setState(() {});
    }

    Future<void> _initializeFaceDetector() async {
      _faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          performanceMode: FaceDetectorMode.accurate,
          enableLandmarks: true,
        ),
      );
    }

    void _initializePostureMonitors() {
      _neckPostureMonitor = NeckPostureMonitor(_faceDetector);
      _wristPostureMonitor = WristPostureMonitor();
    }

    Future<void> _processCameraImage(CameraImage image) async {
      final inputImage =
          await convertCameraImageToInputImage(image, _cameraController);
      if (inputImage == null) return;

      final faces = await _faceDetector.processImage(inputImage);

      final posePostureMessage =
          await _humpPostureMonitor.analyzePosture(inputImage);

      setState(() {
        _humpPostureMessage = posePostureMessage;
      });

      if (faces.isNotEmpty) {
        final distance = calculateDistance(faces.first.boundingBox);
        final neckTilt = _neckPostureMonitor.calculateHeadTilt(faces.first);
        // final wristTilt = _wristPostureMonitor.getWristTilt();

        // Evaluate posture correlation
       // _evaluatePosture(neckTilt, wristTilt);

        setState(() {
          _distanceMessage = "Distance: ${distance.toStringAsFixed(2)} cm";
          _neckPostureMessage = _neckPostureMonitor.checkNeckPosture(faces.first);
         // _wristPostureMessage = _wristPostureMonitor.checkWristPosture();

          if (distance < 30.0 && !_isOverlayActive) {
            _showOverlay();
          } else if (distance >= 30.0 && _isOverlayActive) {
            _closeOverlay();
          }
        });
      } else {
        setState(() {
          _distanceMessage = "No face detected. Please position your face.";
          _neckPostureMessage = "Neck posture: Unknown";
  //        _wristPostureMessage = _wristPostureMonitor
         //     .checkWristPosture(); // Still monitor wrist posture
          _postureMessage = "Posture: Unknown";
          _closeOverlay();
        });
      }
    }

    void _evaluatePosture(double neckTilt, double wristTilt) {
      // Define thresholds
      final bool isPoorNeckPosture = neckTilt > 50 || neckTilt < 10;
      final bool isModerateNeckPosture = neckTilt > 40 || neckTilt < 20;
      final bool isPoorWristPosture = wristTilt > 110 || wristTilt < 50;
      final bool isModerateWristPosture = wristTilt > 95 || wristTilt < -65;

      // Correlation logic
      if (isPoorNeckPosture && isPoorWristPosture) {
        setState(() {
          _postureMessage = "Warning: Poor Neck and Wrist Posture!";
        });
      } else if (isPoorNeckPosture) {
        setState(() {
          _postureMessage = "Warning: Poor Neck Posture!";
        });
      } else if (isPoorWristPosture) {
        setState(() {
          _postureMessage = "Warning: Poor Wrist Posture!";
        });
      } else if (isModerateNeckPosture && isModerateWristPosture) {
        setState(() {
          _postureMessage = "Moderate Neck and Wrist Tilt.";
        });
      } else if (isModerateNeckPosture) {
        setState(() {
          _postureMessage = "Moderate Neck Tilt.";
        });
      } else if (isModerateWristPosture) {
        setState(() {
          _postureMessage = "Moderate Wrist Tilt.";
        });
      } else {
        setState(() {
          _postureMessage = "Good Posture Maintained.";
        });
      }

      // Handle edge cases (e.g., neck tilted backward while holding phone in front)
      final relativeAngle = (neckTilt - wristTilt).abs();
      if (relativeAngle > 60) {
        setState(() {
          _postureMessage = "Warning: Extreme Neck-Wrist Angle Detected!";
        });
      }
    }

    Future<void> _showOverlay() async {
      bool isGranted = await FlutterOverlayWindow.isPermissionGranted();

      if (!isGranted) {
        isGranted = (await FlutterOverlayWindow.requestPermission())!;
      }

      if (isGranted) {
        setState(() {
          _isOverlayActive = true;
        });
        await FlutterOverlayWindow.showOverlay(
          height: 3000, // Adjust to fit the red dot size
          width: 3000,
          flag: OverlayFlag.clickThrough,
          alignment: OverlayAlignment.center,
          overlayTitle: "Red Dot Overlay",
          overlayContent: "Overlay active",
          enableDrag: false,
        );
      }
    }

    Future<void> _closeOverlay() async {
      await FlutterOverlayWindow.closeOverlay();
      setState(() {
        _isOverlayActive = false;
      });
    }

    @override
    void dispose() {
      _cameraController.dispose();
      _faceDetector.close();
      _closeOverlay();
      super.dispose();
    }

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Posture and Distance Monitor'),
        ),
        body: Stack(
          children: [
            _cameraController.value.isInitialized
                ? CameraPreview(_cameraController)
                : const Center(child: CircularProgressIndicator()),
            Positioned(
              bottom: 150,
              left: 20,
              right: 20,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _distanceMessage,
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _neckPostureMessage,
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _wristPostureMessage,
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _postureMessage,
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _lightLevelMessage,
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _humpPostureMessage,
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  */