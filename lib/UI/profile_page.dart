import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'settings_page.dart';

import 'calibration_screen.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const Color kBg = Color(0xFFFCFCFA);
  static const Color kCard = Color(0xFFFFFFFF);
  static const Color kPrimary = Color(0xFF53C8A0);
  static const Color kPrimaryDark = Color(0xFF2E8D6D);
  static const Color kMint = Color(0xFFEAF8F1);
  static const Color kMintSoft = Color(0xFFF3FBF7);
  static const Color kText = Color(0xFF273632);
  static const Color kSubtext = Color(0xFF8C9994);
  static const Color kLine = Color(0xFFEDF1EE);
  static const Color kShadow = Color(0x12000000);
  static const Color kWarn = Color(0xFFF0C84D);
  static const Color kDanger = Color(0xFFF28B82);

  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = true;
  bool _isSaving = false;

  String _fullName = '';
  String _username = '';
  String _gender = 'male';
  String _birthDate = '';
  double _hunchDivisor = 0;

  int _healthScore = 80;
  int _healthyDays = 0;
  int _alertsCount = 0;
  int _healthyBehaviors = 0;
  int _screenTimeMinutes = 0;
  int _badPostureMinutes = 0;
  int _badLightMinutes = 0;
  int _combinedRiskMinutes = 0;
  int _eyeBreakCount = 0;
  int _postureCorrectionCount = 0;
  bool _darkModeEnabled = false;

  DateTime? _createdAt;
  DateTime? _lastCalibratedAt;
  DateTime? _lastActiveAt;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final data = await _supabase.from('users').select().eq('id', user.id).maybeSingle();

      if (!mounted) return;

      if (data == null) {
        setState(() {
          _fullName = '';
          _username = '';
          _gender = 'male';
          _birthDate = '';
          _hunchDivisor = 0;
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _fullName = _readString(data['full_name']);
        _username = _readString(data['username']);
        _gender = _readString(data['gender'], fallback: 'male');
        _birthDate = _readString(data['birth_date']);
        _hunchDivisor = _readDouble(data['hunch_divisor']);

        _healthScore = _readInt(data['health_score'], fallback: 80);
        _healthyDays = _readInt(data['healthy_days']);
        _alertsCount = _readInt(data['alerts_count']);
        _healthyBehaviors = _readInt(data['healthy_behaviors']);
        _screenTimeMinutes = _readInt(data['screen_time_minutes']);
        _badPostureMinutes = _readInt(data['bad_posture_minutes']);
        _badLightMinutes = _readInt(data['bad_light_minutes']);
        _combinedRiskMinutes = _readInt(data['combined_risk_minutes']);
        _eyeBreakCount = _readInt(data['eye_break_count']);
        _postureCorrectionCount = _readInt(data['posture_correction_count']);
        _darkModeEnabled = data['dark_mode_enabled'] == true;

        _createdAt = _readDateTime(data['created_at']);
        _lastCalibratedAt = _readDateTime(data['last_calibrated_at']);
        _lastActiveAt = _readDateTime(data['last_active_at']);

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در خواندن اطلاعات کاربر: $e')),
      );
    }
  }

  Future<void> _updateUserData({
    required String newFullName,
    required String newUsername,
    required String newGender,
    required String newBirthDate,
  }) async {
    try {
      setState(() {
        _isSaving = true;
      });

      final user = _supabase.auth.currentUser;
      if (user == null) {
        if (!mounted) return;
        setState(() {
          _isSaving = false;
        });
        return;
      }

      await _supabase.from('users').update({
        'full_name': newFullName,
        'username': newUsername,
        'gender': newGender,
        'birth_date': newBirthDate,
        'last_active_at': DateTime.now().toIso8601String(),
      }).eq('id', user.id);

      if (!mounted) return;

      setState(() {
        _fullName = newFullName;
        _username = newUsername;
        _gender = newGender;
        _birthDate = newBirthDate;
        _lastActiveAt = DateTime.now();
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اطلاعات با موفقیت بروزرسانی شد')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در بروزرسانی اطلاعات: $e')),
      );
    }
  }

  Future<void> _markCalibrationNow() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return;
      }

      final now = DateTime.now();
      await _supabase.from('users').update({
        'last_calibrated_at': now.toIso8601String(),
        'last_active_at': now.toIso8601String(),
      }).eq('id', user.id);

      if (!mounted) return;
      setState(() {
        _lastCalibratedAt = now;
        _lastActiveAt = now;
      });
    } catch (_) {}
  }

  int _readInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  double _readDouble(dynamic value, {double fallback = 0}) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  String _readString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  DateTime? _readDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  int _calculateAgeFromTextDate(String birthDate) {
    if (birthDate.trim().isEmpty) return 0;

    final normalized = birthDate.replaceAll('/', '-').trim();
    final parts = normalized.split('-');
    if (parts.length != 3) return 0;

    final year = int.tryParse(parts[0]) ?? 0;
    final month = int.tryParse(parts[1]) ?? 1;
    final day = int.tryParse(parts[2]) ?? 1;
    if (year <= 0) return 0;

    final now = DateTime.now();
    var age = now.year - year;
    if (now.month < month || (now.month == month && now.day < day)) {
      age--;
    }
    return age < 0 ? 0 : age;
  }

  int _daysSince(DateTime? date) {
    if (date == null) return 0;
    return DateTime.now().difference(date).inDays.clamp(0, 99999);
  }

  String _formatMinutes(int minutes) {
    if (minutes <= 0) return '۰د';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${_toPersianDigits(m.toString())}د';
    if (m == 0) return '${_toPersianDigits(h.toString())}س';
    return '${_toPersianDigits(h.toString())}س ${_toPersianDigits(m.toString())}د';
  }

  String _formatDateAgo(DateTime? date) {
    if (date == null) return 'ثبت نشده';
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) {
      return '${_toPersianDigits(diff.inDays.toString())} روز پیش';
    }
    if (diff.inHours > 0) {
      return '${_toPersianDigits(diff.inHours.toString())} ساعت پیش';
    }
    if (diff.inMinutes > 0) {
      return '${_toPersianDigits(diff.inMinutes.toString())} دقیقه پیش';
    }
    return 'لحظاتی پیش';
  }

  String _toPersianDigits(String input) {
    const en = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const fa = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    var output = input;
    for (var i = 0; i < en.length; i++) {
      output = output.replaceAll(en[i], fa[i]);
    }
    return output;
  }

  Future<void> _showEditProfileDialog() async {
    final fullNameController = TextEditingController(text: _fullName);
    final usernameController = TextEditingController(text: _username);
    final birthDateController = TextEditingController(text: _birthDate);
    String gender = _gender;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: kCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: const Text(
              'ویرایش پروفایل',
              style: TextStyle(
                color: kText,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: fullNameController,
                  decoration: const InputDecoration(
                    labelText: 'نام و نام خانوادگی',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: usernameController,
                  decoration: const InputDecoration(
                    labelText: 'نام کاربری',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: birthDateController,
                  decoration: const InputDecoration(
                    labelText: 'تاریخ تولد',
                    hintText: '2004-08-17',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: gender,
                  decoration: const InputDecoration(
                    labelText: 'جنسیت',
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
                  onChanged: (val) {
                    if (val != null) {
                      gender = val;
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('انصراف'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final newFullName = fullNameController.text.trim();
                  final newUsername = usernameController.text.trim();
                  final newBirthDate = birthDateController.text.trim();

                  Navigator.of(ctx).pop();
                  await _updateUserData(
                    newFullName: newFullName,
                    newUsername: newUsername,
                    newGender: gender,
                    newBirthDate: newBirthDate,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Text('ذخیره'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCircleIconButton(IconData icon) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: kCard,
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(
            color: kShadow,
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, color: kText, size: 20),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
      child: Row(
        children: [
          GestureDetector(
          onTap: () {
      Navigator.of(context).push(
      MaterialPageRoute(
      builder: (_) => const SettingsPage(),
       ),
      );
    },
      child: _buildCircleIconButton(
        Icons.settings_outlined,
      ),
    ),
          const Spacer(),
          const Text(
            'پروفایل',
            style: TextStyle(
              color: kText,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          _buildCircleIconButton(Icons.settings_outlined),
        ],
      ),
    );
  }

  Widget _buildProfileHeroCard() {
    final age = _calculateAgeFromTextDate(_birthDate);
    final ageLabel = age > 0 ? _toPersianDigits(age.toString()) : '—';
    final genderText = _gender == 'female' ? 'خانم' : 'آقا';
    final daysWithSi = _daysSince(_createdAt);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Container(
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: kShadow,
              blurRadius: 26,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Row(
            children: [
              Container(
                width: 88,
                height: 88,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFD3EEDC),
                    width: 2,
                  ),
                ),
                child: Stack(
                  children: [
                    Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFFE6F6EE),
                            Color(0xFFCBECD9),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.person_rounded,
                          size: 42,
                          color: kPrimaryDark,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: kPrimary,
                          shape: BoxShape.circle,
                          border: Border.all(color: kCard, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _fullName.isNotEmpty
                                ? _fullName
                                : (_username.isNotEmpty ? _username : 'کاربر Si'),
                            style: const TextStyle(
                              color: kText,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: _isSaving ? null : _showEditProfileDialog,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: kCard,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: kLine),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _isSaving ? 'در حال ذخیره...' : 'ویرایش',
                                  style: const TextStyle(
                                    color: kSubtext,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.edit_outlined,
                                  size: 13,
                                  color: kSubtext,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _username.isEmpty ? 'هوای خودت رو داشته باش' : '@$_username',
                      style: const TextStyle(
                        color: kSubtext,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _InfoMetric(
                            icon: Icons.person_outline_rounded,
                            value: ageLabel,
                            label: 'سن',
                          ),
                        ),
                        const _VerticalDividerSoft(),
                        Expanded(
                          child: _InfoMetric(
                            icon: Icons.female_outlined,
                            value: genderText,
                            label: 'جنسیت',
                          ),
                        ),
                        const _VerticalDividerSoft(),
                        Expanded(
                          child: _InfoMetric(
                            icon: Icons.calendar_today_outlined,
                            value: _toPersianDigits(daysWithSi.toString()),
                            label: 'همراه با Si',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoreCard() {
    final score = _healthScore.clamp(0, 100);
    final scoreValue = score / 100.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Container(
        height: 138,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            colors: [
              Color(0xFFF3FCEB),
              Color(0xFFE6FAF0),
              Color(0xFFD7F4F4),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: const [
            BoxShadow(
              color: kShadow,
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              SizedBox(
                width: 106,
                height: 106,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 88,
                      height: 88,
                      child: CircularProgressIndicator(
                        value: scoreValue,
                        strokeWidth: 6,
                        backgroundColor: Colors.white,
                        valueColor: const AlwaysStoppedAnimation<Color>(kPrimary),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _toPersianDigits(score.toString()),
                          style: const TextStyle(
                            color: kText,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          '/100',
                          style: TextStyle(
                            color: kSubtext,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'امتیاز سلامتی',
                          style: TextStyle(
                            color: kText,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(
                          Icons.favorite_rounded,
                          color: kPrimary,
                          size: 16,
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'ترکیبی از وضعیت بدن، نور، وقفه‌های سالم و رفتار روزانه',
                      style: TextStyle(
                        color: kSubtext,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.spa_outlined,
                size: 56,
                color: Color(0x8842D2A7),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = <_QuickActionItem>[
      const _QuickActionItem(
        icon: Icons.self_improvement_outlined,
        title: 'تمرینات',
        subtitle: 'حرکت‌های اصلاحی',
      ),
      const _QuickActionItem(
        icon: Icons.remove_red_eye_outlined,
        title: 'استراحت چشم',
        subtitle: 'وقفه‌های ثبت‌شده',
      ),
      const _QuickActionItem(
        icon: Icons.wb_incandescent_outlined,
        title: 'نور محیط',
        subtitle: 'کنترل روشنایی',
      ),
      const _QuickActionItem(
        icon: Icons.bar_chart_rounded,
        title: 'گزارش‌ها',
        subtitle: 'روند پیشرفت',
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Container(
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(26),
          boxShadow: const [
            BoxShadow(
              color: kShadow,
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: List.generate(actions.length, (index) {
            final item = actions[index];
            return Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
                decoration: BoxDecoration(
                  border: index == actions.length - 1
                      ? null
                      : const Border(
                    left: BorderSide(color: kLine),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: kMintSoft,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        item.icon,
                        color: kPrimaryDark,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      item.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: kText,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: kSubtext,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildModuleStatusCard() {
    final postureBad = _badPostureMinutes >= 60;
    final lightBad = _badLightMinutes >= 60;
    final combinedBad = _combinedRiskMinutes >= 30;

    final statuses = <_ModuleStatusItem>[
      _ModuleStatusItem(
        icon: Icons.remove_red_eye_outlined,
        title: 'فاصله چشم',
        status: _eyeBreakCount > 0 ? 'فعال' : 'کم‌وقفه',
        dot: _eyeBreakCount > 0 ? kPrimary : kWarn,
      ),
      _ModuleStatusItem(
        icon: Icons.psychology_outlined,
        title: 'گردن',
        status: postureBad ? 'نیاز به توجه' : 'مناسب',
        dot: postureBad ? kWarn : kPrimary,
      ),
      _ModuleStatusItem(
        icon: Icons.accessibility_new_outlined,
        title: 'وضعیت بدن',
        status: postureBad ? 'زمان نامناسب بالا' : 'مناسب',
        dot: postureBad ? kWarn : kPrimary,
      ),
      _ModuleStatusItem(
        icon: Icons.back_hand_outlined,
        title: 'اصلاح‌ها',
        status: _postureCorrectionCount > 0 ? 'ثبت شده' : 'بدون ثبت',
        dot: _postureCorrectionCount > 0 ? kPrimary : kWarn,
      ),
      _ModuleStatusItem(
        icon: Icons.lightbulb_outline_rounded,
        title: 'نور محیط',
        status: lightBad ? 'کم یا نامناسب' : 'مناسب',
        dot: lightBad ? kWarn : kPrimary,
      ),
      _ModuleStatusItem(
        icon: Icons.warning_amber_rounded,
        title: 'ریسک ترکیبی',
        status: combinedBad ? 'بالا' : 'کنترل‌شده',
        dot: combinedBad ? kDanger : kPrimary,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Container(
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(26),
          boxShadow: const [
            BoxShadow(
              color: kShadow,
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            children: [
              Row(
                children: const [
                  Text(
                    'وضعیت زنده',
                    style: TextStyle(
                      color: kPrimaryDark,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(
                    Icons.live_help,
                    size: 11,
                    color: kPrimaryDark,
                  ),
                  Spacer(),
                  Text(
                    'وضعیت ماژول‌ها',
                    style: TextStyle(
                      color: kText,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: List.generate(statuses.length, (index) {
                  final item = statuses[index];
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: item.dot == kPrimary
                                  ? kMintSoft
                                  : item.dot == kDanger
                                  ? const Color(0xFFFFEFEF)
                                  : const Color(0xFFFFF8E3),
                            ),
                            child: Icon(
                              item.icon,
                              color: kPrimaryDark,
                              size: 22,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: kText,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: item.dot,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  item.status,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: kSubtext,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTodaySummaryCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Container(
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(26),
          boxShadow: const [
            BoxShadow(
              color: kShadow,
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Spacer(),
                    Text(
                      'خلاصه امروز',
                      style: TextStyle(
                        color: kText,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFF7FBEF),
                      Color(0xFFE5F8EE),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.health_and_safety_outlined,
                      size: 34,
                      color: Color(0x6642D2A7),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'زمان وضعیت نامناسب: ${_formatMinutes(_badPostureMinutes)}  |  نور نامناسب: ${_formatMinutes(_badLightMinutes)}',
                        style: const TextStyle(
                          color: kText,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _SummaryMetric(
                        icon: Icons.calendar_today_outlined,
                        value: _toPersianDigits(_healthyDays.toString()),
                        label: 'روزهای سالم',
                      ),
                    ),
                    Expanded(
                      child: _SummaryMetric(
                        icon: Icons.notifications_none_rounded,
                        value: _toPersianDigits(_alertsCount.toString()),
                        label: 'هشدارها',
                      ),
                    ),
                    Expanded(
                      child: _SummaryMetric(
                        icon: Icons.menu_book_outlined,
                        value: _toPersianDigits(_healthyBehaviors.toString()),
                        label: 'رفتار سالم',
                      ),
                    ),
                    Expanded(
                      child: _SummaryMetric(
                        icon: Icons.access_time_rounded,
                        value: _formatMinutes(_screenTimeMinutes),
                        label: 'زمان استفاده',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRiskMetricsCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Container(
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(26),
          boxShadow: const [
            BoxShadow(
              color: kShadow,
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'شاخص‌های ریسک',
                style: TextStyle(
                  color: kText,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _RiskMetricCard(
                      title: 'بدنشستن',
                      value: _formatMinutes(_badPostureMinutes),
                      icon: Icons.airline_seat_recline_normal_outlined,
                      tint: _badPostureMinutes >= 60 ? kWarn : kPrimary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _RiskMetricCard(
                      title: 'نور بد',
                      value: _formatMinutes(_badLightMinutes),
                      icon: Icons.light_mode_outlined,
                      tint: _badLightMinutes >= 60 ? kWarn : kPrimary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _RiskMetricCard(
                      title: 'همزمان',
                      value: _formatMinutes(_combinedRiskMinutes),
                      icon: Icons.warning_amber_rounded,
                      tint: _combinedRiskMinutes >= 30 ? kDanger : kPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _SummaryMetric(
                      icon: Icons.visibility_outlined,
                      value: _toPersianDigits(_eyeBreakCount.toString()),
                      label: 'وقفه چشم',
                    ),
                  ),
                  Expanded(
                    child: _SummaryMetric(
                      icon: Icons.accessibility_new_outlined,
                      value: _toPersianDigits(_postureCorrectionCount.toString()),
                      label: 'اصلاح وضعیت',
                    ),
                  ),
                  Expanded(
                    child: _SummaryMetric(
                      icon: Icons.tune_outlined,
                      value: _hunchDivisor == 0 ? '—' : _hunchDivisor.toStringAsFixed(2),
                      label: 'کالیبراسیون',
                    ),
                  ),
                  Expanded(
                    child: _SummaryMetric(
                      icon: Icons.dark_mode_outlined,
                      value: _darkModeEnabled ? 'روشن' : 'خاموش',
                      label: 'حالت شب',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalibrationCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      child: Container(
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: kShadow,
              blurRadius: 22,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: kMintSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.settings_accessibility_outlined,
                  color: kPrimaryDark,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'کالیبراسیون شخصی',
                      style: TextStyle(
                        color: kText,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'آخرین بروزرسانی - ${_formatDateAgo(_lastCalibratedAt)}',
                      style: const TextStyle(
                        color: kSubtext,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () async {
                  await _markCalibrationNow();
                  if (!mounted) return;
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) => const CalibrationScreen(cameras: []),
                    ),
                  );
                },
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: kPrimary,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'کالیبره مجدد',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: kBg,
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: kBg,
        body: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverToBoxAdapter(child: _buildProfileHeroCard()),
              SliverToBoxAdapter(child: _buildScoreCard()),
              SliverToBoxAdapter(child: _buildQuickActions()),
              SliverToBoxAdapter(child: _buildModuleStatusCard()),
              SliverToBoxAdapter(child: _buildTodaySummaryCard()),
              SliverToBoxAdapter(child: _buildRiskMetricsCard()),
              SliverToBoxAdapter(child: _buildCalibrationCard()),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoMetric extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _InfoMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          color: _ProfilePageState.kPrimaryDark,
          size: 20,
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: _ProfilePageState.kText,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            color: _ProfilePageState.kSubtext,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _VerticalDividerSoft extends StatelessWidget {
  const _VerticalDividerSoft();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 52,
      color: _ProfilePageState.kLine,
    );
  }
}

class _QuickActionItem {
  final IconData icon;
  final String title;
  final String subtitle;

  const _QuickActionItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}

class _ModuleStatusItem {
  final IconData icon;
  final String title;
  final String status;
  final Color dot;

  const _ModuleStatusItem({
    required this.icon,
    required this.title,
    required this.status,
    required this.dot,
  });
}

class _SummaryMetric extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _SummaryMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          color: _ProfilePageState.kSubtext,
          size: 22,
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: _ProfilePageState.kText,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _ProfilePageState.kSubtext,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _RiskMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color tint;

  const _RiskMetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final bg = tint == _ProfilePageState.kPrimary
        ? _ProfilePageState.kMintSoft
        : tint == _ProfilePageState.kDanger
        ? const Color(0xFFFFEFEF)
        : const Color(0xFFFFF8E3);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(icon, color: tint, size: 22),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: _ProfilePageState.kSubtext,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: _ProfilePageState.kText,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
