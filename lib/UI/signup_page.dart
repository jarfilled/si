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

    if (username.isEmpty || email.isEmpty || password.isEmpty || year.isEmpty || _day == null || _month == null || _gender == null) {
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
      final response = await supabase.auth.signUp(email: email, password: password);
      final user = response.user;
      if (user == null) throw const AuthException('ساخت حساب انجام نشد.');

      await supabase.from('users').insert({
        'id': user.id,
        'username': username,
        'gender': _gender,
        'birth_date': '$year-$_month-$_day',
      });

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/calibrate', arguments: _gender);
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
      ..showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
  }

  InputDecoration _dec(String label, IconData icon, {bool compact = false}) => InputDecoration(
        labelText: label,
        prefixIcon: compact ? null : Icon(icon),
        contentPadding: EdgeInsets.symmetric(horizontal: compact ? 13 : 14, vertical: 15),
        isDense: compact,
      );

  Widget _birthFields(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 420;
        final veryCompact = constraints.maxWidth < 350;
        final day = DropdownButtonFormField<String>(
          initialValue: _day,
          isExpanded: true,
          decoration: _dec('روز', Icons.today_outlined, compact: compact),
          items: List.generate(31, (i) => '${i + 1}')
              .map((day) => DropdownMenuItem(value: day, child: Text(day, overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: (value) => setState(() => _day = value),
        );
        final month = DropdownButtonFormField<String>(
          initialValue: _month,
          isExpanded: true,
          decoration: _dec('ماه', Icons.calendar_month_outlined, compact: compact),
          items: List.generate(12, (i) {
            final month = '${i + 1}'.padLeft(2, '0');
            return DropdownMenuItem(value: month, child: Text(month, overflow: TextOverflow.ellipsis));
          }).toList(),
          onChanged: (value) => setState(() => _month = value),
        );
        final year = TextField(
          controller: _year,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          decoration: _dec('سال', Icons.event_outlined, compact: compact),
        );

        if (veryCompact) {
          return Column(children: [
            Row(children: [
              Expanded(child: day),
              const SizedBox(width: 8),
              Expanded(child: month),
            ]),
            const SizedBox(height: 10),
            year,
          ]);
        }

        if (compact) {
          return Row(children: [
            Expanded(child: day),
            const SizedBox(width: 8),
            Expanded(child: month),
            const SizedBox(width: 8),
            Expanded(child: year),
          ]);
        }

        return Row(children: [
          Expanded(child: day),
          const SizedBox(width: 9),
          Expanded(child: month),
          const SizedBox(width: 9),
          Expanded(child: year),
        ]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: background,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 380;
              final horizontal = narrow ? 14.0 : 20.0;
              final cardPadding = narrow ? 14.0 : 20.0;

              return SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Row(children: [
                        IconButton(
                          onPressed: () => Navigator.maybePop(context),
                          style: IconButton.styleFrom(backgroundColor: Colors.white),
                          icon: const Icon(Icons.arrow_forward_rounded, color: text),
                        ),
                        const Spacer(),
                        Image.asset('assets/logo.png', width: narrow ? 42 : 48, height: narrow ? 42 : 48),
                        const Spacer(),
                        SizedBox(width: narrow ? 40 : 48),
                      ]),
                      SizedBox(height: narrow ? 14 : 20),
                      Text('حساب خودت را بساز', style: TextStyle(color: text, fontSize: narrow ? 24 : 28, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 7),
                      const Text('اطلاعات پایه کمک می‌کنند تجربه سی از همان ابتدا شخصی‌تر باشد.', style: TextStyle(color: subtext, fontSize: 12, height: 1.7)),
                      SizedBox(height: narrow ? 14 : 20),
                      Container(
                        padding: EdgeInsets.all(cardPadding),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(narrow ? 22 : 28),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .045), blurRadius: 24, offset: const Offset(0, 8))],
                        ),
                        child: Column(children: [
                          TextField(controller: _username, textInputAction: TextInputAction.next, decoration: _dec('نام کاربری', Icons.person_outline_rounded, compact: narrow)),
                          const SizedBox(height: 12),
                          TextField(controller: _email, keyboardType: TextInputType.emailAddress, textDirection: TextDirection.ltr, textInputAction: TextInputAction.next, decoration: _dec('ایمیل', Icons.mail_outline_rounded, compact: narrow)),
                          const SizedBox(height: 12),
                          TextField(controller: _password, obscureText: _obscurePassword, textDirection: TextDirection.ltr, textInputAction: TextInputAction.next, decoration: _dec('رمز عبور', Icons.lock_outline_rounded, compact: narrow).copyWith(suffixIcon: IconButton(onPressed: () => setState(() => _obscurePassword = !_obscurePassword), icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined)))),
                          const SizedBox(height: 12),
                          TextField(controller: _confirmPassword, obscureText: _obscureConfirm, textDirection: TextDirection.ltr, textInputAction: TextInputAction.next, decoration: _dec('تکرار رمز عبور', Icons.lock_reset_outlined, compact: narrow).copyWith(suffixIcon: IconButton(onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm), icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined)))),
                          const SizedBox(height: 15),
                          const Align(alignment: Alignment.centerRight, child: Text('تاریخ تولد', style: TextStyle(color: text, fontSize: 13, fontWeight: FontWeight.w800))),
                          const SizedBox(height: 8),
                          _birthFields(context),
                          const SizedBox(height: 13),
                          DropdownButtonFormField<String>(
                            initialValue: _gender,
                            isExpanded: true,
                            decoration: _dec('جنسیت', Icons.wc_outlined, compact: narrow),
                            items: const [DropdownMenuItem(value: 'male', child: Text('آقا')), DropdownMenuItem(value: 'female', child: Text('خانم'))],
                            onChanged: (value) => setState(() => _gender = value),
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            height: narrow ? 52 : 56,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _signUp,
                              style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                              child: _loading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const FittedBox(fit: BoxFit.scaleDown, child: Text('ساخت حساب و ادامه', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900))),
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: mint, borderRadius: BorderRadius.circular(18)),
                        child: const Row(children: [
                          Icon(Icons.verified_user_outlined, color: primaryGreen, size: 22),
                          SizedBox(width: 9),
                          Expanded(child: Text('بعد از ساخت حساب، وارد مرحله کالیبراسیون وضعیت بدن می‌شوی تا تشخیص شخصی‌سازی شود.', style: TextStyle(color: text, fontSize: 11, height: 1.6))),
                        ]),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text('قبلاً ثبت‌نام کرده‌اید؟', style: TextStyle(color: subtext, fontSize: 12)),
                          TextButton(onPressed: () => Navigator.pushReplacementNamed(context, '/login'), child: const Text('وارد شوید', style: TextStyle(color: primaryTeal, fontWeight: FontWeight.w900))),
                        ],
                      ),
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
