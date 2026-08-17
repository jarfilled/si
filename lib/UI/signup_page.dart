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
  final _year = TextEditingController();

  String? _day;
  String? _month;
  String? _gender;
  bool _loading = false;

  static const Color primaryGreen = Color(0xFF42D2A7);
  static const Color primaryTeal = Color(0xFF45C4D0);
  static const Color bgColor = Color(0xFFF4F9F7);

  final supabase = Supabase.instance.client;

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _year.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (_email.text.isEmpty || _password.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لطفا ایمیل و رمز عبور را وارد کنید')),
      );
      return;
    }

    if (_day == null || _month == null || _year.text.trim().isEmpty || _gender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لطفاً تاریخ تولد و جنسیت را کامل کنید')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final res = await supabase.auth.signUp(
        email: _email.text.trim(),
        password: _password.text,
      );
      final user = res.user;

      if (user != null) {
        await supabase.from('users').insert({
          'id': user.id,
          'username': _username.text.trim(),
          'gender': _gender,
          'birth_date': '${_year.text.trim()}-$_month-$_day',
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
      prefixIcon: Icon(icon, color: primaryGreen.withValues(alpha: .8)),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _buildBirthDateFields() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _birthDropdown(
                hint: 'روز',
                value: _day,
                items: List.generate(31, (i) => '${i + 1}'),
                onChanged: (v) => setState(() => _day = v),
              ),
              const SizedBox(height: 8),
              _birthDropdown(
                hint: 'ماه',
                value: _month,
                items: const ['فروردین','اردیبهشت','خرداد','تیر','مرداد','شهریور','مهر','آبان','آذر','دی','بهمن','اسفند'],
                onChanged: (v) => setState(() => _month = v),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _year,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: 'سال تولد',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: _birthDropdown(
                  hint: 'روز',
                  value: _day,
                  items: List.generate(31, (i) => '${i + 1}'),
                  onChanged: (v) => setState(() => _day = v),
                  compact: true,
                ),
              ),
              Container(width: 1, height: 28, color: Colors.grey.shade300),
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: _birthDropdown(
                    hint: 'ماه',
                    value: _month,
                    items: const ['فروردین','اردیبهشت','خرداد','تیر','مرداد','شهریور','مهر','آبان','آذر','دی','بهمن','اسفند'],
                    onChanged: (v) => setState(() => _month = v),
                    compact: true,
                  ),
                ),
              ),
              Container(width: 1, height: 28, color: Colors.grey.shade300),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: TextField(
                    controller: _year,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: 'سال',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _birthDropdown({
    required String hint,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    bool compact = false,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      hint: Text(hint, style: TextStyle(color: Colors.grey.shade400)),
      onChanged: onChanged,
      decoration: InputDecoration(
        border: InputBorder.none,
        isDense: compact,
        contentPadding: compact ? EdgeInsets.zero : null,
      ),
      isExpanded: true,
      items: items
          .map((item) => DropdownMenuItem(
                value: item,
                child: Text(
                  item,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ))
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          Positioned(top: -100, right: -50, child: CircleAvatar(radius: 180, backgroundColor: primaryGreen.withValues(alpha: .06))),
          Positioned(top: 300, left: -80, child: CircleAvatar(radius: 120, backgroundColor: primaryTeal.withValues(alpha: .06))),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final horizontal = constraints.maxWidth < 420 ? 16.0 : 24.0;
                final cardPadding = constraints.maxWidth < 360 ? 20.0 : 28.0;
                return Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Container(
                        margin: EdgeInsets.symmetric(horizontal: horizontal),
                        padding: EdgeInsets.all(cardPadding),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: .04),
                              blurRadius: 30,
                              offset: const Offset(0, 15),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(child: Icon(Icons.person_add_rounded, size: constraints.maxWidth < 360 ? 46 : 56, color: primaryGreen.withValues(alpha: .8))),
                            const SizedBox(height: 14),
                            const Text('ساخت حساب جدید', textAlign: TextAlign.center, style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: Color(0xFF30343B)), overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 6),
                            Text('اطلاعات خود را وارد کنید', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                            const SizedBox(height: 26),
                            TextField(controller: _username, decoration: _inputDec(hint: 'نام کاربری', icon: Icons.person_rounded)),
                            const SizedBox(height: 14),
                            TextField(controller: _email, keyboardType: TextInputType.emailAddress, textDirection: TextDirection.ltr, decoration: _inputDec(hint: 'پست الکترونیک', icon: Icons.email_rounded)),
                            const SizedBox(height: 14),
                            TextField(controller: _password, obscureText: true, textDirection: TextDirection.ltr, decoration: _inputDec(hint: 'رمز عبور', icon: Icons.lock_rounded)),
                            const SizedBox(height: 14),
                            _buildBirthDateFields(),
                            const SizedBox(height: 14),
                            DropdownButtonFormField<String>(
                              initialValue: _gender,
                              hint: Text('جنسیت', style: TextStyle(color: Colors.grey.shade400)),
                              onChanged: (v) => setState(() => _gender = v),
                              decoration: _inputDec(hint: '', icon: Icons.wc_rounded),
                              isExpanded: true,
                              items: const [
                                DropdownMenuItem(value: 'آقا', child: Text('آقا')),
                                DropdownMenuItem(value: 'خانم', child: Text('خانم')),
                              ],
                            ),
                            const SizedBox(height: 26),
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
                                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                                    : const Text('ثبت‌نام', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text('قبلاً ثبت‌نام کرده‌اید؟', style: TextStyle(color: Colors.grey.shade600)),
                                TextButton(
                                  onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                                  child: const Text('وارد شوید', style: TextStyle(color: primaryTeal, fontWeight: FontWeight.bold, fontSize: 15)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
