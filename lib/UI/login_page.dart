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
  bool _isLoading = false;

  static const Color primaryGreen = Color(0xFF42D2A7);
  static const Color darkTeal = Color(0xFF145954);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (response.user != null && mounted) {
        final userData = await Supabase.instance.client
            .from('users')
            .select('gender, hunch_divisor')
            .eq('id', response.user!.id)
            .maybeSingle();

        final gender = userData?['gender'] ?? 'male';
        final hasCalibrated = userData?['hunch_divisor'] != null;

        if (!mounted) return;
        Navigator.pushReplacementNamed(
          context,
          hasCalibrated ? '/dashboard' : '/calibrate',
          arguments: gender,
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('ایمیل یا رمز عبور اشتباه است.'),
            backgroundColor: darkTeal,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F9F7),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 380;
              return Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: compact ? 18 : 30, vertical: 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      children: [
                        Container(
                          padding: EdgeInsets.all(compact ? 16 : 20),
                          decoration: BoxDecoration(
                            color: primaryGreen.withValues(alpha: .15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.spa_rounded, size: compact ? 64 : 80, color: primaryGreen),
                        ),
                        SizedBox(height: compact ? 22 : 30),
                        Text('خوش آمدید', style: TextStyle(fontSize: compact ? 25 : 28, fontWeight: FontWeight.w900, color: darkTeal)),
                        const SizedBox(height: 8),
                        Text('برای ادامه وارد حساب کاربری خود شوید', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                        SizedBox(height: compact ? 28 : 40),
                        _buildTextField(controller: _emailController, label: 'ایمیل', icon: Icons.email_outlined),
                        const SizedBox(height: 16),
                        _buildTextField(controller: _passwordController, label: 'رمز عبور', icon: Icons.lock_outline_rounded, isPassword: true),
                        SizedBox(height: compact ? 28 : 40),
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryGreen,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                            onPressed: _isLoading ? null : _signIn,
                            child: _isLoading
                                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                                : const Text('ورود به برنامه', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text('حساب کاربری ندارید؟ ', style: TextStyle(color: Colors.grey[700])),
                            GestureDetector(
                              onTap: () => Navigator.pushNamed(context, '/signup'),
                              child: const Text('ثبت‌نام کنید', style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x05000000), blurRadius: 10, offset: Offset(0, 5))],
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[500]),
          prefixIcon: Icon(icon, color: primaryGreen),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
        ),
      ),
    );
  }
}
