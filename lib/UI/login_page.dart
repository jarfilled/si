import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  static const primaryGreen = Color(0xFF42D2A7), primaryTeal = Color(0xFF45C4D0), text = Color(0xFF263B37), subtext = Color(0xFF7D8D89), background = Color(0xFFF4F9F7), mint = Color(0xFFE8F8F1);
  bool _isLoading = false, _obscurePassword = true, _resettingPassword = false;

  @override void dispose() { _emailController.dispose(); _passwordController.dispose(); super.dispose(); }

  Future<void> _signIn() async {
    final email = _emailController.text.trim(), password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) { _message('ایمیل و رمز عبور را وارد کنید.'); return; }
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(email: email, password: password);
      final user = response.user;
      if (user == null) throw const AuthException('ورود انجام نشد.');
      final profile = await Supabase.instance.client.from('users').select('gender, hunch_divisor').eq('id', user.id).maybeSingle();
      if (!mounted) return;
      final gender = profile?['gender']?.toString() ?? 'male';
      Navigator.pushReplacementNamed(context, profile?['hunch_divisor'] != null ? '/dashboard' : '/calibrate', arguments: gender);
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

  void _message(String message) { if (!mounted) return; ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))); }

  InputDecoration _inputDecoration({required String label, required IconData icon, required bool compact}) => InputDecoration(labelText: label, prefixIcon: compact ? null : Icon(icon), contentPadding: EdgeInsets.symmetric(horizontal: compact ? 13 : 14, vertical: 15), isDense: compact, suffixIconColor: primaryGreen);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: background,
        body: SafeArea(
          child: LayoutBuilder(builder: (context, constraints) {
            final narrow = constraints.maxWidth < 380;
            final horizontal = narrow ? 14.0 : 22.0;
            return Center(child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 28),
              child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [IconButton(onPressed: () => Navigator.maybePop(context), style: IconButton.styleFrom(backgroundColor: Colors.white), icon: const Icon(Icons.arrow_forward_rounded, color: text)), const Spacer(), Image.asset('assets/logo.png', width: narrow ? 42 : 48, height: narrow ? 42 : 48), const Spacer(), SizedBox(width: narrow ? 40 : 48)]),
                SizedBox(height: narrow ? 18 : 28),
                Container(
                  padding: EdgeInsets.all(narrow ? 17 : 24),
                  decoration: BoxDecoration(gradient: const LinearGradient(colors: [mint, Color(0xFFEAF8FC)], begin: Alignment.topRight, end: Alignment.bottomLeft), borderRadius: BorderRadius.circular(narrow ? 23 : 30)),
                  child: LayoutBuilder(builder: (_, c) {
                    final stacked = c.maxWidth < 330;
                    final copy = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('خوش برگشتی 👋', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: text, fontSize: narrow ? 23 : 27, fontWeight: FontWeight.w900)), const SizedBox(height: 7), const Text('برای دیدن وضعیت امروزت وارد حساب شو.', maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: subtext, fontSize: 12, height: 1.7))]);
                    if (stacked) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [copy, const SizedBox(height: 10), const Icon(Icons.favorite_rounded, color: primaryGreen, size: 30)]);
                    return Row(children: [Expanded(child: copy), const SizedBox(width: 10), Icon(Icons.favorite_rounded, color: primaryGreen, size: narrow ? 30 : 40)]);
                  }),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(narrow ? 15 : 20),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(narrow ? 22 : 28), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .045), blurRadius: 24, offset: const Offset(0, 8))]),
                  child: Column(children: [
                    TextField(controller: _emailController, keyboardType: TextInputType.emailAddress, textDirection: TextDirection.ltr, textInputAction: TextInputAction.next, decoration: _inputDecoration(label: 'ایمیل', icon: Icons.mail_outline_rounded, compact: narrow)),
                    const SizedBox(height: 12),
                    TextField(controller: _passwordController, obscureText: _obscurePassword, textDirection: TextDirection.ltr, textInputAction: TextInputAction.done, decoration: _inputDecoration(label: 'رمز عبور', icon: Icons.lock_outline_rounded, compact: narrow).copyWith(suffixIcon: IconButton(onPressed: () => setState(() => _obscurePassword = !_obscurePassword), icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined)))),
                    Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: _resettingPassword ? null : _resetPassword, icon: _resettingPassword ? const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 2, color: primaryGreen)) : const Icon(Icons.lock_reset_rounded, size: 17), label: const FittedBox(fit: BoxFit.scaleDown, child: Text('رمز عبور را فراموش کرده‌اید؟', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: primaryGreen)))),
                    const SizedBox(height: 6),
                    SizedBox(width: double.infinity, height: narrow ? 52 : 56, child: ElevatedButton(onPressed: _isLoading ? null : _signIn, style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))), child: _isLoading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const FittedBox(fit: BoxFit.scaleDown, child: Text('ورود به برنامه', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900))))),
                  ]),
                ),
                const SizedBox(height: 12),
                Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [const Text('حساب کاربری ندارید؟', style: TextStyle(color: subtext, fontSize: 12)), TextButton(onPressed: () => Navigator.pushReplacementNamed(context, '/signup'), child: const Text('ثبت‌نام کنید', style: TextStyle(color: primaryGreen, fontWeight: FontWeight.w900)))]),
              ])),
            ));
          }),
        ),
      ),
    );
  }
}