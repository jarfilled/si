import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  final Color primaryGreen = const Color(0xFF42D2A7);
  final Color darkTeal = const Color(0xFF145954);

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

        if (hasCalibrated) {
          Navigator.pushReplacementNamed(context, '/dashboard', arguments: gender);
        } else {
          Navigator.pushReplacementNamed(context, '/calibrate');
        }
      }
    } catch (error) {
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
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // آیکون یا لوگوی اپلیکیشن
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: primaryGreen.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.spa_rounded, size: 80, color: primaryGreen),
                ),
                const SizedBox(height: 30),
                Text(
                  'خوش آمدید',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: darkTeal,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'برای ادامه وارد حساب کاربری خود شوید',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 40),

                // فیلد ایمیل
                _buildTextField(
                  controller: _emailController,
                  label: 'ایمیل',
                  icon: Icons.email_outlined,
                ),
                const SizedBox(height: 20),

                // فیلد رمز عبور
                _buildTextField(
                  controller: _passwordController,
                  label: 'رمز عبور',
                  icon: Icons.lock_outline_rounded,
                  isPassword: true,
                ),
                const SizedBox(height: 40),

                // دکمه ورود
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onPressed: _isLoading ? null : _signIn,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                        'ورود به برنامه',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // لینک ثبت نام
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('حساب کاربری ندارید؟ ', style: TextStyle(color: Colors.grey[700])),
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/signup'),
                      child: Text(
                        'ثبت‌نام کنید',
                        style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[500]),
          prefixIcon: Icon(icon, color: primaryGreen),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(vertical: 20),
        ),
      ),
    );
  }
}
