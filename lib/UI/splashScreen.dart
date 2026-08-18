import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const green = Color(0xFF42D2A7);
  static const teal = Color(0xFF45C4D0);
  static const bg = Color(0xFFF4F9F7);
  static const text = Color(0xFF263B37);
  static const subtext = Color(0xFF7D8D89);

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(milliseconds: 1200));

    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final supabase = Supabase.instance.client;

    final onboardingCompleted =
        prefs.getBool('onboarding_completed') ?? false;

    final session = supabase.auth.currentSession;

    debugPrint(
      '[SPLASH] onboarding_completed=$onboardingCompleted',
    );

    debugPrint(
      '[SPLASH] session=${session != null}',
    );

    // =========================================================
    // 1. User is NOT authenticated
    // =========================================================
    if (session == null) {
      if (!onboardingCompleted) {
        debugPrint('[SPLASH] → onboarding');

        Navigator.pushReplacementNamed(
          context,
          '/onboarding',
        );
      } else {
        debugPrint('[SPLASH] → login');

        Navigator.pushReplacementNamed(
          context,
          '/login',
        );
      }

      return;
    }

    // =========================================================
    // 2. User IS authenticated
    //
    // Authentication means onboarding has effectively been
    // completed. Persist this so the user never gets sent back
    // through onboarding after a successful login.
    // =========================================================
    if (!onboardingCompleted) {
      await prefs.setBool(
        'onboarding_completed',
        true,
      );

      debugPrint(
        '[SPLASH] Authenticated user → marking onboarding complete',
      );
    }

    // =========================================================
    // 3. Load user profile
    // =========================================================
    try {
      final userData = await supabase
          .from('users')
          .select('gender, hunch_divisor')
          .eq('id', session.user.id)
          .maybeSingle();

      if (!mounted) return;

      final gender =
          userData?['gender']?.toString() ?? 'male';

      final calibrated =
          userData?['hunch_divisor'] != null;

      debugPrint(
        '[SPLASH] gender=$gender calibrated=$calibrated',
      );

      // =======================================================
      // 4. Existing authenticated user
      // =======================================================
      Navigator.pushReplacementNamed(
        context,
        calibrated ? '/dashboard' : '/calibrate',
        arguments: gender,
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[SPLASH] Profile check failed: $error',
      );

      debugPrint(
        '[SPLASH] $stackTrace',
      );

      if (!mounted) return;

      // Don't send an authenticated user back to login/onboarding.
      // Calibration is the safest recovery route.
      Navigator.pushReplacementNamed(
        context,
        '/calibrate',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 112,
                height: 112,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      green,
                      teal,
                    ],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(34),
                  boxShadow: [
                    BoxShadow(
                      color: green.withOpacity(.18),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/logo.png',
                  fit: BoxFit.contain,
                ),
              ),

              const SizedBox(height: 22),

              const Text(
                'سی',
                style: TextStyle(
                  color: text,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),

              const SizedBox(height: 6),

              const Text(
                'سلامت بهتر، با استفاده بهتر از صفحه',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: subtext,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 34),

              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: green,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}