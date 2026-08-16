import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _year = TextEditingController();

  static const primaryGreen = Color(0xFF42D2A7);
  static const primaryTeal = Color(0xFF45C4D0);
  static const text = Color(0xFF263B37);
  static const subtext = Color(0xFF7D8D89);
  static const background = Color(0xFFF4F9F7);
  static const mint = Color(0xFFE8F8F1);

  final supabase = Supabase.instance.client;
  String? _day;
  String? _month;
  String? _gender;
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _year.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    final username = _username.text.trim();
    final email = _email.text.trim();
    final password = _password.text;
    final year = _year.text.trim();

    if (username.isEmpty || email.isEmpty || password.isEmpty || year.isEmpty ||
        _day == null || _month == null || _gender == null) {
      _message('برای ادامه، همه اطلاعات را کامل کنید.');
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      _message('یک ایمیل معتبر وارد کنید.');
      return;
    }
    if (password.length < 8) {
      _message('رمز عبور باید حداقل ۸ کاراکتر باشد.');
      return;
    }
    if (password != _confirmPassword.text) {
      _message('رمز عبور و تکرار آن یکسان نیستند.');
      return;
    }

    final parsedYear = int.tryParse(year);
    final currentYear = DateTime.now().year;
    if (parsedYear == null || parsedYear < 1900 || parsedYear > currentYear) {
      _message('سال تولد را به‌درستی وارد کنید.');
      return;
    }

    setState(() => _loading = true);
    try {
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
      );
      final user = response.user;
      if (user == null) throw const AuthException('ساخت حساب انجام نشد.');

      await supabase.from('users').insert({
        'id': user.id,
        'username': username,
        'gender': _gender,
        'birth_date': '$year-$_month-$_day',
      });

      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        '/calibrate',
        arguments: _gender,
      );
    } on AuthException catch (error) {
      _message(error.message);
    } catch (_) {
      _message('ثبت‌نام انجام نشد. ممکن است این ایمیل قبلاً استفاده شده باشد.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      );

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: background,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.maybePop(context),
                          style: IconButton.styleFrom(backgroundColor: Colors.white),
                          icon: const Icon(Icons.arrow_forward_rounded, color: text),
                        ),
                        const Spacer(),
                        Image.asset('assets/logo.png', width: 48, height: 48),
                        const Spacer(),
                        const SizedBox(width: 48),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'حساب خودت را بساز',
                      style: TextStyle(color: text, fontSize: 28, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      'اطلاعات پایه کمک می‌کنند تجربه سی از همان ابتدا شخصی‌تر باشد.',
                      style: TextStyle(color: subtext, fontSize: 12, height: 1.7),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(.045),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          TextField(controller: _username, decoration: _dec('نام کاربری', Icons.person_outline_rounded)),
                          const SizedBox(height: 13),
                          TextField(controller: _email, keyboardType: TextInputType.emailAddress, textDirection: TextDirection.ltr, decoration: _dec('ایمیل', Icons.mail_outline_rounded)),
                          const SizedBox(height: 13),
                          TextField(
                            controller: _password,
                            obscureText: _obscurePassword,
                            textDirection: TextDirection.ltr,
                            decoration: _dec('رمز عبور', Icons.lock_outline_rounded).copyWith(
                              suffixIcon: IconButton(
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                              ),
                            ),
                          ),
                          const SizedBox(height: 13),
                          TextField(
                            controller: _confirmPassword,
                            obscureText: _obscureConfirm,
                            textDirection: TextDirection.ltr,
                            decoration: _dec('تکرار رمز عبور', Icons.lock_reset_outlined).copyWith(
                              suffixIcon: IconButton(
                                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                                icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Align(
                            alignment: Alignment.centerRight,
                            child: Text('تاریخ تولد', style: TextStyle(color: text, fontSize: 13, fontWeight: FontWeight.w800)),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _day,
                                  decoration: const InputDecoration(labelText: 'روز', prefixIcon: Icon(Icons.today_outlined)),
                                  items: List.generate(31, (i) => '${i + 1}')
                                      .map((day) => DropdownMenuItem(value: day, child: Text(day)))
                                      .toList(),
                                  onChanged: (value) => setState(() => _day = value),
                                ),
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _month,
                                  decoration: const InputDecoration(labelText: 'ماه', prefixIcon: Icon(Icons.calendar_month_outlined)),
                                  items: List.generate(12, (i) {
                                    final month = '${i + 1}'.padLeft(2, '0');
                                    return DropdownMenuItem(value: month, child: Text(month));
                                  }).toList(),
                                  onChanged: (value) => setState(() => _month = value),
                                ),
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: TextField(
                                  controller: _year,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(labelText: 'سال', prefixIcon: Icon(Icons.event_outlined)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            value: _gender,
                            decoration: _dec('جنسیت', Icons.wc_outlined),
                            items: const [
                              DropdownMenuItem(value: 'male', child: Text('آقا')),
                              DropdownMenuItem(value: 'female', child: Text('خانم')),
                            ],
                            onChanged: (value) => setState(() => _gender = value),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _signUp,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryGreen,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                              ),
                              child: _loading
                                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Text('ساخت حساب و ادامه', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: mint, borderRadius: BorderRadius.circular(18)),
                      child: const Row(
                        children: [
                          Icon(Icons.verified_user_outlined, color: primaryGreen, size: 22),
                          SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              'بعد از ساخت حساب، وارد مرحله کالیبراسیون وضعیت بدن می‌شوی تا تشخیص شخصی‌سازی شود.',
                              style: TextStyle(color: text, fontSize: 11, height: 1.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('قبلاً ثبت‌نام کرده‌اید؟', style: TextStyle(color: subtext, fontSize: 12)),
                        TextButton(
                          onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                          child: const Text('وارد شوید', style: TextStyle(color: primaryTeal, fontWeight: FontWeight.w900)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
