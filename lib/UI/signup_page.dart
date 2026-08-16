import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({Key? key}) : super(key: key);

  @override
  _SignupPageState createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _year = TextEditingController();

  String? _day;
  String? _month;
  String? _gender;
  bool _loading = false;

  final Color primaryGreen = const Color(0xFF42D2A7);
  final Color primaryTeal = const Color(0xFF45C4D0);
  final Color bgColor = const Color(0xFFF4F9F7);

  final supabase = Supabase.instance.client;

  Future<void> _signUp() async {
    if (_email.text.isEmpty || _password.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لطفا ایمیل و رمز عبور را وارد کنید')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      // ۱. ثبت نام کاربر در بخش Auth
      final AuthResponse res = await supabase.auth.signUp(
        email: _email.text.trim(),
        password: _password.text,
      );

      final User? user = res.user;

      if (user != null) {
        // ۲. ذخیره اطلاعات تکمیلی در جدول users
        await supabase.from('users').insert({
          'id': user.id, // استفاده از آیدی Auth برای ارتباط با دیتابیس
          'username': _username.text.trim(),
          'gender': _gender,
          'birth_date': '${_year.text}-$_month-$_day',
        });

        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/calibrate');
      }

    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطای ثبت نام: ${e.message}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطای نامشخص: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }




  InputDecoration _inputDec({required String hint, required IconData icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400),
      prefixIcon: Icon(icon, color: primaryGreen.withOpacity(0.8)),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // پس‌زمینه مشابه
          Positioned(top: -100, right: -50, child: CircleAvatar(radius: 180, backgroundColor: primaryGreen.withOpacity(0.06))),
          Positioned(top: 300, left: -80, child: CircleAvatar(radius: 120, backgroundColor: primaryTeal.withOpacity(0.06))),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    // کارت فرم شناور
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(40),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(Icons.person_add_rounded, size: 60, color: primaryGreen.withOpacity(0.8)),
                          const SizedBox(height: 16),
                          Text('ساخت حساب جدید', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.grey.shade800)),
                          const SizedBox(height: 8),
                          Text('اطلاعات خود را وارد کنید', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                          const SizedBox(height: 32),

                          TextField(controller: _username, decoration: _inputDec(hint: 'نام کاربری', icon: Icons.person_rounded)),
                          const SizedBox(height: 16),

                          TextField(controller: _email, keyboardType: TextInputType.emailAddress, textDirection: TextDirection.ltr, decoration: _inputDec(hint: 'پست الکترونیک', icon: Icons.email_rounded)),
                          const SizedBox(height: 16),

                          TextField(controller: _password, obscureText: true, textDirection: TextDirection.ltr, decoration: _inputDec(hint: 'رمز عبور', icon: Icons.lock_rounded)),
                          const SizedBox(height: 16),

                          // بخش تاریخ تولد با طراحی تمیزتر
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _day,
                                    hint: Text('روز', style: TextStyle(color: Colors.grey.shade400)),
                                    onChanged: (v) => setState(() => _day = v),
                                    decoration: const InputDecoration(border: InputBorder.none),
                                    items: List.generate(31, (i) => '${i + 1}').map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                                  ),
                                ),
                                Container(width: 1, height: 30, color: Colors.grey.shade300),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                    child: DropdownButtonFormField<String>(
                                      value: _month,
                                      hint: Text('ماه', style: TextStyle(color: Colors.grey.shade400)),
                                      onChanged: (v) => setState(() => _month = v),
                                      decoration: const InputDecoration(border: InputBorder.none),
                                      isExpanded: true,
                                      items: ['فروردین','اردیبهشت','خرداد','تیر','مرداد','شهریور','مهر','آبان','آذر','دی','بهمن','اسفند']
                                          .map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 13)))).toList(),
                                    ),
                                  ),
                                ),
                                Container(width: 1, height: 30, color: Colors.grey.shade300),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: TextField(
                                      controller: _year,
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      decoration: InputDecoration(
                                        hintText: 'سال',
                                        hintStyle: TextStyle(color: Colors.grey.shade400),
                                        border: InputBorder.none,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          DropdownButtonFormField<String>(
                            value: _gender,
                            hint: Text('جنسیت', style: TextStyle(color: Colors.grey.shade400)),
                            onChanged: (v) => setState(() => _gender = v),
                            decoration: _inputDec(hint: '', icon: Icons.wc_rounded),
                            items: ['آقا', 'خانم'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                          ),
                          const SizedBox(height: 32),

                          // دکمه ثبت‌نام
                          GestureDetector(
                            onTap: _loading ? null : _signUp,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: double.infinity,
                              height: 60,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                gradient: LinearGradient(colors: [primaryGreen, primaryTeal]),
                                boxShadow: [
                                  BoxShadow(
                                    color: primaryTeal.withOpacity(0.3),
                                    blurRadius: 15,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: _loading
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : const Text('ثبت‌نام', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('قبلاً ثبت‌نام کرده‌اید؟', style: TextStyle(color: Colors.grey.shade600)),
                          TextButton(
                            onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                            child: Text('وارد شوید', style: TextStyle(color: primaryTeal, fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
