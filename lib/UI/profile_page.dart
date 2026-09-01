import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../backend/daily_health_metric.dart';
import '../backend/health_data_repository.dart';
import '../services/background_service.dart';
import 'calibration_screen.dart';
import 'exercise_center_page.dart';
import 'settings_page.dart';

class ProfilePage extends StatefulWidget {
  static final GlobalKey<ProfilePageState> tourKey = GlobalKey<ProfilePageState>();
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => ProfilePageState();
}

class ProfilePageState extends State<ProfilePage> {
  final ScrollController _tourScrollController = ScrollController();
  final GlobalKey _tourSettingsRowKey = GlobalKey();
  static const bg = Color(0xFFF4F9F7);
  static const card = Colors.white;
  static const green = Color(0xFF42D2A7);
  static const teal = Color(0xFF45C4D0);
  static const text = Color(0xFF263B37);
  static const subtext = Color(0xFF7D8D89);
  static const mint = Color(0xFFE8F8F1);
  static const line = Color(0xFFE8EFEC);
  static const danger = Color(0xFFD95C5C);

  final supabase = Supabase.instance.client;

  bool loading = true;
  bool saving = false;

  String fullName = '';
  String username = '';
  String gender = 'male';
  String birthDate = '';

  DateTime? lastCalibratedAt;
  double hunchDivisor = 0;

  DailyHealthMetric? today;
  String? mood;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ---------------------------------------------------------------------------
  // DATA
  // ---------------------------------------------------------------------------

  Future<void> _load() async {
    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        if (mounted) {
          setState(() => loading = false);
        }
        return;
      }

      final results = await Future.wait<dynamic>([
        supabase
            .from('users')
            .select()
            .eq('id', user.id)
            .maybeSingle(),
        HealthDataRepository.instance.getDailyMetrics(days: 1),
      ]);

      final data = results[0] as Map<String, dynamic>?;
      final daily = results[1] as List<Map<String, dynamic>>;

      if (!mounted) return;

      setState(() {
        fullName = _string(data?['full_name']);
        username = _string(data?['username']);
        gender = _string(
          data?['gender'],
          fallback: 'male',
        );
        birthDate = _string(data?['birth_date']);

        hunchDivisor = _number(data?['hunch_divisor']);

        lastCalibratedAt =
            _date(data?['last_calibrated_at']);

        today = daily.isEmpty
            ? null
            : DailyHealthMetric.fromMap(daily.first);

        loading = false;
      });
    } catch (error) {
      debugPrint('[Profile] Load failed: $error');

      if (mounted) {
        setState(() => loading = false);
        _message('اطلاعات حساب بارگذاری نشد.');
      }
    }
  }

  String _string(
      dynamic value, {
        String fallback = '',
      }) {
    final valueString = value?.toString().trim();

    if (valueString == null || valueString.isEmpty) {
      return fallback;
    }

    return valueString;
  }

  double _number(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse('$value') ?? 0;
  }

  DateTime? _date(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  // ---------------------------------------------------------------------------
  // BIRTH DATE / SHAMSI
  // ---------------------------------------------------------------------------

  int get age {
    if (birthDate.isEmpty) return 0;

    try {
      // birth_date is stored in Supabase as Gregorian.
      final gregorian = DateTime.parse(birthDate);

      final birth = Jalali.fromDateTime(gregorian);
      final now = Jalali.now();

      var result = now.year - birth.year;

      if (now.month < birth.month ||
          (now.month == birth.month &&
              now.day < birth.day)) {
        result--;
      }

      return result < 0 ? 0 : result;
    } catch (_) {
      return 0;
    }
  }

  String _formatBirthDate(String value) {
    if (value.trim().isEmpty) {
      return 'ثبت نشده';
    }

    try {
      final gregorian = DateTime.parse(value);
      final jalali = Jalali.fromDateTime(gregorian);

      return '${jalali.year}/'
          '${jalali.month.toString().padLeft(2, '0')}/'
          '${jalali.day.toString().padLeft(2, '0')}';
    } catch (_) {
      // Compatibility with any old records that may already
      // contain a Shamsi date.
      final normalized = value.replaceAll('-', '/');
      final parts = normalized.split('/');

      if (parts.length == 3) {
        return normalized;
      }

      return value;
    }
  }

  // ---------------------------------------------------------------------------
  // EDIT PROFILE
  // ---------------------------------------------------------------------------

  Future<void> _editProfile() async {
    final user = supabase.auth.currentUser;

    if (user == null) return;

    final result = await showDialog<_ProfileEditResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return _EditProfileDialog(
          fullName: fullName,
          username: username,
          gender: gender,
          birthDate: birthDate,
          supabase: supabase,
        );
      },
    );

    // IMPORTANT:
    //
    // The dialog is completely gone at this point.
    // Only NOW do we update ProfilePage's state.
    //
    // This prevents the parent and dialog from fighting over
    // focus/dependencies while the keyboard is being removed.

    if (!mounted || result == null) return;

    setState(() {
      fullName = result.fullName;
      username = result.username;
      gender = result.gender;
      birthDate = result.birthDate;
    });

    _message('اطلاعات حساب ذخیره شد.');
  }

  // ---------------------------------------------------------------------------
  // LOGOUT
  // ---------------------------------------------------------------------------

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('خروج از حساب'),
            content: const Text(
              'از حساب فعلی خارج می‌شوی و برای ورود دوباره '
                  'به صفحه ورود منتقل می‌شوی.',
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.pop(ctx, false),
                child: const Text('انصراف'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: danger,
                ),
                child: const Text('خروج'),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true) return;

    try {
      BackgroundMonitorService.stop();

      if (await FlutterOverlayWindow.isActive()) {
        await FlutterOverlayWindow.closeOverlay();
      }
    } catch (_) {}

    await supabase.auth.signOut();

    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      '/login',
          (route) => false,
    );
  }

  // ---------------------------------------------------------------------------
  // NAVIGATION
  // ---------------------------------------------------------------------------

  Future<void> _openCalibration() async {
    try {
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        _message('دوربین در دسترس نیست.');
        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              CalibrationScreen(cameras: cameras),
        ),
      );

      await _load();
    } catch (error) {
      debugPrint(
        '[Profile] Calibration failed: $error',
      );

      _message('باز کردن کالیبراسیون ممکن نشد.');
    }
  }

  Future<void> _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SettingsPage(),
      ),
    );
  }

  Future<void> _openExercise() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ExerciseCenterPage(),
      ),
    );
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

  Widget _card({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(18),
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.035),
            blurRadius: 20,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionTitle(
      String title,
      String subtitle,
      ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: text,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(
              color: subtext,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ACCOUNT HEADER
  // ---------------------------------------------------------------------------

  Widget _accountHeader() {
    return _card(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [green, teal],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        color: text,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      username.isEmpty
                          ? 'پروفایل شخصی'
                          : '@$username',
                      style: const TextStyle(
                        color: subtext,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              IconButton(
                onPressed: _editProfile,
                tooltip: 'ویرایش اطلاعات',
                icon: const Icon(
                  Icons.edit_rounded,
                  color: text,
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Container(
            height: 1,
            color: line,
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: _miniInfo(
                  Icons.cake_outlined,
                  age > 0
                      ? '$age سال'
                      : 'ثبت نشده',
                  'سن',
                ),
              ),

              Container(
                width: 1,
                height: 34,
                color: line,
              ),

              Expanded(
                child: _miniInfo(
                  Icons.wc_outlined,
                  gender == 'female'
                      ? 'خانم'
                      : 'آقا',
                  'جنسیت',
                ),
              ),

              Container(
                width: 1,
                height: 34,
                color: line,
              ),

              Expanded(
                child: _miniInfo(
                  Icons.tune_rounded,
                  hunchDivisor > 0
                      ? 'فعال'
                      : 'نیازمند',
                  'کالیبراسیون',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String get displayName {
    if (fullName.isNotEmpty) {
      return fullName;
    }

    if (username.isNotEmpty) {
      return username;
    }

    return 'کاربر سی';
  }

  Widget _miniInfo(
      IconData icon,
      String value,
      String label,
      ) {
    return Column(
      children: [
        Icon(
          icon,
          color: green,
          size: 19,
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            color: text,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: subtext,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // ACCOUNT DETAILS
  // ---------------------------------------------------------------------------

  Widget _accountDetails() {
    final email =
        supabase.auth.currentUser?.email ??
            'ثبت نشده';

    final calibrated =
    lastCalibratedAt == null
        ? 'هنوز انجام نشده'
        : _formatDate(lastCalibratedAt!);

    return _card(
      child: Column(
        children: [
          _detail(
            Icons.mail_outline_rounded,
            'ایمیل حساب',
            email,
            editable: false,
          ),

          const Divider(
            height: 22,
            color: line,
          ),

          _detail(
            Icons.alternate_email_rounded,
            'نام کاربری',
            username.isEmpty
                ? 'ثبت نشده'
                : username,
            onTap: _editProfile,
          ),

          const Divider(
            height: 22,
            color: line,
          ),

          _detail(
            Icons.cake_outlined,
            'تاریخ تولد',
            _formatBirthDate(birthDate),
            onTap: _editProfile,
          ),

          const Divider(
            height: 22,
            color: line,
          ),

          _detail(
            Icons.verified_outlined,
            'آخرین کالیبراسیون',
            calibrated,
            onTap: _openCalibration,
          ),
        ],
      ),
    );
  }

  Widget _detail(
      IconData icon,
      String label,
      String value, {
        VoidCallback? onTap,
        bool editable = true,
      }) {
    return InkWell(
      onTap: editable ? onTap : null,
      borderRadius: BorderRadius.circular(14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: mint,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: green,
              size: 20,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: subtext,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: text,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),

          if (editable)
            const Icon(
              Icons.chevron_left_rounded,
              color: subtext,
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HEALTH
  // ---------------------------------------------------------------------------

  Widget _healthSnapshot() {
    final score = today?.healthScore ?? 0;
    final screen =
        today?.screenTime.round() ?? 0;

    final posture =
    ((today?.hunch ?? 0) +
        (today?.neck ?? 0) +
        (today?.wrist ?? 0))
        .round();

    return Row(
      children: [
        Expanded(
          child: _metric(
            'امتیاز امروز',
            '$score',
            Icons.favorite_rounded,
          ),
        ),

        const SizedBox(width: 8),

        Expanded(
          child: _metric(
            'صفحه',
            '${screen}د',
            Icons.phone_android_rounded,
          ),
        ),

        const SizedBox(width: 8),

        Expanded(
          child: _metric(
            'وضعیت بدن',
            '${posture}د',
            Icons.accessibility_new_rounded,
          ),
        ),
      ],
    );
  }

  Widget _metric(
      String label,
      String value,
      IconData icon,
      ) {
    return _card(
      padding: const EdgeInsets.symmetric(
        vertical: 13,
        horizontal: 7,
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: green,
            size: 20,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: text,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: subtext,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // MOOD
  // ---------------------------------------------------------------------------

  Widget _moodCard() {
    const moods = {
      'خیلی خوب': '😄',
      'خوب': '🙂',
      'معمولی': '😐',
      'خسته': '😮‍💨',
      'بد': '😕',
    };

    return _card(
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.psychology_alt_rounded,
                color: green,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'حال امروز',
                style: TextStyle(
                  color: text,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),

          const SizedBox(height: 5),

          const Text(
            'یک ثبت کوتاه برای دنبال کردن حال روزانه.',
            style: TextStyle(
              color: subtext,
              fontSize: 11,
            ),
          ),

          const SizedBox(height: 12),

          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: moods.entries.map((entry) {
              return ChoiceChip(
                selected: mood == entry.key,
                label: Text(
                  '${entry.value} ${entry.key}',
                ),
                onSelected: (_) {
                  setState(() {
                    mood = entry.key;
                  });
                },
                selectedColor: mint,
                side: BorderSide(
                  color: mood == entry.key
                      ? green
                      : line,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // QUICK ACTIONS
  // ---------------------------------------------------------------------------

  Widget _quickActions() {
    return _card(
      child: Column(
        children: [
          _action(
            Icons.tune_rounded,
            'کالیبراسیون وضعیت بدن',
            hunchDivisor > 0
                ? 'فعال • آخرین تنظیم: ${lastCalibratedAt == null ? 'نامشخص' : _formatDate(lastCalibratedAt!)}'
                : 'برای شروع پایش انجام دهید',
            _openCalibration,
          ),

          const Divider(
            height: 22,
            color: line,
          ),

          _action(
            Icons.fitness_center_rounded,
            'مرکز تمرین',
            'تمرین‌های مرتبط با وضعیت بدنت',
            _openExercise,
          ),

          const Divider(
            height: 22,
            color: line,
          ),

          _tourSettingsAction(),
        ],
      ),
    );
  }

  Widget _tourSettingsAction() {
    return InkWell(
      key: _tourSettingsRowKey,
      onTap: _openSettings,
      borderRadius: BorderRadius.circular(15),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(color: mint, shape: BoxShape.circle),
            child: const Icon(Icons.settings_outlined, color: green),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('تنظیمات پایش', style: TextStyle(color: text, fontSize: 13, fontWeight: FontWeight.w900)),
                SizedBox(height: 3),
                Text('دوربین، هشدارها و محافظت از محتوا', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: subtext, fontSize: 10)),
              ],
            ),
          ),
          const Icon(Icons.chevron_left_rounded, color: subtext),
        ],
      ),
    );
  }

  Future<void> ensureTourSettingsVisible() async {
    if (!_tourScrollController.hasClients) return;
    await _tourScrollController.animateTo(
      _tourScrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
    await WidgetsBinding.instance.endOfFrame;
  }

  Widget _action(
      IconData icon,
      String title,
      String subtitle,
      VoidCallback onTap,
      ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: mint,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: green,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: text,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: subtext,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),

          const Icon(
            Icons.chevron_left_rounded,
            color: subtext,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.day.toString().padLeft(2, '0')}';
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: loading
              ? const Center(
            child: CircularProgressIndicator(
              color: green,
            ),
          )
              : RefreshIndicator(
            color: green,
            onRefresh: _load,
            child: ListView(
              controller: _tourScrollController,
              physics:
              const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                18,
                10,
                18,
                30,
              ),
              children: [
                Row(
                  children: [
                    const Text(
                      'پروفایل',
                      style: TextStyle(
                        color: text,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    const Spacer(),

                    IconButton(
                      onPressed: _editProfile,
                      tooltip: 'ویرایش اطلاعات',
                      icon: const Icon(
                        Icons.edit_outlined,
                        color: text,
                      ),
                    ),

                    IconButton(
                      onPressed: _logout,
                      tooltip: 'خروج',
                      icon: const Icon(
                        Icons.logout_rounded,
                        color: danger,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                _accountHeader(),

                const SizedBox(height: 18),

                _sectionTitle(
                  'اطلاعات حساب',
                  'اطلاعات واقعی حساب را ببین و از همین‌جا ویرایش کن.',
                ),

                _accountDetails(),

                const SizedBox(height: 18),

                _sectionTitle(
                  'وضعیت امروز',
                  'خلاصه‌ای از داده‌هایی که سی همین امروز ثبت کرده است.',
                ),

                _healthSnapshot(),

                const SizedBox(height: 18),

                _sectionTitle(
                  'سلامت شخصی',
                  'یک فضای کوچک برای بررسی وضعیت ذهنی روزانه.',
                ),

                _moodCard(),

                const SizedBox(height: 18),

                _sectionTitle(
                  'دسترسی سریع',
                  'ابزارهای اصلی را بدون تکرار و شلوغی در دسترس نگه داریم.',
                ),

                _quickActions(),

                const SizedBox(height: 20),

                OutlinedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(
                    Icons.logout_rounded,
                    color: danger,
                  ),
                  label: const Text(
                    'خروج از حساب',
                    style: TextStyle(
                      color: danger,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                      color: Color(0x33D95C5C),
                    ),
                    padding:
                    const EdgeInsets.symmetric(
                      vertical: 14,
                    ),
                    shape:
                    RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// PROFILE EDIT RESULT
// =============================================================================

class _ProfileEditResult {
  final String fullName;
  final String username;
  final String gender;

  // Always Gregorian YYYY-MM-DD for Supabase.
  final String birthDate;

  const _ProfileEditResult({
    required this.fullName,
    required this.username,
    required this.gender,
    required this.birthDate,
  });
}

// =============================================================================
// EDIT PROFILE DIALOG
// =============================================================================
//
// This is deliberately a separate StatefulWidget.
//
// The old implementation kept TextEditingControllers in the parent method.
// That made keyboard/focus/dialog lifecycle interactions much easier to break.
//
// This widget owns:
//   - its controllers
//   - its saving state
//   - its validation
//   - its keyboard handling
//   - its Android back-button handling
//
// The parent doesn't update until this widget has completely disappeared.
// =============================================================================

class _EditProfileDialog extends StatefulWidget {
  final String fullName;
  final String username;
  final String gender;
  final String birthDate;
  final SupabaseClient supabase;

  const _EditProfileDialog({
    required this.fullName,
    required this.username,
    required this.gender,
    required this.birthDate,
    required this.supabase,
  });

  @override
  State<_EditProfileDialog> createState() =>
      _EditProfileDialogState();
}

class _EditProfileDialogState
    extends State<_EditProfileDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _birthController;

  late String _selectedGender;

  bool _saving = false;

  @override
  void initState() {
    super.initState();

    _nameController =
        TextEditingController(
          text: widget.fullName,
        );

    _usernameController =
        TextEditingController(
          text: widget.username,
        );

    _birthController =
        TextEditingController(
          text: _formatBirthForEditing(
            widget.birthDate,
          ),
        );

    _selectedGender = widget.gender;
  }

  @override
  void dispose() {
    _tourScrollController.dispose();
    _nameController.dispose();
    _usernameController.dispose();
    _birthController.dispose();

    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // BIRTH DATE
  // ---------------------------------------------------------------------------

  String _formatBirthForEditing(String value) {
    if (value.trim().isEmpty) {
      return '';
    }

    try {
      final gregorian = DateTime.parse(value);
      final jalali = Jalali.fromDateTime(gregorian);

      return '${jalali.year}/'
          '${jalali.month.toString().padLeft(2, '0')}/'
          '${jalali.day.toString().padLeft(2, '0')}';
    } catch (_) {
      // Compatibility with old Shamsi records.
      return value.replaceAll('-', '/');
    }
  }

  String? _convertBirthToGregorian(
      String value,
      ) {
    final normalized =
    value.trim().replaceAll('-', '/');

    if (normalized.isEmpty) {
      return null;
    }

    final parts = normalized.split('/');

    if (parts.length != 3) {
      throw const FormatException(
        'invalid_birth_format',
      );
    }

    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);

    if (year == null ||
        month == null ||
        day == null) {
      throw const FormatException(
        'invalid_birth_format',
      );
    }

    late Jalali jalali;

    try {
      jalali = Jalali(
        year,
        month,
        day,
      );
    } on DateException {
      throw const FormatException(
        'invalid_birth_date',
      );
    } catch (_) {
      throw const FormatException(
        'invalid_birth_date',
      );
    }

    if (jalali > Jalali.now()) {
      throw const FormatException(
        'future_birth_date',
      );
    }

    final gregorian = jalali.toGregorian();

    return '${gregorian.year.toString().padLeft(4, '0')}-'
        '${gregorian.month.toString().padLeft(2, '0')}-'
        '${gregorian.day.toString().padLeft(2, '0')}';
  }

  // ---------------------------------------------------------------------------
  // MESSAGES
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

  // ---------------------------------------------------------------------------
  // BACK BUTTON
  // ---------------------------------------------------------------------------

  void _handleBack() {
    final focus = FocusManager.instance.primaryFocus;

    // If a TextField currently owns focus, Android's first back press
    // should ONLY dismiss the keyboard.
    //
    // Crucially, we do NOT pop the dialog here.
    if (focus != null && focus.hasFocus) {
      focus.unfocus();
      return;
    }

    // Keyboard is already closed.
    //
    // Now it is safe to close the dialog.
    Navigator.of(context).pop();
  }

  // ---------------------------------------------------------------------------
  // CLOSE BUTTON
  // ---------------------------------------------------------------------------

  void _close() {
    if (_saving) return;

    FocusManager.instance.primaryFocus?.unfocus();

    Navigator.of(context).pop();
  }

  // ---------------------------------------------------------------------------
  // SAVE
  // ---------------------------------------------------------------------------

  Future<void> _save() async {
    if (_saving) return;

    final user = widget.supabase.auth.currentUser;

    if (user == null) {
      return;
    }

    final fullName = _nameController.text.trim();
    final username = _usernameController.text.trim();
    final birthText = _birthController.text.trim();

    String? databaseBirthDate;

    // -------------------------------------------------------------------------
    // Validate birth date
    // -------------------------------------------------------------------------

    try {
      databaseBirthDate =
          _convertBirthToGregorian(birthText);
    } on FormatException catch (error) {
      switch (error.message) {
        case 'invalid_birth_format':
          _message(
            'تاریخ تولد را به صورت 1400/01/01 وارد کنید.',
          );
          return;

        case 'future_birth_date':
          _message(
            'تاریخ تولد نمی‌تواند در آینده باشد.',
          );
          return;

        default:
          _message('تاریخ تولد معتبر نیست.');
          return;
      }
    }

    setState(() {
      _saving = true;
    });

    try {
      await widget.supabase
          .from('users')
          .update({
        'full_name': fullName,
        'username': username,
        'gender': _selectedGender,
        'birth_date': databaseBirthDate,
        'last_active_at':
        DateTime.now().toIso8601String(),
      })
          .eq('id', user.id);

      if (!mounted) return;

      // Close the keyboard first.
      FocusManager.instance.primaryFocus?.unfocus();

      // Return the result to the parent.
      //
      // The parent will NOT update itself until showDialog()
      // has completed.
      Navigator.of(context).pop(
        _ProfileEditResult(
          fullName: fullName,
          username: username,
          gender: _selectedGender,
          birthDate: databaseBirthDate ?? '',
        ),
      );
    } catch (error) {
      debugPrint(
        '[Profile Edit] Save failed: $error',
      );

      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      _message(
        'ذخیره اطلاعات انجام نشد.',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        _handleBack();
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),

          // -------------------------------------------------------------------
          // TITLE + CLOSE BUTTON
          // -------------------------------------------------------------------

          titlePadding: const EdgeInsets.fromLTRB(
            20,
            18,
            12,
            0,
          ),

          title: Row(
            children: [
              const Expanded(
                child: Text(
                  'اطلاعات شخصی',
                  style: TextStyle(
                    color: Color(0xFF263B37),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),

              IconButton(
                tooltip: 'بستن',
                onPressed: _saving ? null : _close,
                icon: const Icon(
                  Icons.close_rounded,
                ),
              ),
            ],
          ),

          // -------------------------------------------------------------------
          // CONTENT
          // -------------------------------------------------------------------

          contentPadding:
          const EdgeInsets.fromLTRB(
            20,
            16,
            20,
            8,
          ),

          content: SingleChildScrollView(
            keyboardDismissBehavior:
            ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _nameController,
                  enabled: !_saving,
                  decoration:
                  const InputDecoration(
                    labelText:
                    'نام و نام خانوادگی',
                    prefixIcon:
                    Icon(Icons.badge_outlined),
                  ),
                ),

                const SizedBox(height: 12),

                TextField(
                  controller:
                  _usernameController,
                  enabled: !_saving,
                  decoration:
                  const InputDecoration(
                    labelText: 'نام کاربری',
                    prefixIcon: Icon(
                      Icons.alternate_email_rounded,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                TextField(
                  controller: _birthController,
                  enabled: !_saving,
                  keyboardType:
                  TextInputType.datetime,
                  textDirection:
                  TextDirection.ltr,
                  decoration:
                  const InputDecoration(
                    labelText: 'تاریخ تولد',
                    hintText: '1388/05/27',
                    prefixIcon:
                    Icon(Icons.cake_outlined),
                  ),
                ),

                const SizedBox(height: 6),

                const Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'تاریخ را به صورت شمسی وارد کنید.',
                    style: TextStyle(
                      color: Color(0xFF7D8D89),
                      fontSize: 10,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                DropdownButtonFormField<String>(
                  value: _selectedGender,
                  decoration:
                  const InputDecoration(
                    labelText: 'جنسیت',
                    prefixIcon:
                    Icon(Icons.wc_outlined),
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
                  onChanged: _saving
                      ? null
                      : (value) {
                    if (value == null) {
                      return;
                    }

                    setState(() {
                      _selectedGender =
                          value;
                    });
                  },
                ),
              ],
            ),
          ),

          // -------------------------------------------------------------------
          // ACTIONS
          // -------------------------------------------------------------------

          actionsPadding:
          const EdgeInsets.fromLTRB(
            20,
            8,
            20,
            18,
          ),

          actions: [
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor:
                  const Color(0xFF42D2A7),
                  foregroundColor: Colors.white,
                  minimumSize:
                  const Size.fromHeight(50),
                  shape:
                  RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.circular(15),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child:
                  CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Text(
                  'ذخیره تغییرات',
                  style: TextStyle(
                    fontWeight:
                    FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}