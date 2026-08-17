import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../backend/daily_health_metric.dart';
import '../backend/health_data_repository.dart';
import '../services/background_service.dart';
import 'calibration_screen.dart';
import 'exercise_center_page.dart';
import 'settings_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const bg = Color(0xFFF4F9F7), card = Colors.white, green = Color(0xFF42D2A7), teal = Color(0xFF45C4D0), text = Color(0xFF263B37), sub = Color(0xFF7D8D89), mint = Color(0xFFE8F8F1), line = Color(0xFFE8EFEC), danger = Color(0xFFD95C5C);
  final supabase = Supabase.instance.client;
  bool loading = true, saving = false;
  String fullName = '', username = '', gender = 'male', birthDate = '';
  DateTime? lastCalibratedAt;
  double hunchDivisor = 0;
  DailyHealthMetric? today;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) { if (mounted) setState(() => loading = false); return; }
      final results = await Future.wait<dynamic>([
        supabase.from('users').select().eq('id', user.id).maybeSingle(),
        HealthDataRepository.instance.getDailyMetrics(days: 1),
      ]);
      final data = results[0] as Map<String, dynamic>?;
      final rows = results[1] as List<Map<String, dynamic>>;
      if (!mounted) return;
      setState(() {
        fullName = _string(data?['full_name']);
        username = _string(data?['username']);
        gender = _string(data?['gender'], fallback: 'male');
        birthDate = _string(data?['birth_date']);
        hunchDivisor = _number(data?['hunch_divisor']);
        lastCalibratedAt = _date(data?['last_calibrated_at']);
        today = rows.isEmpty ? null : DailyHealthMetric.fromMap(rows.first);
        loading = false;
      });
    } catch (_) {
      if (mounted) { setState(() => loading = false); _message('اطلاعات حساب بارگذاری نشد.'); }
    }
  }

  String _string(dynamic v, {String fallback = ''}) { final s = v?.toString().trim(); return s == null || s.isEmpty ? fallback : s; }
  double _number(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
  DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());
  String get displayName => fullName.isNotEmpty ? fullName : (username.isNotEmpty ? username : 'کاربر سی');

  int get age {
    final p = birthDate.replaceAll('/', '-').split('-');
    if (p.length != 3) return 0;
    final y = int.tryParse(p[0]), m = int.tryParse(p[1]), d = int.tryParse(p[2]);
    if (y == null || m == null || d == null) return 0;
    final now = DateTime.now();
    var a = now.year - y;
    if (now.month < m || (now.month == m && now.day < d)) a--;
    return a < 0 ? 0 : a;
  }

  Future<void> _editProfile() async {
    final name = TextEditingController(text: fullName), userName = TextEditingController(text: username), birth = TextEditingController(text: birthDate);
    var selectedGender = gender;
    try {
      await showDialog<void>(context: context, builder: (dialogContext) => Directionality(textDirection: TextDirection.rtl, child: AlertDialog(
        backgroundColor: card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('اطلاعات شخصی', style: TextStyle(color: text, fontWeight: FontWeight.w900)),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'نام و نام خانوادگی', prefixIcon: Icon(Icons.badge_outlined))),
          const SizedBox(height: 12),
          TextField(controller: userName, decoration: const InputDecoration(labelText: 'نام کاربری', prefixIcon: Icon(Icons.alternate_email_rounded))),
          const SizedBox(height: 12),
          TextField(controller: birth, keyboardType: TextInputType.datetime, decoration: const InputDecoration(labelText: 'تاریخ تولد', hintText: '2009-08-17', prefixIcon: Icon(Icons.cake_outlined))),
          const SizedBox(height: 12),
          StatefulBuilder(builder: (_, setLocal) => DropdownButtonFormField<String>(initialValue: selectedGender, decoration: const InputDecoration(labelText: 'جنسیت', prefixIcon: Icon(Icons.wc_outlined)), items: const [DropdownMenuItem(value: 'male', child: Text('آقا')), DropdownMenuItem(value: 'female', child: Text('خانم'))], onChanged: (v) => setLocal(() => selectedGender = v ?? selectedGender))),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('انصراف')),
          FilledButton(onPressed: saving ? null : () async {
            final user = supabase.auth.currentUser;
            if (user == null) return;
            setState(() => saving = true);
            try {
              await supabase.from('users').update({'full_name': name.text.trim(), 'username': userName.text.trim(), 'gender': selectedGender, 'birth_date': birth.text.trim(), 'last_active_at': DateTime.now().toIso8601String()}).eq('id', user.id);
              if (!mounted) return;
              setState(() { fullName = name.text.trim(); username = userName.text.trim(); gender = selectedGender; birthDate = birth.text.trim(); saving = false; });
              Navigator.pop(dialogContext);
              _message('اطلاعات حساب ذخیره شد.');
            } catch (_) { if (mounted) { setState(() => saving = false); _message('ذخیره اطلاعات انجام نشد.'); } }
          }, style: FilledButton.styleFrom(backgroundColor: green), child: const Text('ذخیره تغییرات')),
        ],
      )));
    } finally { name.dispose(); userName.dispose(); birth.dispose(); }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => Directionality(textDirection: TextDirection.rtl, child: AlertDialog(title: const Text('خروج از حساب'), content: const Text('از حساب فعلی خارج می‌شوی و برای ورود دوباره به صفحه ورود منتقل می‌شوی.'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')), FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: danger), child: const Text('خروج'))])));
    if (confirmed != true) return;
    try { BackgroundMonitorService.stop(); if (await FlutterOverlayWindow.isActive()) await FlutterOverlayWindow.closeOverlay(); } catch (_) {}
    await supabase.auth.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  Future<void> _openCalibration() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) { _message('دوربین در دسترس نیست.'); return; }
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => CalibrationScreen(cameras: cameras)));
      if (mounted) await _load();
    } catch (_) { if (mounted) _message('باز کردن کالیبراسیون ممکن نشد.'); }
  }
  Future<void> _openSettings() => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()));
  Future<void> _openExercise() => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExerciseCenterPage()));
  void _message(String message) { if (!mounted) return; ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating)); }

  Widget _card({required Widget child, EdgeInsets padding = const EdgeInsets.all(18)}) => Container(padding: padding, decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(22), border: Border.all(color: line), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .035), blurRadius: 20, offset: const Offset(0, 7))]), child: child);
  Widget _sectionTitle(String title, String subtitle) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: text, fontSize: 16, fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: sub, fontSize: 11))]));

  Widget _accountHeader() => _card(padding: const EdgeInsets.all(20), child: Column(children: [
    Row(children: [Container(width: 60, height: 60, decoration: const BoxDecoration(gradient: LinearGradient(colors: [green, teal]), shape: BoxShape.circle), child: const Icon(Icons.person_rounded, color: Colors.white, size: 32)), const SizedBox(width: 13), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: text, fontSize: 19, fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(username.isEmpty ? 'پروفایل شخصی' : '@$username', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: sub, fontSize: 12))])), IconButton(onPressed: _editProfile, tooltip: 'ویرایش اطلاعات', icon: const Icon(Icons.edit_rounded, color: text))]),
    const SizedBox(height: 16), Container(height: 1, color: line), const SizedBox(height: 13),
    LayoutBuilder(builder: (_, c) {
      final compact = c.maxWidth < 330;
      return Row(children: [Expanded(child: _miniInfo(Icons.cake_outlined, age > 0 ? '$age سال' : 'ثبت نشده', 'سن', compact)), Container(width: 1, height: 34, color: line), Expanded(child: _miniInfo(Icons.wc_outlined, gender == 'female' ? 'خانم' : 'آقا', 'جنسیت', compact)), Container(width: 1, height: 34, color: line), Expanded(child: _miniInfo(Icons.tune_rounded, hunchDivisor > 0 ? 'فعال' : 'نیازمند', 'کالیبراسیون', compact))]);
    }),
  ]));

  Widget _miniInfo(IconData icon, String value, String label, bool compact) => Column(children: [Icon(icon, color: green, size: compact ? 17 : 19), const SizedBox(height: 5), Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: text, fontSize: compact ? 10 : 12, fontWeight: FontWeight.w800)), const SizedBox(height: 2), Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: sub, fontSize: compact ? 8 : 10))]);

  Widget _accountDetails() {
    final email = supabase.auth.currentUser?.email ?? 'ثبت نشده';
    final calibrated = lastCalibratedAt == null ? 'هنوز انجام نشده' : '${lastCalibratedAt!.year}/${lastCalibratedAt!.month.toString().padLeft(2, '0')}/${lastCalibratedAt!.day.toString().padLeft(2, '0')}';
    return _card(child: Column(children: [_detail(Icons.mail_outline_rounded, 'ایمیل حساب', email, editable: false), const Divider(height: 22, color: line), _detail(Icons.alternate_email_rounded, 'نام کاربری', username.isEmpty ? 'ثبت نشده' : username, onTap: _editProfile), const Divider(height: 22, color: line), _detail(Icons.cake_outlined, 'تاریخ تولد', birthDate.isEmpty ? 'ثبت نشده' : birthDate, onTap: _editProfile), const Divider(height: 22, color: line), _detail(Icons.verified_outlined, 'آخرین کالیبراسیون', calibrated, onTap: _openCalibration)]));
  }

  Widget _detail(IconData icon, String label, String value, {VoidCallback? onTap, bool editable = true}) => InkWell(onTap: editable ? onTap : null, borderRadius: BorderRadius.circular(14), child: Row(children: [Container(width: 40, height: 40, decoration: const BoxDecoration(color: mint, shape: BoxShape.circle), child: Icon(icon, color: green, size: 20)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: sub, fontSize: 10)), const SizedBox(height: 3), Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: text, fontSize: 13, fontWeight: FontWeight.w800))])), if (editable) const Icon(Icons.chevron_left_rounded, color: sub)]));

  Widget _healthSnapshot() {
    final score = today?.healthScore ?? 0, screen = today?.screenTime.round() ?? 0, posture = ((today?.hunch ?? 0) + (today?.neck ?? 0) + (today?.wrist ?? 0)).round();
    return LayoutBuilder(builder: (_, c) {
      final narrow = c.maxWidth < 390;
      final metrics = [_metric('امتیاز امروز', '$score', Icons.favorite_rounded), _metric('زمان صفحه', '${screen}د', Icons.phone_android_rounded), _metric('وضعیت بدن', '${posture}د', Icons.accessibility_new_rounded)];
      return narrow ? Column(children: [metrics[0], const SizedBox(height: 8), metrics[1], const SizedBox(height: 8), metrics[2]]) : Row(children: [Expanded(child: metrics[0]), const SizedBox(width: 8), Expanded(child: metrics[1]), const SizedBox(width: 8), Expanded(child: metrics[2])]);
    });
  }
  Widget _metric(String label, String value, IconData icon) => _card(padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 7), child: Column(children: [Icon(icon, color: green, size: 20), const SizedBox(height: 6), Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: text, fontSize: 16, fontWeight: FontWeight.w900)), const SizedBox(height: 2), Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(color: sub, fontSize: 9, fontWeight: FontWeight.w700))]));

  Widget _quickActions() => _card(child: Column(children: [_action(Icons.tune_rounded, 'کالیبراسیون وضعیت بدن', 'تنظیم دوباره آستانه تشخیص شخصی', _openCalibration), const Divider(height: 22, color: line), _action(Icons.fitness_center_rounded, 'مرکز تمرین', 'تمرین‌های کوتاه متناسب با هدف تو', _openExercise), const Divider(height: 22, color: line), _action(Icons.settings_outlined, 'تنظیمات پایش', 'دوربین، هشدارها و محافظت از محتوا', _openSettings)]));
  Widget _action(IconData icon, String title, String subtitle, VoidCallback onTap) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(15), child: Row(children: [Container(width: 42, height: 42, decoration: const BoxDecoration(color: mint, shape: BoxShape.circle), child: Icon(icon, color: green)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: text, fontSize: 13, fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: sub, fontSize: 10))])), const Icon(Icons.chevron_left_rounded, color: sub)]));

  @override
  Widget build(BuildContext context) => Directionality(textDirection: TextDirection.rtl, child: Scaffold(backgroundColor: bg, body: SafeArea(child: loading ? const Center(child: CircularProgressIndicator(color: green)) : RefreshIndicator(color: green, onRefresh: _load, child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(18, 10, 18, 30), children: [
    Row(children: [const Expanded(child: Text('پروفایل', style: TextStyle(color: text, fontSize: 23, fontWeight: FontWeight.w900)),), IconButton(onPressed: _editProfile, tooltip: 'ویرایش اطلاعات', icon: const Icon(Icons.edit_outlined, color: text)), IconButton(onPressed: _logout, tooltip: 'خروج', icon: const Icon(Icons.logout_rounded, color: danger))]),
    const SizedBox(height: 12), _accountHeader(), const SizedBox(height: 18),
    _sectionTitle('اطلاعات حساب', 'اطلاعات واقعی حساب را ببین و از همین‌جا ویرایش کن.'), _accountDetails(), const SizedBox(height: 18),
    _sectionTitle('وضعیت امروز', 'خلاصه‌ای از داده‌هایی که سی همین امروز ثبت کرده است.'), _healthSnapshot(), const SizedBox(height: 18),
    _sectionTitle('دسترسی سریع', 'ابزارهای اصلی را بدون تکرار و شلوغی در دسترس نگه داریم.'), _quickActions(),
  ]))));
}