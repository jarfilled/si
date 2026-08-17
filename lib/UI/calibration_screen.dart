// lib/UI/calibration_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../backend/hunch_monitor.dart';

enum _Stage { capturingGood, capturingHunched, review }

class CalibrationScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const CalibrationScreen({super.key, required this.cameras});

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  late CameraController _controller;
  late Future<void> _initFuture;
  final _monitor = HumpPostureMonitor();

  File? _goodFile, _hunchedFile;
  _Stage _stage = _Stage.capturingGood;
  bool _busy = false;
  String _userGender = 'male';

  final supabase = Supabase.instance.client;

  static const Color mintGreen = Color(0xFF42D2A7);
  static const Color darkTeal = Color(0xFF145954);
  static const Color backgroundLight = Color(0xFFF7F9F9);

  @override
  void initState() {
    super.initState();
    _initFuture = _initializeCameraAndUser();
  }

  Future<void> _initializeCameraAndUser() async {
    final frontCamera = widget.cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => widget.cameras.first,
    );
    _controller = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    await _controller.initialize();

    final user = supabase.auth.currentUser;
    if (user != null) {
      try {
        final data = await supabase
            .from('users')
            .select('hunch_divisor, gender')
            .eq('id', user.id)
            .maybeSingle();

        if (data != null) {
          if (data['gender'] != null) {
            _userGender = data['gender'] as String;
          }

          if (data['hunch_divisor'] != null) {
            if (mounted) {
              Navigator.pushReplacementNamed(
                context,
                '/dashboard',
                arguments: _userGender,
              );
            }
          }
        }
      } catch (e) {
        debugPrint('Error fetching user data: $e');
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _monitor.dispose();
    super.dispose();
  }

  Future<void> _onCapture() async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      final xfile = await _controller.takePicture();
      final image = InputImage.fromFilePath(xfile.path);
      final m = await _monitor.measure(image);

      if (m == null) {
        _showAlert('تشخیص موفقیت‌آمیز نبود. دوباره تلاش کنید.');
        return;
      }

      final ratio = m.verticalDistanceCm / m.shoulderWidthCm;

      if (_stage == _Stage.capturingGood) {
        _goodFile = File(xfile.path);
        _showAlert('تصویر صاف ثبت شد!\nنسبت: ${ratio.toStringAsFixed(2)}');
        setState(() => _stage = _Stage.capturingHunched);
      } else {
        _hunchedFile = File(xfile.path);
        _showAlert('تصویر قوز ثبت شد!\nنسبت: ${ratio.toStringAsFixed(2)}');
        setState(() => _stage = _Stage.review);
      }
    } catch (e) {
      _showAlert('خطا: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onVerify() async {
    if (_goodFile == null || _hunchedFile == null) {
      _showAlert('لطفاً هر دو تصویر را ثبت کنید.');
      return;
    }

    final user = supabase.auth.currentUser;
    if (user == null) {
      _showAlert('جلسه ورود شما پیدا نشد. لطفاً دوباره وارد شوید.');
      return;
    }

    setState(() => _busy = true);

    try {
      final goodMeasurement = await _monitor.measure(
        InputImage.fromFilePath(_goodFile!.path),
      );

      final hunchedMeasurement = await _monitor.measure(
        InputImage.fromFilePath(_hunchedFile!.path),
      );

      if (goodMeasurement == null || hunchedMeasurement == null) {
        _showAlert('خطا در اندازه‌گیری تصاویر. لطفاً دوباره تصاویر را ثبت کنید.');
        return;
      }

      final divisor =
          goodMeasurement.shoulderWidthCm / hunchedMeasurement.verticalDistanceCm;

      if (!divisor.isFinite || divisor <= 0) {
        _showAlert('مقدار کالیبراسیون معتبر نیست. لطفاً تصاویر را دوباره ثبت کنید.');
        return;
      }

      await supabase
          .from('users')
          .update({
        'hunch_divisor': divisor,
        'last_calibrated_at': DateTime.now().toIso8601String(),
      })
          .eq('id', user.id);

      if (!mounted) return;

      await _controller.dispose();

      if (!mounted) return;

      Navigator.pushReplacementNamed(
        context,
        '/dashboard',
        arguments: _userGender,
      );
    } catch (e) {
      debugPrint('Calibration save error: $e');

      if (mounted) {
        _showAlert('خطا در ذخیره کالیبراسیون: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _showAlert(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Text(msg, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('باشه', style: TextStyle(color: darkTeal)),
          ),
        ],
      ),
    );
  }

  void _showWhyDialog() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'چرا باید این تصاویر را بگیرم؟',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: darkTeal),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'برای تنظیم دقیق نسبت چانه به شانه و تشخیص وضعیت شما، نیاز است که تصویر صاف و تصویر با قوز مختصر از زاویهٔ مناسب ثبت شود. این اطلاعات به ما کمک می‌کند تا الگوریتم وضعیت بدن شما را به‌درستی کالیبره کند و هشدارهای مناسبی در طول استفاده از اپ بدهد.',
                textAlign: TextAlign.justify,
                style: TextStyle(fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mintGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('متوجه شدم', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundLight,
      appBar: AppBar(
        title: const Text('کالیبراسیون وضعیت بدن', style: TextStyle(color: darkTeal, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: backgroundLight,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: darkTeal),
      ),
      body: FutureBuilder<void>(
        future: _initFuture,
        builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: mintGreen));
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final horizontalPadding = width < 360 ? 12.0 : width < 600 ? 20.0 : 28.0;
              final previewHeight = (constraints.maxHeight * 0.42).clamp(250.0, 480.0).toDouble();
              final guideWidth = (width - horizontalPadding * 2).clamp(150.0, 260.0).toDouble();
              final guideHeight = (guideWidth * 1.18).clamp(180.0, 300.0).toDouble();
              final compact = width < 380;

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(vertical: 14, horizontal: horizontalPadding),
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: SizedBox(
                          width: double.infinity,
                          height: previewHeight,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (_stage != _Stage.review)
                                CameraPreview(_controller)
                              else
                                Row(
                                  children: [
                                    if (_goodFile != null)
                                      Expanded(child: Image.file(_goodFile!, fit: BoxFit.cover)),
                                    if (_hunchedFile != null)
                                      Expanded(child: Image.file(_hunchedFile!, fit: BoxFit.cover)),
                                  ],
                                ),
                              if (_stage != _Stage.review)
                                Center(
                                  child: Container(
                                    width: guideWidth,
                                    height: guideHeight,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: mintGreen.withValues(alpha: 0.8), width: compact ? 2 : 3),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    if (_stage != _Stage.review)
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: compact ? 12 : 16, horizontal: compact ? 14 : 24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Flexible(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Image.asset('assets/straight.png', width: compact ? 54 : 70),
                                  const SizedBox(height: 7),
                                  const Text('صاف', style: TextStyle(color: darkTeal, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            Container(width: 1, height: 56, color: Colors.grey.withValues(alpha: 0.2)),
                            Flexible(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Image.asset('assets/slouched.png', width: compact ? 54 : 70),
                                  const SizedBox(height: 7),
                                  const Text('قوز', style: TextStyle(color: darkTeal, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 20),

                    Text(
                      _stage == _Stage.capturingGood
                          ? 'سر خود را در کادر قرار دهید و روی «ثبت تصویر صاف» بزنید.'
                          : _stage == _Stage.capturingHunched
                              ? 'اکنون کمی قوز کنید و روی «ثبت تصویر قوز» بزنید.'
                              : 'تصاویر را بررسی کنید و سپس روی «تأیید نهایی» بزنید.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: compact ? 14 : 16, color: darkTeal, height: 1.5, fontWeight: FontWeight.w500),
                    ),

                    const SizedBox(height: 6),

                    TextButton.icon(
                      onPressed: _showWhyDialog,
                      icon: const Icon(Icons.info_outline_rounded, color: mintGreen, size: 20),
                      label: const Flexible(
                        child: Text(
                          'چرا باید این تصاویر را بگیرم؟',
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: mintGreen, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      height: compact ? 52 : 56,
                      child: ElevatedButton(
                        onPressed: _busy ? null : (_stage == _Stage.review ? _onVerify : _onCapture),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: mintGreen,
                          elevation: 2,
                          shadowColor: mintGreen.withValues(alpha: 0.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _busy
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white))
                            : Text(
                                _stage == _Stage.review ? 'تأیید نهایی' : 'ثبت تصویر',
                                style: TextStyle(fontSize: compact ? 15 : 16, color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),

                    if (_stage == _Stage.review) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: compact ? 52 : 56,
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _goodFile = null;
                              _hunchedFile = null;
                              _stage = _Stage.capturingGood;
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: mintGreen, width: 2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Text('دوباره ثبت کن', style: TextStyle(color: darkTeal, fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
