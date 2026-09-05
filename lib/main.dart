// lib/main.dart

import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:monitor/UI/calibration_screen.dart';
import 'package:monitor/UI/dashboard.dart';
import 'package:monitor/UI/login_page.dart';
import 'package:monitor/UI/onBoarding.dart';
import 'package:monitor/UI/signup_page.dart';
import 'package:monitor/UI/splashScreen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://rdlxrnnvebkmldqoedpf.supabase.co',
    anonKey: 'sb_publishable_TURWbpzn8fbkv304X0KP3Q_69o-3vka',
  );

  final cameras = await availableCameras();
  runApp(MyApp(cameras: cameras));
}

Future<void> changeDNS() async {
  const platform = MethodChannel('monitor/dns');

  try {
    await platform.invokeMethod('changeDNS');
  } on PlatformException catch (e) {
    debugPrint("Failed to change DNS: '${e.message}'.");
  }
}

@pragma('vm:entry-point')
void overlayMain() {
  runApp(const OverlayHudApp());
}

class OverlayHudApp extends StatelessWidget {
  const OverlayHudApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: OverlayHud(),
    );
  }
}

class OverlayHud extends StatefulWidget {
  const OverlayHud({super.key});

  @override
  State<OverlayHud> createState() => _OverlayHudState();
}

class _OverlayHudState extends State<OverlayHud> {
  static const _indicatorShowDelay = Duration(milliseconds: 500);
  static const _indicatorHideGrace = Duration(milliseconds: 700);

  bool _showTooClose = false;
  bool _showNeck = false;
  bool _showWrist = false;
  bool _showHunch = false;
  bool _showLowLight = false;
  bool _showNsfw = false;

  Timer? _indicatorShowTimer;
  Timer? _indicatorHideTimer;

  bool get _hasPostureIndicator =>
      _showTooClose ||
      _showNeck ||
      _showWrist ||
      _showHunch ||
      _showLowLight;

  @override
  void initState() {
    super.initState();
    _listenForOverlayData();
  }

  void _listenForOverlayData() {
    FlutterOverlayWindow.overlayListener.listen((dynamic data) {
      if (!mounted) return;

      if (data is Map) {
        final map = Map<dynamic, dynamic>.from(data);
        final type = map['type']?.toString();

        bool readBool(String key) {
          final value = map[key];
          if (value is bool) return value;
          if (value is num) return value != 0;
          return value?.toString().toLowerCase() == 'true';
        }

        final tooClose = readBool('tooClose');
        final neck = readBool('neck');
        final wrist = readBool('wrist') || readBool('wristPoor');
        final hunch = readBool('hunch') || readBool('hunchPoor');
        final lowLight = readBool('lowLight') || readBool('lowLightPoor');

        setState(() {
          if (type == 'nsfw') {
            _showNsfw = true;
          } else if (type == 'none') {
            _showNsfw = false;
          }
        });

        if (type == 'none') {
          _cancelPostureIndicatorTimers();
          if (_hasPostureIndicator) {
            setState(() {
              _showTooClose = false;
              _showNeck = false;
              _showWrist = false;
              _showHunch = false;
              _showLowLight = false;
            });
          }
          return;
        }

        _updatePostureIndicators(
          tooClose: tooClose,
          neck: neck,
          wrist: wrist,
          hunch: hunch,
          lowLight: lowLight,
        );
        return;
      }

      if (data is String) {
        if (data == 'nsfw') {
          setState(() => _showNsfw = true);
        } else if (data == 'none') {
          _cancelPostureIndicatorTimers();
          setState(() {
            _showNsfw = false;
            _showTooClose = false;
            _showNeck = false;
            _showWrist = false;
            _showHunch = false;
            _showLowLight = false;
          });
        }
      }
    });
  }

  void _updatePostureIndicators({
    required bool tooClose,
    required bool neck,
    required bool wrist,
    required bool hunch,
    required bool lowLight,
  }) {
    final hasWarning =
        tooClose || neck || wrist || hunch || lowLight;

    if (hasWarning) {
      _indicatorHideTimer?.cancel();
      _indicatorHideTimer = null;

      if (_hasPostureIndicator) {
        // Once visible, update active warning icons immediately. The grace
        // period above prevents them from disappearing during brief recovery.
        setState(() {
          _showTooClose = tooClose;
          _showNeck = neck;
          _showWrist = wrist;
          _showHunch = hunch;
          _showLowLight = lowLight;
        });
        return;
      }

      // A transient detector spike must persist before becoming visible.
      _indicatorShowTimer ??= Timer(
        _indicatorShowDelay,
        () {
          _indicatorShowTimer = null;
          if (!mounted) return;

          setState(() {
            _showTooClose = tooClose;
            _showNeck = neck;
            _showWrist = wrist;
            _showHunch = hunch;
            _showLowLight = lowLight;
          });
        },
      );
      return;
    }

    _indicatorShowTimer?.cancel();
    _indicatorShowTimer = null;

    if (_hasPostureIndicator) {
      // Keep the HUD visible briefly after a warning clears so it doesn't
      // rapidly pop in/out while the detector hovers around its threshold.
      _indicatorHideTimer?.cancel();
      _indicatorHideTimer = Timer(
        _indicatorHideGrace,
        () {
          _indicatorHideTimer = null;
          if (!mounted) return;

          setState(() {
            _showTooClose = false;
            _showNeck = false;
            _showWrist = false;
            _showHunch = false;
            _showLowLight = false;
          });
        },
      );
    }
  }

  void _cancelPostureIndicatorTimers() {
    _indicatorShowTimer?.cancel();
    _indicatorShowTimer = null;
    _indicatorHideTimer?.cancel();
    _indicatorHideTimer = null;
  }

  @override
  void dispose() {
    _cancelPostureIndicatorTimers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 6, right: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_showTooClose)
                      _indicatorCircle(Icons.remove_red_eye, Colors.orange),
                    if (_showLowLight)
                      _indicatorCircle(Icons.light_mode, Colors.amber),
                    if (_showNeck)
                      _indicatorCircle(Icons.accessibility_new, Colors.blue),
                    if (_showHunch)
                      _indicatorCircle(
                        Icons.airline_seat_recline_normal,
                        Colors.teal,
                      ),
                    if (_showWrist)
                      _indicatorCircle(Icons.pan_tool, Colors.purple),
                  ],
                ),
              ),
            ),
          ),
          if (_showNsfw) _buildNsfwWarning(),
        ],
      ),
    );
  }

  Widget _indicatorCircle(IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.90),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white, size: 14),
    );
  }

  Widget _buildNsfwWarning() {
    return Center(
      child: Container(
        width: 320,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.redAccent.withValues(alpha: 0.85),
            width: 2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x73000000),
              blurRadius: 16,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(
                  Icons.visibility_off_rounded,
                  color: Colors.redAccent,
                  size: 25,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'محتوای نامناسب شناسایی شد',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(
                  width: 44,
                  height: 44,
                  child: IconButton(
                    onPressed: _dismissNsfw,
                    tooltip: 'بستن',
                    padding: EdgeInsets.zero,
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white70,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            const Text(
              'برای ادامه استفاده ایمن، به برنامه بازگردید.',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _dismissNsfw() async {
    try {
      if (await FlutterOverlayWindow.isActive()) {
        await FlutterOverlayWindow.closeOverlay();
      }

      if (mounted) {
        setState(() => _showNsfw = false);
      }
    } catch (e, stackTrace) {
      debugPrint('[OverlayHud] Error closing NSFW warning: $e');
      debugPrint('$stackTrace');
    }
  }
}

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;

  const MyApp({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vibrant Auth',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Vazirmatn',
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Colors.white24,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            borderSide: BorderSide.none,
          ),
          hintStyle: TextStyle(color: Colors.white70),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: Colors.white),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 64),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            elevation: 8,
          ),
        ),
      ),
      initialRoute: '/splash',
      routes: {
        '/signup': (_) => const SignupPage(),
        '/login': (_) => LoginPage(),
        '/calibrate': (_) => CalibrationScreen(cameras: cameras),
        '/dashboard': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          final gender = args is String ? args : 'male';
          return MainNavigationScreen(userGender: gender);
        },
        '/splash': (_) => SplashScreen(),
        '/onboarding': (_) => OnBoardingPage(),
      },
    );
  }
}
