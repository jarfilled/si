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
  bool _isLoading = false, _obscurePassword = true, _resettingPassword = false;

  @override
  void dispose() { _emailController.dispose(); _passwordController.dispose(); super.dispose(); }

  Future<void> _signIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) { _message('ایمیل و رمز عبور را وارد کنید.'); return; }
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
    } on AuthException catch (error) { _message(error.message); }
    catch (_) { _message('ورود انجام نشد. ایمیل و رمز عبور را بررسی کنید.'); }
    finally { if (mounted) setState(() => _isLoading = false); }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (!email.contains('@') || email.length < 5) { _message('ابتدا ایمیل حساب خود را وارد کنید.'); return; }
    setState(() => _resettingPassword = true);
    try { await Supabase.instance.client.auth.resetPasswordForEmail(email); _message('لینک بازیابی رمز عبور به ایمیل شما ارسال شد.'); }
    on AuthException catch (error) { _message(error.message); }
    catch (_) { _message('ارسال لینک بازیابی انجام نشد. دوباره تلاش کنید.'); }
    finally { if (mounted) setState(() => _resettingPassword = false); }
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))));
  }

  InputDecoration _inputDecoration({required String label, required IconData icon}) => InputDecoration(labelText: label, prefixIcon: Icon(icon), suffixIconColor: primaryGreen);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: background,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 700;
              final wide = constraints.maxWidth >= 650;
              final side = wide ? 34.0 : 18.0;
              return Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(side, compact ? 12 : 24, side, 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Row(children: [
                        IconButton(onPressed: () => Navigator.maybePop(context), style: IconButton.styleFrom(backgroundColor: Colors.white), icon: const Icon(Icons.arrow_forward_rounded, color: text)),
                        const Spacer(),
                        Image.asset('assets/logo.png', width: compact ? 42 : 48, height: compact ? 42 : 48),
                        const Spacer(),
                        const SizedBox(width: 48),
                      ]),
                      SizedBox(height: compact ? 16 : 28),
                      Container(
                        padding: EdgeInsets.all(compact ? 17 : 24),
                        decoration: BoxDecoration(gradient: const LinearGradient(colors: [mint, Color(0xFFEAF8FC)], begin: Alignment.topRight, end: Alignment.bottomLeft), borderRadius: BorderRadius.circular(30)),
                        child: Row(children: [
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('خوش برگشتی 👋', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: text, fontSize: compact ? 21 : 27, fontWeight: FontWeight.w900)), SizedBox(height: compact ? 5 : 8), Text('برای دیدن وضعیت امروزت وارد حساب شو.', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: subtext, fontSize: compact ? 10 : 12, height: 1.6))])),
                          SizedBox(width: compact ? 12 : 18),
                          Icon(Icons.favorite_rounded, color: primaryGreen, size: compact ? 30 : 40),
                        ]),
                      ),
                      SizedBox(height: compact ? 12 : 18),
                      Container(
                        padding: EdgeInsets.all(compact ? 16 : 20),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .045), blurRadius: 24, offset: const Offset(0, 8))]),
                        child: Column(children: [
                          TextField(controller: _emailController, keyboardType: TextInputType.emailAddress, textDirection: TextDirection.ltr, decoration: _inputDecoration(label: 'ایمیل', icon: Icons.mail_outline_rounded)),
                          const SizedBox(height: 14),
                          TextField(controller: _passwordController, obscureText: _obscurePassword, textDirection: TextDirection.ltr, decoration: _inputDecoration(label: 'رمز عبور', icon: Icons.lock_outline_rounded).copyWith(suffixIcon: IconButton(onPressed: () => setState(() => _obscurePassword = !_obscurePassword), icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined)))),
                          Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: _resettingPassword ? null : _resetPassword, icon: _resettingPassword ? const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 2, color: primaryGreen)) : const Icon(Icons.lock_reset_rounded, size: 17), label: const Text('رمز عبور را فراموش کرده‌اید؟', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: primaryGreen)))),
                          const SizedBox(height: 8),
                          SizedBox(width: double.infinity, height: compact ? 52 : 56, child: ElevatedButton(onPressed: _isLoading ? null : _signIn, style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))), child: _isLoading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text('ورود به برنامه', style: TextStyle(fontSize: compact ? 14 : 16, fontWeight: FontWeight.w900)))),
                        ]),
                      ),
                      const SizedBox(height: 12),
                      Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [const Text('حساب کاربری ندارید؟', style: TextStyle(color: subtext, fontSize: 12)), TextButton(onPressed: () => Navigator.pushReplacementNamed(context, '/signup'), child: const Text('ثبت‌نام کنید', style: TextStyle(color: primaryGreen, fontWeight: FontWeight.w900)))])
                    ]),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
