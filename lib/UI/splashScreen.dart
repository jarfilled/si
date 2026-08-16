import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    // Show splash logo for 2 seconds.
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final supabase = Supabase.instance.client;
    final session = supabase.auth.currentSession;

    // Only redirect to login when the user genuinely has no session.
    if (session == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    try {
      final userData = await supabase
          .from('users')
          .select('gender, hunch_divisor')
          .eq('id', session.user.id)
          .maybeSingle();

      if (!mounted) return;

      final gender = userData?['gender'] ?? 'male';
      final hasCalibrated = userData?['hunch_divisor'] != null;

      if (hasCalibrated) {
        Navigator.pushReplacementNamed(
          context,
          '/dashboard',
          arguments: gender,
        );
      } else {
        Navigator.pushReplacementNamed(context, '/calibrate');
      }
    } catch (error) {
      debugPrint('Splash profile check failed: $error');

      if (!mounted) return;

      // User is still authenticated. Do NOT force another login because
      // a profile query can fail because of internet/RLS/schema issues.
      Navigator.pushReplacementNamed(context, '/calibrate');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF42D2A7),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(
              Icons.spa,
              size: 100,
              color: Colors.white,
            ),
            SizedBox(height: 20),
            CircularProgressIndicator(
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}
