import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shamsi_date/shamsi_date.dart';

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
  void initState() {
    super.initState();

    // Start with the current Jalali year rather than the Gregorian year.
    _year.text = Jalali.now().year.toString();
  }

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _year.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // BIRTH DATE
  // ---------------------------------------------------------------------------

  Jalali? _getBirthDate() {
    final year = int.tryParse(_year.text.trim());
    final month = int.tryParse(_month ?? '');
    final day = int.tryParse(_day ?? '');

    if (year == null || month == null || day == null) {
      return null;
    }

    try {
      return Jalali(year, month, day);
    } on DateException {
      return null;
    } catch (_) {
      return null;
    }
  }

  bool _isFutureBirthDate(Jalali birthDate) {
    final today = Jalali.now();

    return birthDate > today;
  }

  String _formatJalali(Jalali date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  // ---------------------------------------------------------------------------
  // SIGN UP
  // ---------------------------------------------------------------------------

  Future<void> _signUp() async {
    final username = _username.text.trim();
    final email = _email.text.trim();
    final password = _password.text;
    final confirmPassword = _confirmPassword.text;

    if (username.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        _year.text.trim().isEmpty ||
        _day == null ||
        _month == null ||
        _gender == null) {
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

    if (password != confirmPassword) {
      _message('رمز عبور و تکرار آن یکسان نیستند.');
      return;
    }

    // Validate the actual Jalali date.
    final birthDate = _getBirthDate();

    if (birthDate == null) {
      _message('تاریخ تولد واردشده معتبر نیست.');
      return;
    }

    // Prevent dates in the future.
    if (_isFutureBirthDate(birthDate)) {
      _message('تاریخ تولد نمی‌تواند در آینده باشد.');
      return;
    }

    setState(() => _loading = true);

    try {
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
      );

      final user = response.user;

      if (user == null) {
        throw const AuthException('ساخت حساب انجام نشد.');
      }

      // Convert the Jalali birthday to Gregorian for Supabase.
      //
      // Example:
      // Jalali 1388-05-20
      // becomes its equivalent Gregorian date.
      final gregorianBirthDate = birthDate.toGregorian();

      final birthDateForDatabase =
          '${gregorianBirthDate.year.toString().padLeft(4, '0')}-'
          '${gregorianBirthDate.month.toString().padLeft(2, '0')}-'
          '${gregorianBirthDate.day.toString().padLeft(2, '0')}';

      await supabase.from('users').insert({
        'id': user.id,
        'username': username,
        'gender': _gender,

        // Store as a real Gregorian date in PostgreSQL.
        'birth_date': birthDateForDatabase,

        // Optional: if you have this column, keep the original
        // Shamsi representation as well.
        //
        // 'birth_date_shamsi': _formatJalali(birthDate),
      });

      if (!mounted) return;

      Navigator.pushReplacementNamed(
        context,
        '/calibrate',
        arguments: _gender,
      );
    } on AuthException catch (error) {
      _message(error.message);
    } catch (error) {
      debugPrint('Signup error: $error');
      _message(
        'ثبت‌نام انجام نشد. ممکن است این ایمیل قبلاً استفاده شده باشد.',
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // UI HELPERS
  // ---------------------------------------------------------------------------

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

  InputDecoration _dec(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
    );
  }

  // ---------------------------------------------------------------------------
  // BIRTH DATE UI
  // ---------------------------------------------------------------------------

  Widget _birthFields(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 430;

    final selectedYear = int.tryParse(_year.text.trim());

    int maxDays = 31;

    if (selectedYear != null && _month != null) {
      final month = int.tryParse(_month!);

      if (month != null && month >= 1 && month <= 12) {
        try {
          maxDays = Jalali(
            selectedYear,
            month,
            1,
          ).monthLength;
        } catch (_) {
          maxDays = month <= 6 ? 31 : (month <= 11 ? 30 : 29);
        }
      }
    }

    // If the user changes month/year and the selected day becomes invalid,
    // clear it.
    final selectedDay = int.tryParse(_day ?? '');

    if (selectedDay != null && selectedDay > maxDays) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _day = null);
        }
      });
    }

    final day = DropdownButtonFormField<String>(
      value: _day,
      decoration: const InputDecoration(
        labelText: 'روز',
        prefixIcon: Icon(Icons.today_outlined),
      ),
      items: List.generate(
        maxDays,
            (i) => '${i + 1}'.padLeft(2, '0'),
      )
          .map(
            (day) => DropdownMenuItem(
          value: day,
          child: Text(day),
        ),
      )
          .toList(),
      onChanged: (value) {
        setState(() => _day = value);
      },
    );

    final monthNames = const [
      'فروردین',
      'اردیبهشت',
      'خرداد',
      'تیر',
      'مرداد',
      'شهریور',
      'مهر',
      'آبان',
      'آذر',
      'دی',
      'بهمن',
      'اسفند',
    ];

    final month = DropdownButtonFormField<String>(
      value: _month,
      decoration: const InputDecoration(
        labelText: 'ماه',
        prefixIcon: Icon(Icons.calendar_month_outlined),
      ),
      items: List.generate(
        12,
            (i) {
          final value = '${i + 1}'.padLeft(2, '0');

          return DropdownMenuItem(
            value: value,
            child: Text(monthNames[i]),
          );
        },
      ).toList(),
      onChanged: (value) {
        setState(() {
          _month = value;

          // Clear day if it isn't valid for the new month.
          final day = int.tryParse(_day ?? '');

          if (day != null) {
            final year = int.tryParse(_year.text.trim());

            if (year != null && value != null) {
              try {
                final monthNumber = int.parse(value);
                final maxDays = Jalali(
                  year,
                  monthNumber,
                  1,
                ).monthLength;

                if (day > maxDays) {
                  _day = null;
                }
              } catch (_) {
                _day = null;
              }
            }
          }
        });
      },
    );

    final year = TextField(
      controller: _year,
      keyboardType: TextInputType.number,
      textDirection: TextDirection.ltr,
      decoration: const InputDecoration(
        labelText: 'سال',
        prefixIcon: Icon(Icons.event_outlined),
      ),
      onChanged: (_) {
        setState(() {
          // Rebuild the day dropdown because Esfand depends on
          // whether the Jalali year is a leap year.
        });
      },
    );

    if (narrow) {
      return Column(
        children: [
          day,
          const SizedBox(height: 10),
          month,
          const SizedBox(height: 10),
          year,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: day),
        const SizedBox(width: 9),
        Expanded(child: month),
        const SizedBox(width: 9),
        Expanded(child: year),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: background,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 720;
              final side = constraints.maxWidth >= 650 ? 34.0 : 18.0;

              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  side,
                  compact ? 8 : 14,
                  side,
                  28,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 560,
                    ),
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: () =>
                                  Navigator.maybePop(context),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white,
                              ),
                              icon: const Icon(
                                Icons.arrow_forward_rounded,
                                color: text,
                              ),
                            ),
                            const Spacer(),
                            Image.asset(
                              'assets/logo.png',
                              width: compact ? 42 : 48,
                              height: compact ? 42 : 48,
                            ),
                            const Spacer(),
                            const SizedBox(width: 48),
                          ],
                        ),

                        SizedBox(
                          height: compact ? 14 : 20,
                        ),

                        Text(
                          'حساب خودت را بساز',
                          style: TextStyle(
                            color: text,
                            fontSize: compact ? 24 : 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),

                        const SizedBox(height: 7),

                        const Text(
                          'اطلاعات پایه کمک می‌کنند تجربه سی از همان ابتدا شخصی‌تر باشد.',
                          style: TextStyle(
                            color: subtext,
                            fontSize: 12,
                            height: 1.7,
                          ),
                        ),

                        SizedBox(
                          height: compact ? 14 : 20,
                        ),

                        Container(
                          padding: EdgeInsets.all(
                            compact ? 16 : 20,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                            BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black
                                    .withValues(alpha: .045),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              TextField(
                                controller: _username,
                                decoration: _dec(
                                  'نام کاربری',
                                  Icons.person_outline_rounded,
                                ),
                              ),

                              const SizedBox(height: 13),

                              TextField(
                                controller: _email,
                                keyboardType:
                                TextInputType.emailAddress,
                                textDirection: TextDirection.ltr,
                                decoration: _dec(
                                  'ایمیل',
                                  Icons.mail_outline_rounded,
                                ),
                              ),

                              const SizedBox(height: 13),

                              TextField(
                                controller: _password,
                                obscureText:
                                _obscurePassword,
                                textDirection:
                                TextDirection.ltr,
                                decoration:
                                _dec(
                                  'رمز عبور',
                                  Icons.lock_outline_rounded,
                                ).copyWith(
                                  suffixIcon:
                                  IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword =
                                        !_obscurePassword;
                                      });
                                    },
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons
                                          .visibility_off_outlined
                                          : Icons
                                          .visibility_outlined,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 13),

                              TextField(
                                controller: _confirmPassword,
                                obscureText:
                                _obscureConfirm,
                                textDirection:
                                TextDirection.ltr,
                                decoration:
                                _dec(
                                  'تکرار رمز عبور',
                                  Icons.lock_reset_outlined,
                                ).copyWith(
                                  suffixIcon:
                                  IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _obscureConfirm =
                                        !_obscureConfirm;
                                      });
                                    },
                                    icon: Icon(
                                      _obscureConfirm
                                          ? Icons
                                          .visibility_off_outlined
                                          : Icons
                                          .visibility_outlined,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 16),

                              const Align(
                                alignment:
                                Alignment.centerRight,
                                child: Text(
                                  'تاریخ تولد',
                                  style: TextStyle(
                                    color: text,
                                    fontSize: 13,
                                    fontWeight:
                                    FontWeight.w800,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 8),

                              _birthFields(context),

                              const SizedBox(height: 14),

                              DropdownButtonFormField<String>(
                                value: _gender,
                                decoration: _dec(
                                  'جنسیت',
                                  Icons.wc_outlined,
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'male',
                                    child: Text('آقا'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'female',
                                    child: Text('خانم'),
                                  ),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _gender = value;
                                  });
                                },
                              ),

                              const SizedBox(height: 20),

                              SizedBox(
                                width: double.infinity,
                                height: compact ? 52 : 56,
                                child: ElevatedButton(
                                  onPressed:
                                  _loading ? null : _signUp,
                                  style:
                                  ElevatedButton.styleFrom(
                                    backgroundColor:
                                    primaryGreen,
                                    foregroundColor:
                                    Colors.white,
                                    elevation: 0,
                                    shape:
                                    RoundedRectangleBorder(
                                      borderRadius:
                                      BorderRadius.circular(
                                        18,
                                      ),
                                    ),
                                  ),
                                  child: _loading
                                      ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child:
                                    CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color:
                                      Colors.white,
                                    ),
                                  )
                                      : Text(
                                    'ساخت حساب و ادامه',
                                    style: TextStyle(
                                      fontSize:
                                      compact
                                          ? 14
                                          : 16,
                                      fontWeight:
                                      FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        Container(
                          padding:
                          const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: mint,
                            borderRadius:
                            BorderRadius.circular(18),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.verified_user_outlined,
                                color: primaryGreen,
                                size: 22,
                              ),
                              SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  'بعد از ساخت حساب، وارد مرحله کالیبراسیون وضعیت بدن می‌شوی تا تشخیص شخصی‌سازی شود.',
                                  style: TextStyle(
                                    color: text,
                                    fontSize: 11,
                                    height: 1.6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        Wrap(
                          alignment:
                          WrapAlignment.center,
                          crossAxisAlignment:
                          WrapCrossAlignment.center,
                          children: [
                            const Text(
                              'قبلاً ثبت‌نام کرده‌اید؟',
                              style: TextStyle(
                                color: subtext,
                                fontSize: 12,
                              ),
                            ),
                            TextButton(
                              onPressed: () =>
                                  Navigator
                                      .pushReplacementNamed(
                                    context,
                                    '/login',
                                  ),
                              child: const Text(
                                'وارد شوید',
                                style: TextStyle(
                                  color: primaryTeal,
                                  fontWeight:
                                  FontWeight.w900,
                                ),
                              ),
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
}