import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  @override
  void initState() { super.initState(); _checkAuth(); }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    final supabase = Supabase.instance.client;
    final session = supabase.auth.currentSession;
    if (session == null) { Navigator.pushReplacementNamed(context, '/login'); return; }
    try {
      final userData = await supabase.from('users').select('gender, hunch_divisor').eq('id', session.user.id).maybeSingle();
      if (!mounted) return;
      final gender = userData?['gender']?.toString() ?? 'male';
      final calibrated = userData?['hunch_divisor'] != null;
      Navigator.pushReplacementNamed(context, calibrated ? '/dashboard' : '/calibrate', arguments: gender);
    } catch (error) {
      debugPrint('Splash profile check failed: $error');
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/calibrate');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: bg, body: SafeArea(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Container(width: 112, height: 112, padding: const EdgeInsets.all(22), decoration: BoxDecoration(gradient: const LinearGradient(colors: [green, teal], begin: Alignment.topRight, end: Alignment.bottomLeft), borderRadius: BorderRadius.circular(34), boxShadow: [BoxShadow(color: green.withOpacity(.18), blurRadius: 30, offset: const Offset(0, 12))]), child: Image.asset('assets/logo.png', color: Colors.white)),
    const SizedBox(height: 22),
    const Text('سی', style: TextStyle(color: text, fontSize: 30, fontWeight: FontWeight.w900)),
    const SizedBox(height: 6),
    const Text('سلامت بهتر، با استفاده بهتر از صفحه', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF7D8D89), fontSize: 11, fontWeight: FontWeight.w600)),
    const SizedBox(height: 34),
    const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: green)),
  ]))));
}
