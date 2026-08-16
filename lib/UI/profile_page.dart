import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../backend/daily_health_metric.dart';
import '../backend/health_data_repository.dart';
import 'calibration_screen.dart';
import 'exercise_center_page.dart';
import 'settings_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const kBg = Color(0xFFF4F9F7);
  static const kCard = Colors.white;
  static const kGreen = Color(0xFF42D2A7);
  static const kTeal = Color(0xFF45C4D0);
  static const kText = Color(0xFF263B37);
  static const kSubtext = Color(0xFF7D8D89);
  static const kMint = Color(0xFFE8F8F1);
  static const kLine = Color(0xFFE8EFEC);

  final _supabase = Supabase.instance.client;

  bool _loading = true;
  bool _saving = false;
  String _fullName = '';
  String _username = '';
  String _gender = 'male';
  String _birthDate = '';
  double _hunchDivisor = 0;
  DateTime? _lastCalibratedAt;
  int _waterCount = 0;
  String? _mood;
  DailyHealthMetric? _today;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final user = _supabase.auth.currentUser;
      final prefs = await SharedPreferences.getInstance();
      final waterKey = _waterKey(DateTime.now());
      final savedWater = prefs.getInt(waterKey) ?? 0;
      final savedMood = prefs.getString(_moodKey(DateTime.now()));

      if (user == null) {
        if (mounted) {
          setState(() {
            _waterCount = savedWater;
            _mood = savedMood;
            _loading = false;
          });
        }
        return;
      }

      final results = await Future.wait([
        _supabase.from('users').select().eq('id', user.id).maybeSingle(),
        HealthDataRepository.instance.getDailyMetrics(days: 1),
      ]);

      final data = results[0] as Map<String, dynamic>?;
      final daily = results[1] as List<Map<String, dynamic>>;

      if (!mounted) return;
      setState(() {
        _fullName = _readString(data?['full_name']);
        _username = _readString(data?['username']);
        _gender = _readString(data?['gender'], fallback: 'male');
        _birthDate = _readString(data?['birth_date']);
        _hunchDivisor = _readDouble(data?['hunch_divisor']);
        _lastCalibratedAt = _readDate(data?['last_calibrated_at']);
        _today = daily.isEmpty ? null : DailyHealthMetric.fromMap(daily.first);
        _waterCount = savedWater.clamp(0, 8);
        _mood = savedMood;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _message('اطلاعات پروفایل بارگذاری نشد.');
    }
  }

  String _waterKey(DateTime date) => 'si_water_${date.year}_${date.month}_${date.day}';
  String _moodKey(DateTime date) => 'si_mood_${date.year}_${date.month}_${date.day}';

  String _readString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final v = value.toString().trim();
    return v.isEmpty ? fallback : v;
  }

  double _readDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  DateTime? _readDate(dynamic value) {
    if (value is DateTime) return value;
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  int _age() {
    final parts = _birthDate.replaceAll('/', '-').split('-');
    if (parts.length != 3) return 0;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return 0;
    final now = DateTime.now();
    var age = now.year - year;
    if (now.month < month || (now.month == month && now.day < day)) age--;
    return age < 0 ? 0 : age;
  }

  Future<void> _saveMood(String mood) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_moodKey(DateTime.now()), mood);
    if (!mounted) return;
    setState(() => _mood = mood);
    _message('حال امروزت ذخیره شد.');
  }

  Future<void> _changeWater(int delta) async {
    final next = (_waterCount + delta).clamp(0, 8);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_waterKey(DateTime.now()), next);
    if (!mounted) return;
    setState(() => _waterCount = next);
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsPage()),
    );
  }

  Future<void> _openCalibration() async {
    try {
      final cameras = await availableCameras();
      if (!mounted || cameras.isEmpty) {
        _message('دوربین در دسترس نیست.');
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CalibrationScreen(cameras: cameras),
        ),
      );
      await _load();
    } catch (_) {
      _message('باز کردن صفحه کالیبراسیون ممکن نشد.');
    }
  }

  Future<void> _openExercise() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ExerciseCenterPage()),
    );
  }

  Future<void> _editProfile() async {
    final name = TextEditingController(text: _fullName);
    final username = TextEditingController(text: _username);
    final birth = TextEditingController(text: _birthDate);
    var gender = _gender;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('ویرایش اطلاعات'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'نام و نام خانوادگی')),
                const SizedBox(height: 12),
                TextField(controller: username, decoration: const InputDecoration(labelText: 'نام کاربری')),
                const SizedBox(height: 12),
                TextField(controller: birth, decoration: const InputDecoration(labelText: 'تاریخ تولد', hintText: '2009-08-17')),
                const SizedBox(height: 12),
                StatefulBuilder(
                  builder: (_, setLocal) => DropdownButtonFormField<String>(
                    value: gender,
                    decoration: const InputDecoration(labelText: 'جنسیت'),
                    items: const [
                      DropdownMenuItem(value: 'male', child: Text('آقا')),
                      DropdownMenuItem(value: 'female', child: Text('خانم')),
                    ],
                    onChanged: (v) => setLocal(() => gender = v ?? gender),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('انصراف')),
            FilledButton(
              onPressed: _saving
                  ? null
                  : () async {
                      final user = _supabase.auth.currentUser;
                      if (user == null) return;
                      setState(() => _saving = true);
                      try {
                        await _supabase.from('users').update({
                          'full_name': name.text.trim(),
                          'username': username.text.trim(),
                          'gender': gender,
                          'birth_date': birth.text.trim(),
                          'last_active_at': DateTime.now().toIso8601String(),
                        }).eq('id', user.id);
                        if (!mounted) return;
                        Navigator.pop(dialogContext);
                        setState(() {
                          _fullName = name.text.trim();
                          _username = username.text.trim();
                          _gender = gender;
                          _birthDate = birth.text.trim();
                        });
                        _message('اطلاعات با موفقیت ذخیره شد.');
                      } catch (_) {
                        if (mounted) _message('ذخیره اطلاعات انجام نشد.');
                      } finally {
                        if (mounted) setState(() => _saving = false);
                      }
                    },
              style: FilledButton.styleFrom(backgroundColor: kGreen),
              child: const Text('ذخیره'),
            ),
          ],
        ),
      ),
    );

    name.dispose();
    username.dispose();
    birth.dispose();
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));
  }

  Widget _card({required Widget child, EdgeInsets padding = const EdgeInsets.all(18)}) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(.045), blurRadius: 24, offset: const Offset(0, 8))],
        ),
        child: child,
      );

  Widget _iconButton(IconData icon, VoidCallback onTap) => Material(
        color: kCard,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: const Padding(
            padding: EdgeInsets.all(11),
            child: Icon(Icons.settings_outlined, color: kText, size: 20),
          ),
        ),
      );

  Widget _profileCard() {
    final displayName = _fullName.isNotEmpty ? _fullName : (_username.isNotEmpty ? _username : 'کاربر سی');
    final age = _age();
    return _card(
      child: Row(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [kGreen, kTeal]),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(Icons.person_rounded, color: Colors.white, size: 36),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayName, style: const TextStyle(color: kText, fontSize: 19, fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                Text(
                  [_username.isEmpty ? null : '@$_username', age == 0 ? null : '$age سال', _gender == 'female' ? 'خانم' : 'آقا']
                      .whereType<String>()
                      .join('  •  '),
                  style: const TextStyle(color: kSubtext, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(onPressed: _editProfile, icon: const Icon(Icons.edit_outlined, color: kText)),
        ],
      ),
    );
  }

  Widget _healthSnapshot() {
    final score = _today?.healthScore ?? 0;
    final screen = _today?.screenTime.round() ?? 0;
    final posture = ((_today?.hunch ?? 0) + (_today?.neck ?? 0) + (_today?.wrist ?? 0)).round();
    return Row(
      children: [
        Expanded(child: _stat('امتیاز امروز', score.toString(), Icons.favorite_rounded)),
        const SizedBox(width: 10),
        Expanded(child: _stat('زمان صفحه', '${screen}د', Icons.phone_android_rounded)),
        const SizedBox(width: 10),
        Expanded(child: _stat('وضعیت بدن', '${posture}د', Icons.accessibility_new_rounded)),
      ],
    );
  }

  Widget _stat(String label, String value, IconData icon) => _card(
        padding: const EdgeInsets.fromLTRB(10, 14, 10, 14),
        child: Column(
          children: [
            Icon(icon, color: kGreen, size: 22),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(color: kText, fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(color: kSubtext, fontSize: 10, fontWeight: FontWeight.w600)),
          ],
        ),
      );

  Widget _waterCard() {
    final percent = _waterCount / 8;
    return _card(
      child: Column(
        children: [
          Row(
            children: [
              Container(width: 46, height: 46, decoration: const BoxDecoration(color: Color(0xFFEAF8FC), shape: BoxShape.circle), child: const Icon(Icons.water_drop_rounded, color: kTeal)),
              const SizedBox(width: 12),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('یادآوری آب', style: TextStyle(color: kText, fontSize: 14, fontWeight: FontWeight.w800)), SizedBox(height: 4), Text('هدف ساده امروز: ۸ لیوان', style: TextStyle(color: kSubtext, fontSize: 11))])),
              Text('$_waterCount/8', style: const TextStyle(color: kTeal, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(minHeight: 8, value: percent, backgroundColor: kLine, valueColor: const AlwaysStoppedAnimation(kTeal))),
          const SizedBox(height: 12),
          Row(children: [
            OutlinedButton(onPressed: _waterCount == 0 ? null : () => _changeWater(-1), child: const Icon(Icons.remove_rounded)),
            const Spacer(),
            Text(_waterCount >= 8 ? 'هدف امروز کامل شد 🎉' : 'هر بار یک لیوان ثبت کن', style: const TextStyle(color: kSubtext, fontSize: 11, fontWeight: FontWeight.w600)),
            const Spacer(),
            FilledButton(onPressed: _waterCount >= 8 ? null : () => _changeWater(1), style: FilledButton.styleFrom(backgroundColor: kTeal), child: const Icon(Icons.add_rounded)),
          ]),
        ],
      ),
    );
  }

  Widget _moodCard() {
    const moods = {'خیلی خوب': '😄', 'خوب': '🙂', 'معمولی': '😐', 'خسته': '😮‍💨', 'بد': '😕'};
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [Icon(Icons.psychology_alt_rounded, color: kGreen), SizedBox(width: 8), Text('حال امروز', style: TextStyle(color: kText, fontSize: 14, fontWeight: FontWeight.w800))]),
          const SizedBox(height: 6),
          const Text('یک ثبت کوتاه کمک می‌کند پیشنهادهای سلامت شخصی‌تر شوند.', style: TextStyle(color: kSubtext, fontSize: 11, height: 1.5)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: moods.entries.map((entry) {
              final selected = _mood == entry.key;
              return ChoiceChip(
                selected: selected,
                label: Text('${entry.value} ${entry.key}'),
                onSelected: (_) => _saveMood(entry.key),
                selectedColor: kMint,
                side: BorderSide(color: selected ? kGreen : kLine),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _actionCard() => _card(
        child: Column(
          children: [
            _action(Icons.tune_rounded, 'کالیبراسیون وضعیت بدن', _hunchDivisor > 0 ? 'آخرین تنظیم: ${_lastCalibratedAt == null ? 'ثبت شده' : 'فعال'}' : 'هنوز انجام نشده', _openCalibration),
            const Divider(height: 22, color: kLine),
            _action(Icons.fitness_center_rounded, 'مرکز تمرین', 'تمرین متناسب با وضعیت امروزت', _openExercise),
            const Divider(height: 22, color: kLine),
            _action(Icons.settings_outlined, 'تنظیمات و پایش', 'مدیریت پایش بدن و محافظت از محتوا', _openSettings),
          ],
        ),
      );

  Widget _action(IconData icon, String title, String subtitle, VoidCallback onTap) => InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Container(width: 44, height: 44, decoration: const BoxDecoration(color: kMint, shape: BoxShape.circle), child: Icon(icon, color: kGreen)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: kText, fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text(subtitle, style: const TextStyle(color: kSubtext, fontSize: 11))])),
              const Icon(Icons.chevron_left_rounded, color: kSubtext),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: kBg,
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: kGreen))
              : RefreshIndicator(
                  color: kGreen,
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                    children: [
                      Row(children: [
                        _iconButton(Icons.settings_outlined, _openSettings),
                        const Spacer(),
                        const Text('پروفایل', style: TextStyle(color: kText, fontSize: 21, fontWeight: FontWeight.w900)),
                        const Spacer(),
                        const SizedBox(width: 44),
                      ]),
                      const SizedBox(height: 14),
                      _profileCard(),
                      const SizedBox(height: 14),
                      _healthSnapshot(),
                      const SizedBox(height: 20),
                      const Text('مراقبت روزانه', style: TextStyle(color: kText, fontSize: 17, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 10),
                      _waterCard(),
                      const SizedBox(height: 10),
                      _moodCard(),
                      const SizedBox(height: 20),
                      const Text('دسترسی سریع', style: TextStyle(color: kText, fontSize: 17, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 10),
                      _actionCard(),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
