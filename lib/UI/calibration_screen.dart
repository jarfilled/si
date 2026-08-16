import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  final _supabase = Supabase.instance.client;

  File? _goodFile;
  File? _hunchedFile;
  _Stage _stage = _Stage.capturingGood;
  bool _busy = false;
  String _userGender = 'male';
  bool _hadExistingCalibration = false;

  static const mintGreen = Color(0xFF42D2A7);
  static const darkTeal = Color(0xFF145954);
  static const background = Color(0xFFF7F9F9);
  static const text = Color(0xFF263B37);
  static const subtext = Color(0xFF7D8D89);

  @override
  void initState() {
    super.initState();
    _initFuture = _initializeCameraAndUser();
  }

  Future<void> _initializeCameraAndUser() async {
    final frontCamera = widget.cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => widget.cameras.first,
    );

    _controller = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _controller.initialize();

    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final data = await _supabase
          .from('users')
          .select('hunch_divisor, gender')
          .eq('id', user.id)
          .maybeSingle();

      if (data != null) {
        _userGender = data['gender']?.toString() ?? 'male';
        _hadExistingCalibration = data['hunch_divisor'] != null;
      }
    } catch (e) {
      debugPrint('Calibration user-data error: $e');
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
      final measurement = await _monitor.measure(InputImage.fromFilePath(xfile.path));

      if (measurement == null) {
        _showAlert('تشخیص موفقیت‌آمیز نبود. صورت و شانه‌ها را داخل کادر قرار دهید و دوباره تلاش کنید.');
        return;
      }

      final ratio = measurement.verticalDistanceCm / measurement.shoulderWidthCm;

      if (_stage == _Stage.capturingGood) {
        _goodFile = File(xfile.path);
        _showAlert('تصویر صاف ثبت شد.\nنسبت اندازه‌گیری: ${ratio.toStringAsFixed(2)}');
        setState(() => _stage = _Stage.capturingHunched);
      } else {
        _hunchedFile = File(xfile.path);
        _showAlert('تصویر قوز ثبت شد.\nنسبت اندازه‌گیری: ${ratio.toStringAsFixed(2)}');
        setState(() => _stage = _Stage.review);
      }
    } catch (e) {
      _showAlert('خطا هنگام ثبت تصویر: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onVerify() async {
    if (_goodFile == null || _hunchedFile == null) {
      _showAlert('لطفاً هر دو تصویر را ثبت کنید.');
      return;
    }

    final user = _supabase.auth.currentUser;
    if (user == null) {
      _showAlert('جلسه ورود شما پیدا نشد. لطفاً دوباره وارد شوید.');
      return;
    }

    setState(() => _busy = true);

    try {
      final goodMeasurement = await _monitor.measure(InputImage.fromFilePath(_goodFile!.path));
      final hunchedMeasurement = await _monitor.measure(InputImage.fromFilePath(_hunchedFile!.path));

      if (goodMeasurement == null || hunchedMeasurement == null) {
        _showAlert('اندازه‌گیری تصاویر معتبر نیست. لطفاً هر دو تصویر را دوباره ثبت کنید.');
        return;
      }

      final divisor = goodMeasurement.shoulderWidthCm / hunchedMeasurement.verticalDistanceCm;

      if (!divisor.isFinite || divisor <= 0) {
        _showAlert('مقدار کالیبراسیون معتبر نیست. لطفاً تصاویر را دوباره ثبت کنید.');
        return;
      }

      final now = DateTime.now().toIso8601String();

      await _supabase.from('users').update({
        'hunch_divisor': divisor,
        'last_calibrated_at': now,
        'last_active_at': now,
      }).eq('id', user.id);

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
      if (mounted) _showAlert('خطا در ذخیره کالیبراسیون: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showAlert(String message) {
    showDialog<void>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('کالیبراسیون'),
          content: Text(message, textAlign: TextAlign.center, style: const TextStyle(height: 1.6)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('باشه', style: TextStyle(color: darkTeal, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showWhyDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('چرا باید این تصاویر را بگیرم؟', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: darkTeal)),
                const SizedBox(height: 14),
                const Text(
                  'سی از تصویر صاف و تصویر با قوز مختصر برای ساختن یک آستانه شخصی استفاده می‌کند. این کار باعث می‌شود هشدارهای وضعیت بدن متناسب با خود شما باشند، نه یک عدد عمومی.',
                  textAlign: TextAlign.justify,
                  style: TextStyle(color: subtext, fontSize: 13, height: 1.7),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(backgroundColor: mintGreen, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    child: const Text('متوجه شدم'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _hadExistingCalibration ? 'تنظیم دوباره وضعیت بدن' : 'کالیبراسیون وضعیت بدن';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          title: Text(title, style: const TextStyle(color: darkTeal, fontWeight: FontWeight.bold, fontSize: 18)),
          backgroundColor: background,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: darkTeal),
        ),
        body: FutureBuilder<void>(
          future: _initFuture,
          builder: (_, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator(color: mintGreen));
            }

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              child: Column(
                children: [
                  Container(
                    height: MediaQuery.of(context).size.height * .42,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(.08), blurRadius: 20, offset: const Offset(0, 8))],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(26),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (_stage != _Stage.review)
                            CameraPreview(_controller)
                          else
                            Row(
                              children: [
                                if (_goodFile != null) Expanded(child: Image.file(_goodFile!, fit: BoxFit.cover)),
                                if (_hunchedFile != null) Expanded(child: Image.file(_hunchedFile!, fit: BoxFit.cover)),
                              ],
                            ),
                          if (_stage != _Stage.review)
                            Center(
                              child: Container(
                                width: 190,
                                height: 230,
                                decoration: BoxDecoration(
                                  border: Border.all(color: mintGreen.withOpacity(.9), width: 3),
                                  borderRadius: BorderRadius.circular(22),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_stage != _Stage.review)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
                      child: Row(
                        children: [
                          Expanded(child: Column(children: [Image.asset('assets/straight.png', width: 64), const SizedBox(height: 7), const Text('صاف', style: TextStyle(color: darkTeal, fontWeight: FontWeight.bold))])),
                          Container(width: 1, height: 56, color: Colors.grey.withOpacity(.15)),
                          Expanded(child: Column(children: [Image.asset('assets/slouched.png', width: 64), const SizedBox(height: 7), const Text('قوز', style: TextStyle(color: darkTeal, fontWeight: FontWeight.bold))])),
                        ],
                      ),
                    ),
                  const SizedBox(height: 18),
                  Text(
                    _stage == _Stage.capturingGood
                        ? 'در حالت طبیعی و صاف قرار بگیر و تصویر اول را ثبت کن.'
                        : _stage == _Stage.capturingHunched
                            ? 'حالا کمی قوز کن؛ اغراق نکن و تصویر دوم را ثبت کن.'
                            : 'هر دو تصویر را بررسی کن و کالیبراسیون را تأیید کن.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: darkTeal, fontSize: 15, fontWeight: FontWeight.w600, height: 1.6),
                  ),
                  TextButton.icon(
                    onPressed: _showWhyDialog,
                    icon: const Icon(Icons.info_outline_rounded, color: mintGreen),
                    label: const Text('چرا این تصاویر لازم‌اند؟', style: TextStyle(color: mintGreen, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _busy ? null : (_stage == _Stage.review ? _onVerify : _onCapture),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: mintGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                      child: _busy
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(
                              _stage == _Stage.capturingGood
                                  ? 'ثبت تصویر صاف'
                                  : _stage == _Stage.capturingHunched
                                      ? 'ثبت تصویر قوز'
                                      : 'تأیید کالیبراسیون',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                            ),
                    ),
                  ),
                  if (_stage == _Stage.review) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton(
                        onPressed: () => setState(() {
                          _goodFile = null;
                          _hunchedFile = null;
                          _stage = _Stage.capturingGood;
                        }),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: mintGreen, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        ),
                        child: const Text('ثبت دوباره تصاویر', style: TextStyle(color: darkTeal, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
