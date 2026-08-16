import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  static const primaryGreen = Color(0xFF42D2A7);
  static const primaryTeal = Color(0xFF45C4D0);
  static const text = Color(0xFF263B37);
  static const subtext = Color(0xFF7D8D89);
  static const background = Color(0xFFF4F9F7);
  static const mint = Color(0xFFE8F8F1);

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _resettingPassword = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      _message('ایمیل و رمز عبور را وارد کنید.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(email: email, password: password);
      final user = response.user;
      if (user == null) throw const AuthException('ورود انجام نشد.');
      final profile = await Supabase.instance.client.from('users').select('gender, hunch_divisor').eq('id', user.id).maybeSingle();
      if (!mounted) return;
      final gender = profile?['gender']?.toString() ?? 'male';
      final calibrated = profile?['hunch_divisor'] != null;
      Navigator.pushReplacementNamed(context, calibrated ? '/dashboard' : '/calibrate', arguments: gender);
    } on AuthException catch (error) {
      _message(error.message);
    } catch (_) {
      _message('ورود انجام نشد. ایمیل و رمز عبور را بررسی کنید.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (!email.contains('@') || email.length < 5) {
      _message('ابتدا ایمیل حساب خود را وارد کنید.');
      return;
    }
    setState(() => _resettingPassword = true);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      _message('لینک بازیابی رمز عبور به ایمیل شما ارسال شد.');
    } on AuthException catch (error) {
      _message(error.message);
    } catch (_) {
      _message('ارسال لینک بازیابی انجام نشد. دوباره تلاش کنید.');
    } finally {
      if (mounted) setState(() => _resettingPassword = false);
    }
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))));
  }

  InputDecoration _inputDecoration({required String label, required IconData icon}) => InputDecoration(labelText: label, prefixIcon: Icon(icon), suffixIconColor: primaryGreen);

  @override
  Widget build(BuildContext context) {
    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(backgroundColor: background, body: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(22, 24, 22, 28), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [IconButton(onPressed: () => Navigator.maybePop(context), style: IconButton.styleFrom(backgroundColor: Colors.white), icon: const Icon(Icons.arrow_forward_rounded, color: text)), const Spacer(), Image.asset('assets/logo.png', width: 48, height: 48), const Spacer(), const SizedBox(width: 48)]),
      const SizedBox(height: 28),
      Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(gradient: const LinearGradient(colors: [mint, Color(0xFFEAF8FC)], begin: Alignment.topRight, end: Alignment.bottomLeft), borderRadius: BorderRadius.circular(30)), child: const Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('خوش برگشتی 👋', style: TextStyle(color: text, fontSize: 27, fontWeight: FontWeight.w900)), SizedBox(height: 8), Text('برای دیدن وضعیت امروزت وارد حساب شو.', style: TextStyle(color: subtext, fontSize: 12, height: 1.7))])), Icon(Icons.favorite_rounded, color: primaryGreen, size: 40)])),
      const SizedBox(height: 18),
      Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: Colors.black.withOpacity(.045), blurRadius: 24, offset: const Offset(0, 8))]), child: Column(children: [
        TextField(controller: _emailController, keyboardType: TextInputType.emailAddress, textDirection: TextDirection.ltr, decoration: _inputDecoration(label: 'ایمیل', icon: Icons.mail_outline_rounded)),
        const SizedBox(height: 14),
        TextField(controller: _passwordController, obscureText: _obscurePassword, textDirection: TextDirection.ltr, decoration: _inputDecoration(label: 'رمز عبور', icon: Icons.lock_outline_rounded).copyWith(suffixIcon: IconButton(onPressed: () => setState(() => _obscurePassword = !_obscurePassword), icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined)))),
        Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: _resettingPassword ? null : _resetPassword, icon: _resettingPassword ? const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 2, color: primaryGreen)) : const Icon(Icons.lock_reset_rounded, size: 17), label: const Text('رمز عبور را فراموش کرده‌اید؟', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: primaryGreen)))),
        const SizedBox(height: 8),
        SizedBox(width: double.infinity, height: 56, child: ElevatedButton(onPressed: _isLoading ? null : _signIn, style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))), child: _isLoading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('ورود به برنامه', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)))),
      ])),
      const SizedBox(height: 16),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Text('حساب کاربری ندارید؟', style: TextStyle(color: subtext, fontSize: 12)), TextButton(onPressed: () => Navigator.pushReplacementNamed(context, '/signup'), child: const Text('ثبت‌نام کنید', style: TextStyle(color: primaryGreen, fontWeight: FontWeight.w900)))]),
    ]))))));
  }
}
