import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../backend/daily_health_metric.dart';
import '../backend/health_data_repository.dart';
import '../services/background_service.dart';
import 'exercise_center_page.dart';
import 'posture_analysis_page.dart';
import 'profile_page.dart';
import 'womens_health_page.dart';

class MainNavigationScreen extends StatefulWidget {
  final String userGender;
  const MainNavigationScreen({super.key, required this.userGender});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  static const green = Color(0xFF42D2A7);
  static const teal = Color(0xFF45C4D0);
  static const bg = Color(0xFFF4F9F7);
  static const text = Color(0xFF263B37);
  static const subtext = Color(0xFF7D8D89);

  int currentIndex = 0;
  late final List<Widget> pages;
  late final List<_NavItem> navItems;
  StreamSubscription<Map<String, dynamic>?>? statusSubscription;
  bool serviceAlive = false;
  DateTime? heartbeat;
  bool startingMonitoring = false;

  @override
  void initState() {
    super.initState();
    pages = [
      _DashboardHome(isMonitoringActive: () => _isMonitoringActive, onPosture: () => _goTo(1), onExercise: () => _goTo(2)),
      const PostureAnalysisPage(),
      const ExerciseCenterPage(),
    ];
    navItems = [
      const _NavItem(Icons.grid_view_rounded, 'سلامت'),
      const _NavItem(Icons.accessibility_new_rounded, 'بدن'),
      const _NavItem(Icons.fitness_center_rounded, 'ورزش'),
    ];
    if (widget.userGender == 'female') {
      pages.add(const WomensHealthPage());
      navItems.add(const _NavItem(Icons.favorite_rounded, 'بانوان'));
    }
    pages.add(const ProfilePage());
    navItems.add(const _NavItem(Icons.person_rounded, 'پروفایل'));
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureMonitoringPermission());
  }

  bool get _isMonitoringActive => serviceAlive && heartbeat != null && DateTime.now().difference(heartbeat!) < const Duration(seconds: 12);

  void _goTo(int index) => setState(() => currentIndex = index);

  Future<void> _ensureMonitoringPermission() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    if (prefs.getBool('has_agreed_privacy') != true) {
      _showPrivacyDialog(prefs);
    } else {
      await _startMonitoring();
    }
  }

  Future<void> _startMonitoring() async {
    if (startingMonitoring) return;
    startingMonitoring = true;
    try {
      final permissions = await [Permission.camera, Permission.notification].request();
      if (!permissions[Permission.camera]!.isGranted) {
        _message('برای پایش بدن، اجازه دوربین لازم است.', error: true);
        return;
      }
      if (!await FlutterOverlayWindow.isPermissionGranted()) {
        await FlutterOverlayWindow.requestPermission();
      }
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      final row = await Supabase.instance.client.from('users').select('hunch_divisor').eq('id', user.id).maybeSingle();
      final divisor = (row?['hunch_divisor'] as num?)?.toDouble();
      if (divisor == null || !divisor.isFinite || divisor <= 0) {
        _message('ابتدا کالیبراسیون وضعیت بدن را انجام دهید.', error: true);
        return;
      }
      await BackgroundMonitorService.saveHunchDivisor(divisor);
      final running = await BackgroundMonitorService.isRunning;
      await BackgroundMonitorService.initialize();
      if (!running) BackgroundMonitorService.start();
      _listenToService();
    } catch (e) {
      debugPrint('[Dashboard] monitoring error: $e');
      _message('فعال‌سازی پایش با خطا مواجه شد.', error: true);
    } finally {
      startingMonitoring = false;
    }
  }

  void _listenToService() {
    statusSubscription?.cancel();
    statusSubscription = BackgroundMonitorService.statusStream.listen((event) {
      if (!mounted || event == null) return;
      setState(() {
        serviceAlive = event['running'] == true;
        heartbeat = DateTime.now();
      });
    });
  }

  void _showPrivacyDialog(SharedPreferences prefs) {
    bool checked = false;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(builder: (_, setLocal) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('حریم خصوصی و پایش', style: TextStyle(color: text, fontWeight: FontWeight.w900)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('برای پایش وضعیت بدن، دوربین در پس‌زمینه استفاده می‌شود. پردازش وضعیت بدن روی دستگاه انجام می‌شود و تصویر خام برای این قابلیت ذخیره یا ارسال نمی‌شود.', style: TextStyle(color: subtext, fontSize: 13, height: 1.7)),
            const SizedBox(height: 14),
            CheckboxListTile(value: checked, onChanged: (v) => setLocal(() => checked = v ?? false), activeColor: green, contentPadding: EdgeInsets.zero, title: const Text('شرایط و دسترسی‌ها را می‌پذیرم.', style: TextStyle(fontSize: 12, color: text))),
          ]),
          actions: [SizedBox(width: double.infinity, child: FilledButton(onPressed: !checked ? null : () async { await prefs.setBool('has_agreed_privacy', true); if (!mounted) return; Navigator.pop(ctx); await _startMonitoring(); }, style: FilledButton.styleFrom(backgroundColor: green, padding: const EdgeInsets.symmetric(vertical: 14)), child: const Text('تأیید و ادامه')))],
        )),
      ),
    );
  }

  void _message(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(message), backgroundColor: error ? Colors.red.shade600 : green, behavior: SnackBarBehavior.floating));
  }

  @override
  void dispose() {
    statusSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Directionality(textDirection: TextDirection.rtl, child: Scaffold(
    backgroundColor: bg,
    body: SafeArea(child: IndexedStack(index: currentIndex, children: pages)),
    bottomNavigationBar: Container(
      color: bg,
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
      child: Container(
        height: 68,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), boxShadow: [BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 24, offset: const Offset(0, 7))]),
        child: Row(children: List.generate(navItems.length, (i) {
          final selected = i == currentIndex;
          return Expanded(child: InkWell(onTap: () => _goTo(i), child: AnimatedContainer(duration: const Duration(milliseconds: 180), margin: const EdgeInsets.all(6), decoration: BoxDecoration(color: selected ? green.withOpacity(.12) : Colors.transparent, borderRadius: BorderRadius.circular(17)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(navItems[i].icon, size: 21, color: selected ? green : subtext), const SizedBox(height: 3), Text(navItems[i].label, style: TextStyle(color: selected ? green : subtext, fontSize: 9, fontWeight: selected ? FontWeight.w900 : FontWeight.w600))]))));
        })),
      ),
    ),
  ));
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem(this.icon, this.label);
}

class _DashboardHome extends StatefulWidget {
  final bool Function() isMonitoringActive;
  final VoidCallback onPosture;
  final VoidCallback onExercise;
  const _DashboardHome({required this.isMonitoringActive, required this.onPosture, required this.onExercise});

  @override
  State<_DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<_DashboardHome> {
  static const green = Color(0xFF42D2A7);
  static const teal = Color(0xFF45C4D0);
  static const bg = Color(0xFFF4F9F7);
  static const text = Color(0xFF263B37);
  static const subtext = Color(0xFF7D8D89);
  static const line = Color(0xFFE8EFEC);
  static const mint = Color(0xFFE8F8F1);

  DailyHealthMetric? today;
  bool loading = true;
  int water = 0;
  String? mood;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rows = await HealthDataRepository.instance.getDailyMetrics(days: 1);
      if (!mounted) return;
      setState(() {
        today = rows.isEmpty ? null : DailyHealthMetric.fromMap(rows.first);
        water = prefs.getInt(_waterKey()) ?? 0;
        mood = prefs.getString(_moodKey());
        loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  String _waterKey() { final d = DateTime.now(); return 'si_water_${d.year}_${d.month}_${d.day}'; }
  String _moodKey() { final d = DateTime.now(); return 'si_mood_${d.year}_${d.month}_${d.day}'; }

  Future<void> _addWater() async {
    if (water >= 8) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_waterKey(), water + 1);
    if (mounted) setState(() => water++);
  }

  Future<void> _setMood(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_moodKey(), value);
    if (mounted) setState(() => mood = value);
  }

  double get risk => today == null ? 0 : today!.neck + today!.hunch + today!.wrist + today!.tooClose + today!.badLight;
  int get score => today?.healthScore ?? (risk == 0 ? 100 : (100 - risk * .8).clamp(0, 100).round());

  String _minutes(double value) {
    if (value < 1) return '${(value * 60).round()}ث';
    if (value < 60) return '${value.round()}د';
    final h = value ~/ 60;
    final m = value.round() % 60;
    return m == 0 ? '${h}س' : '${h}س ${m}د';
  }

  Widget _card({required Widget child, EdgeInsets padding = const EdgeInsets.all(16)}) => Container(padding: padding, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(21), border: Border.all(color: line), boxShadow: [BoxShadow(color: Colors.black.withOpacity(.03), blurRadius: 18, offset: const Offset(0, 6))]), child: child);

  Widget _metric(String title, String value, IconData icon, Color color) => Expanded(child: _card(padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 6), child: Column(children: [Icon(icon, color: color, size: 19), const SizedBox(height: 6), Text(value, style: const TextStyle(color: text, fontSize: 15, fontWeight: FontWeight.w900)), const SizedBox(height: 2), Text(title, textAlign: TextAlign.center, style: const TextStyle(color: subtext, fontSize: 9))])));

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(color: green, onRefresh: _load, child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(18, 12, 18, 28), children: [
      Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_greeting(), style: const TextStyle(color: subtext, fontSize: 11)), const SizedBox(height: 3), const Text('امروزت را بهتر مدیریت کن', style: TextStyle(color: text, fontSize: 22, fontWeight: FontWeight.w900))])), Container(width: 42, height: 42, decoration: const BoxDecoration(gradient: LinearGradient(colors: [green, teal]), shape: BoxShape.circle), child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 21))]),
      const SizedBox(height: 14),
      _monitorCard(),
      const SizedBox(height: 12),
      _overview(),
      const SizedBox(height: 12),
      Row(children: [_metric('گردن', _minutes(today?.neck ?? 0), Icons.accessibility_new_rounded, green), const SizedBox(width: 7), _metric('قوز', _minutes(today?.hunch ?? 0), Icons.airline_seat_recline_normal_rounded, teal), const SizedBox(width: 7), _metric('مچ', _minutes(today?.wrist ?? 0), Icons.back_hand_rounded, const Color(0xFFFFA62B))]),
      const SizedBox(height: 14),
      _dailySupport(),
      const SizedBox(height: 14),
      _quickActions(),
      const SizedBox(height: 14),
      _recommendation(),
    ]);
  }

  String _greeting() { final h = DateTime.now().hour; return h < 12 ? 'صبح بخیر 👋' : h < 18 ? 'روز بخیر 👋' : 'عصر بخیر 👋'; }

  Widget _monitorCard() {
    final active = widget.isMonitoringActive();
    return Container(padding: const EdgeInsets.all(17), decoration: BoxDecoration(gradient: LinearGradient(colors: active ? const [green, teal] : const [Color(0xFF9AA4AD), Color(0xFF6E7983)]), borderRadius: BorderRadius.circular(22)), child: Row(children: [Container(width: 44, height: 44, decoration: BoxDecoration(color: Colors.white.withOpacity(.18), shape: BoxShape.circle), child: Icon(active ? Icons.radar_rounded : Icons.radar_outlined, color: Colors.white)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(active ? 'پایش فعال است' : 'پایش فعال نیست', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(active ? 'سی در حال ثبت الگوهای سلامت توست.' : 'برای دریافت گزارش روزانه، پایش را فعال کن.', style: const TextStyle(color: Colors.white70, fontSize: 10))])), Container(width: 9, height: 9, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle))]));
  }

  Widget _overview() => _card(child: Row(children: [SizedBox(width: 88, height: 88, child: Stack(alignment: Alignment.center, children: [CircularProgressIndicator(value: score / 100, strokeWidth: 8, backgroundColor: mint, valueColor: const AlwaysStoppedAnimation(green)), Column(mainAxisSize: MainAxisSize.min, children: [Text('$score', style: const TextStyle(color: text, fontSize: 23, fontWeight: FontWeight.w900)), const Text('امتیاز', style: TextStyle(color: subtext, fontSize: 9))])])), const SizedBox(width: 15), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('تصویر کلی امروز', style: TextStyle(color: subtext, fontSize: 10)), const SizedBox(height: 4), Text(score >= 80 ? 'شرایط امروز خوب است' : score >= 60 ? 'چند مورد قابل اصلاح است' : 'امروز بیشتر به بدنت توجه کن', style: const TextStyle(color: text, fontSize: 15, fontWeight: FontWeight.w900)), const SizedBox(height: 5), Text(today == null ? 'با شروع پایش، داده‌های امروز اینجا جمع می‌شوند.' : 'خلاصه‌ای از داده‌های واقعی ثبت‌شده توسط پایش.', style: const TextStyle(color: subtext, fontSize: 10, height: 1.5))]))]));

  Widget _dailySupport() => Row(children: [Expanded(child: _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Row(children: [Icon(Icons.water_drop_rounded, color: teal, size: 18), SizedBox(width: 6), Text('آب امروز', style: TextStyle(color: text, fontSize: 12, fontWeight: FontWeight.w900))]), const SizedBox(height: 8), Text('$water/8 لیوان', style: const TextStyle(color: text, fontSize: 15, fontWeight: FontWeight.w900)), const SizedBox(height: 6), ClipRRect(borderRadius: BorderRadius.circular(5), child: LinearProgressIndicator(value: water / 8, minHeight: 5, backgroundColor: line, valueColor: const AlwaysStoppedAnimation(teal))), const SizedBox(height: 8), SizedBox(width: double.infinity, child: OutlinedButton(onPressed: water >= 8 ? null : _addWater, style: OutlinedButton.styleFrom(foregroundColor: teal, side: const BorderSide(color: teal)), child: const Text('+ یک لیوان', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800))))])), const SizedBox(width: 8), Expanded(child: _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Row(children: [Icon(Icons.psychology_alt_rounded, color: green, size: 18), SizedBox(width: 6), Text('حال امروز', style: TextStyle(color: text, fontSize: 12, fontWeight: FontWeight.w900))]), const SizedBox(height: 8), Text(mood == null ? 'هنوز ثبت نشده' : mood!, style: const TextStyle(color: text, fontSize: 13, fontWeight: FontWeight.w900)), const SizedBox(height: 7), Wrap(spacing: 3, children: ['😄', '🙂', '😐', '😮‍💨', '😕'].map((e) => InkWell(onTap: () => _setMood(e), child: Padding(padding: const EdgeInsets.all(3), child: Text(e, style: const TextStyle(fontSize: 16))))).toList())])))]);

  Widget _quickActions() => _card(child: Column(children: [_action(Icons.accessibility_new_rounded, 'تحلیل وضعیت بدن', 'جزئیات گردن، قوز، مچ و فاصله', widget.onPosture), const Divider(height: 20, color: line), _action(Icons.fitness_center_rounded, 'تمرین پیشنهادی', 'تمرین کوتاه متناسب با وضعیت امروز', widget.onExercise)]));

  Widget _action(IconData icon, String title, String subtitle, VoidCallback onTap) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(14), child: Row(children: [Container(width: 40, height: 40, decoration: const BoxDecoration(color: mint, shape: BoxShape.circle), child: Icon(icon, color: green, size: 20)), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: text, fontSize: 12, fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(subtitle, style: const TextStyle(color: subtext, fontSize: 9))])), const Icon(Icons.chevron_left_rounded, color: subtext)]));

  Widget _recommendation() {
    final d = today;
    String title = 'یک قدم کوچک برای سلامت';
    String body = 'اگر امروز هنوز داده‌ای نداریم، پایش را روشن کن تا پیشنهادها شخصی‌تر شوند.';
    if (d != null) {
      if (d.hunch >= d.neck && d.hunch >= d.wrist && d.hunch >= d.tooClose) { title = 'فرم نشستن را اصلاح کن'; body = 'قوز کردن بیشترین زمان نامناسب امروز را داشته است.'; }
      else if (d.tooClose >= d.neck && d.tooClose >= d.wrist) { title = 'کمی از صفحه فاصله بگیر'; body = 'فاصله نامناسب امروز بیشتر از سایر موارد بوده است.'; }
      else if (d.neck >= d.wrist) { title = 'به گردنت استراحت بده'; body = 'صفحه را بالاتر بیاور و هر چند دقیقه وضعیت شانه‌ها را رها کن.'; }
      else { title = 'به مچ‌ها استراحت بده'; body = 'یک وقفه کوتاه و کشش ملایم مچ‌ها انجام بده.'; }
    }
    return Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: mint, borderRadius: BorderRadius.circular(20)), child: Row(children: [const Icon(Icons.lightbulb_outline_rounded, color: green), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('پیشنهاد سی', style: TextStyle(color: subtext, fontSize: 9)), const SizedBox(height: 3), Text(title, style: const TextStyle(color: text, fontSize: 12, fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(body, style: const TextStyle(color: subtext, fontSize: 9, height: 1.5))]))]));
  }
}
