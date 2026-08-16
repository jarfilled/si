// lib/main.dart

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:monitor/UI/onBoarding.dart';
import 'package:monitor/UI/splashScreen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'UI/signup_page.dart';
import 'UI/login_page.dart';
import 'cam_screen.dart';
import 'UI/calibration_screen.dart';
import 'UI/dashboard.dart';

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
    debugPrint(
      "Failed to change DNS: '${e.message}'.",
    );
  }
}

// ============================================================================
// OVERLAY ENTRY POINT
// ============================================================================

@pragma("vm:entry-point")
void overlayMain() {
  runApp(const OverlayHudApp());
}

// ============================================================================
// OVERLAY APP
// ============================================================================

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

// ============================================================================
// OVERLAY HUD
// ============================================================================

class OverlayHud extends StatefulWidget {
  const OverlayHud({super.key});

  @override
  State<OverlayHud> createState() => _OverlayHudState();
}

class _OverlayHudState extends State<OverlayHud> {
  // --------------------------------------------------------------------------
  // POSTURE HUD STATES
  // --------------------------------------------------------------------------

  bool _showTooClose = false;
  bool _showNeck = false;
  bool _showWrist = false;
  bool _showHunch = false;
  bool _showLowLight = false;

  // --------------------------------------------------------------------------
  // NSFW STATE
  // --------------------------------------------------------------------------

  bool _showNsfw = false;

  // --------------------------------------------------------------------------
  // NATIVE CONTROL CHANNEL
  // --------------------------------------------------------------------------

  static const MethodChannel _controlChannel =
  MethodChannel('com.example.overlay/control');

  @override
  void initState() {
    super.initState();

    _listenForOverlayData();
  }

  // ==========================================================================
  // OVERLAY DATA LISTENER
  // ==========================================================================

  void _listenForOverlayData() {
    FlutterOverlayWindow.overlayListener.listen(
          (dynamic data) {
        debugPrint(
          '[OverlayHud] RECEIVED: $data',
        );

        if (!mounted) {
          return;
        }

        // --------------------------------------------------------------------
        // MAP DATA
        // --------------------------------------------------------------------

        if (data is Map) {
          final map = Map<dynamic, dynamic>.from(data);

          final type = map['type']?.toString();

          debugPrint(
            '[OverlayHud] type = $type',
          );

          bool readBool(String key) {
            final value = map[key];

            if (value is bool) {
              return value;
            }

            if (value is num) {
              return value != 0;
            }

            return value
                ?.toString()
                .toLowerCase() ==
                'true';
          }

          setState(() {
            // ---------------------------------------------------------------
            // Existing posture HUD logic
            // ---------------------------------------------------------------

            _showTooClose = readBool('tooClose');

            _showNeck = readBool('neck');

            _showWrist =
                readBool('wrist') ||
                    readBool('wristPoor');

            _showHunch =
                readBool('hunch') ||
                    readBool('hunchPoor');

            _showLowLight =
                readBool('lowLight') ||
                    readBool('lowLightPoor');

            // ---------------------------------------------------------------
            // NSFW state
            // ---------------------------------------------------------------

            if (type == 'nsfw') {
              debugPrint(
                '[OverlayHud] Switching to NSFW mode',
              );

              _showNsfw = true;
            } else if (type == 'none') {
              debugPrint(
                '[OverlayHud] Leaving NSFW mode',
              );

              _showNsfw = false;
            }
          });

          return;
        }

        // --------------------------------------------------------------------
        // STRING DATA
        // --------------------------------------------------------------------

        if (data is String) {
          debugPrint(
            '[OverlayHud] RECEIVED STRING: $data',
          );

          if (data == 'nsfw') {
            setState(() {
              _showNsfw = true;
            });

            debugPrint(
              '[OverlayHud] Switching to NSFW mode',
            );
          } else if (data == 'none') {
            setState(() {
              _showNsfw = false;

              _showTooClose = false;
              _showNeck = false;
              _showWrist = false;
              _showHunch = false;
              _showLowLight = false;
            });

            debugPrint(
              '[OverlayHud] Leaving NSFW mode',
            );
          }
        }
      },
    );
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,

      body: Stack(
        children: [
          // ==================================================================
          // EXISTING POSTURE HUD
          //
          // This remains the same basic HUD that was already working.
          // ==================================================================

          Align(
            alignment: Alignment.topCenter,

            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(
                  top: 8.0,
                ),

                child: Row(
                  mainAxisSize: MainAxisSize.min,

                  children: [
                    if (_showTooClose)
                      _indicatorCircle(
                        Icons.remove_red_eye,
                        Colors.orange,
                      ),

                    if (_showLowLight)
                      _indicatorCircle(
                        Icons.light_mode,
                        Colors.amber,
                      ),

                    if (_showNeck)
                      _indicatorCircle(
                        Icons.accessibility_new,
                        Colors.blue,
                      ),

                    if (_showHunch)
                      _indicatorCircle(
                        Icons.airline_seat_recline_normal,
                        Colors.teal,
                      ),

                    if (_showWrist)
                      _indicatorCircle(
                        Icons.pan_tool,
                        Colors.purple,
                      ),
                  ],
                ),
              ),
            ),
          ),

          // ==================================================================
          // NSFW WARNING
          //
          // IMPORTANT:
          //
          // This is NOT another overlay.
          //
          // It is simply another widget rendered by the SAME existing
          // OverlayHud that already displays the posture indicators.
          // ==================================================================

          if (_showNsfw)
            _buildNsfwWarning(),
        ],
      ),
    );
  }

  // ==========================================================================
  // NORMAL HUD INDICATOR
  // ==========================================================================

  Widget _indicatorCircle(
      IconData icon,
      Color color,
      ) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: 4,
      ),

      width: 32,
      height: 32,

      decoration: BoxDecoration(
        color: color.withOpacity(0.90),
        shape: BoxShape.circle,
      ),

      child: Icon(
        icon,
        color: Colors.white,
        size: 18,
      ),
    );
  }

  // ==========================================================================
  // NSFW WARNING
  // ==========================================================================

  Widget _buildNsfwWarning() {
    debugPrint(
      '[OverlayHud] BUILDING NSFW WARNING',
    );

    return Center(
      child: Container(
        width: 300,

        margin: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),

        padding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 12,
        ),

        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.94),

          borderRadius: BorderRadius.circular(
            18,
          ),

          border: Border.all(
            color: Colors.redAccent.withOpacity(
              0.85,
            ),
            width: 2,
          ),

          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(
                0.45,
              ),
              blurRadius: 16,
              spreadRadius: 2,
            ),
          ],
        ),

        child: Column(
          mainAxisSize: MainAxisSize.min,

          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.visibility_off_rounded,
                  color: Colors.redAccent,
                  size: 25,
                ),

                const SizedBox(
                  width: 10,
                ),

                Flexible(
                  child: Text(
                    'محتوای نامناسب شناسایی شد',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 7,
            ),

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

            const SizedBox(
              height: 9,
            ),

            SizedBox(
              height: 34,
              width: 150,

              child: ElevatedButton(
                onPressed: _dismissNsfw,

                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero,

                  minimumSize: Size.zero,

                  tapTargetSize:
                  MaterialTapTargetSize.shrinkWrap,

                  shape: RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.circular(10),
                  ),
                ),

                child: const Text(
                  'بازگشت به برنامه',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // DISMISS NSFW WARNING
  // ==========================================================================

  Future<void> _dismissNsfw() async {
    debugPrint(
      '[OverlayHud] Dismissing NSFW warning',
    );

    try {
      // ----------------------------------------------------------------------
      // DO NOT CLOSE THE OVERLAY.
      //
      // The same overlay is also responsible for the posture HUD.
      // We only tell it that NSFW mode has ended.
      // ----------------------------------------------------------------------

      if (await FlutterOverlayWindow.isActive()) {
        await FlutterOverlayWindow.shareData({
          'type': 'none',
        });
      }

      // ----------------------------------------------------------------------
      // Tell the native detector to resume.
      // ----------------------------------------------------------------------

      await _controlChannel.invokeMethod(
        'resumeDetection',
      );

      if (mounted) {
        setState(() {
          _showNsfw = false;
        });
      }
    } catch (e) {
      debugPrint(
        '[OverlayHud] Error dismissing NSFW warning: $e',
      );
    }
  }
}

// ============================================================================
// MAIN APPLICATION
// ============================================================================

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;

  const MyApp({
    Key? key,
    required this.cameras,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vibrant Auth',

      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        fontFamily: "Vazirmatn",

        inputDecorationTheme:
        const InputDecorationTheme(
          filled: true,

          fillColor: Colors.white24,

          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(16),
            ),

            borderSide: BorderSide.none,
          ),

          hintStyle: TextStyle(
            color: Colors.white70,
          ),
        ),

        textButtonTheme:
        TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
          ),
        ),

        elevatedButtonTheme:
        ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(
              vertical: 16,
              horizontal: 64,
            ),

            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                30,
              ),
            ),

            elevation: 8,
          ),
        ),
      ),

      initialRoute: '/splash',

      routes: {
        '/signup': (_) => const SignupPage(),

        '/login': (_) => LoginPage(),

        '/cam': (_) => CamScreen(
          cameras: cameras,
        ),

        '/calibrate': (_) =>
            CalibrationScreen(
              cameras: cameras,
            ),

        '/dashboard': (context) {
          final args =
              ModalRoute.of(context)
                  ?.settings
                  .arguments;

          final gender =
          (args is String)
              ? args
              : 'male';

          return MainNavigationScreen(
            userGender: gender,
          );
        },

        '/splash': (_) => SplashScreen(),

        '/onboarding': (_) =>
            OnBoardingPage(),
      },
    );
  }
}