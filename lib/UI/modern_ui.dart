import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../backend/daily_health_metric.dart';
import '../backend/health_data_repository.dart';
import '../services/background_service.dart';
import '../backend/nsfw_detection.dart';
import 'calibration_screen.dart';
import 'exercise_center_page.dart';
import 'posture_analysis_page.dart';

class SiTheme {
  static const green = Color(0xFF42D2A7);
  static const teal = Color(0xFF45C4D0);
  static const dark = Color(0xFF183D39);
  static const text = Color(0xFF263B37);
  static const subtext = Color(0xFF7D8D89);
  static const bg = Color(0xFFF4F9F7);
  static const card = Colors.white;
  static const mint = Color(0xFFE8F8F1);
  static const line = Color(0xFFE8EFEC);

  static ThemeData theme() => ThemeData(
        fontFamily: 'Vazirmatn',
        scaffoldBackgroundColor: bg,
        colorScheme: ColorScheme.fromSeed(seedColor: green),
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          prefixIconColor: green,
          hintStyle: const TextStyle(color: subtext),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: green, width: 1.5),
          ),
        ),
      );
}

class SiCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  const SiCard({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.onTap});

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: SiTheme.card,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(.045), blurRadius: 26, offset: const Offset(0, 9)),
        ],
      ),
      child: child,
    );
    return onTap == null ? content : InkWell(borderRadius: BorderRadius.circular(26), onTap: onTap, child: content);
  }
}

class SiSectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const SiSectionTitle(this.title, {super.key, this.action, this.onAction});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Text(title, style: const TextStyle(color: SiTheme.text, fontSize: 17, fontWeight: FontWeight.w800)),
          const Spacer(),
          if (action != null)
            TextButton(onPressed: onAction, child: Text(action!, style: const TextStyle(color: SiTheme.green, fontWeight: FontWeight.w700))),
        ],
      );
}

class SiIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const SiIconButton({super.key, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 0,
        child: InkWell(onTap: onTap, customBorder: const CircleBorder(), child: Padding(padding: const EdgeInsets.all(11), child: Icon(icon, color: SiTheme.text, size: 21))),
      );
}

class ModernOnboardingPage extends StatefulWidget {
  const ModernOnboardingPage({super.key});
  @override
  State<ModernOnboardingPage> createState() => _ModernOnboardingPageState();
}

class _ModernOnboardingPageState extends State<ModernOnboardingPage> {
  final controller = PageController();
  int index = 0;
  final pages = const [
    ('سلامت چشم', 'با یادآوری‌های هوشمند، فاصله از صفحه و استراحت چشم را بهتر مدیریت کن.', 'assets/eyeComfort.png', Icons.visibility_rounded),
    ('وضعیت بدن', 'گردن، کمر، مچ دست و فاصله از گوشی را در طول روز زیر نظر داشته باش.', 'assets/backPosture.png', Icons.accessibility_new_rounded),
    ('بینش روزانه', 'داده‌های پایش به گزارش‌های ساده و قابل‌فهم تبدیل می‌شوند تا بدانی امروز چه چیزی را بهتر کنی.', 'assets/history.gif', Icons.insights_rounded),
    ('سلامت کامل‌تر', 'در کنار وضعیت بدن، آب، حال روحی و عادت‌های روزانه‌ات را هم در یک داشبورد دنبال کن.', 'assets/meditate.png', Icons.spa_rounded),
  ];

  @override
  void dispose() { controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
                  child: Row(children: [
                    Image.asset('assets/logo.png', width: 42, height: 42),
                    const Spacer(),
                    if (index < pages.length - 1) TextButton(onPressed: () => Navigator.pushReplacementNamed(context, '/signup'), child: const Text('رد کردن')),
                  ]),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: controller,
                    itemCount: pages.length,
                    onPageChanged: (v) => setState(() => index = v),
                    itemBuilder: (_, i) {
                      final p = pages[i];
                      return Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Expanded(flex: 6, child: Container(margin: const EdgeInsets.only(top: 12), decoration: BoxDecoration(color: SiTheme.mint, borderRadius: BorderRadius.circular(34)), child: Stack(alignment: Alignment.center, children: [Padding(padding: const EdgeInsets.all(24), child: Image.asset(p.$3, fit: BoxFit.contain)), Positioned(top: 18, right: 18, child: Container(padding: const EdgeInsets.all(12), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: Icon(p.$4, color: SiTheme.green)))]))),
                            const SizedBox(height: 18),
                            Expanded(flex: 4, child: SiCard(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(p.$1, style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900, color: SiTheme.text)), const SizedBox(height: 12), Text(p.$2, style: const TextStyle(fontSize: 14, height: 1.8, color: SiTheme.subtext)), const Spacer(), Row(children: List.generate(pages.length, (d) => AnimatedContainer(duration: const Duration(milliseconds: 250), margin: const EdgeInsets.only(left: 6), width: d == index ? 28 : 8, height: 8, decoration: BoxDecoration(color: d == index ? SiTheme.green : SiTheme.line, borderRadius: BorderRadius.circular(10)))),]))),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Padding(padding: const EdgeInsets.fromLTRB(24, 0, 24, 18), child: SizedBox(width: double.infinity, height: 58, child: ElevatedButton(onPressed: () { if (index == pages.length - 1) { Navigator.pushReplacementNamed(context, '/signup'); } else { controller.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeOut); } }, style: ElevatedButton.styleFrom(backgroundColor: SiTheme.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(19))), child: Text(index == pages.length - 1 ? 'شروع کنید' : 'ادامه', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))))),
              ],
            ),
          ),
        ),
      );
}

class ModernLoginPage extends StatefulWidget {
  const ModernLoginPage({super.key});
  @override
  State<ModernLoginPage> createState() => _ModernLoginPageState();
}

class _ModernLoginPageState extends State<ModernLoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool loading = false;
  bool obscure = true;

  @override
  void dispose() { email.dispose(); password.dispose(); super.dispose(); }

  Future<void> login() async {
    if (email.text.trim().isEmpty || password.text.isEmpty) { _message('ایمیل و رمز عبور را وارد کن.'); return; }
    setState(() => loading = true);
    try {
      final res = await Supabase.instance.client.auth.signInWithPassword(email: email.text.trim(), password: password.text);
      if (res.user == null) throw Exception();
      final data = await Supabase.instance.client.from('users').select('gender,hunch_divisor').eq('id', res.user!.id).maybeSingle();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, data?['hunch_divisor'] == null ? '/calibrate' : '/dashboard', arguments: data?['gender'] ?? 'male');
    } on AuthException catch (e) { _message(e.message); } catch (_) { _message('ورود انجام نشد. اطلاعات حساب را بررسی کن.'); } finally { if (mounted) setState(() => loading = false); }
  }

  void _message(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));

  @override
  Widget build(BuildContext context) => Directionality(textDirection: TextDirection.rtl, child: Scaffold(body: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Container(height: 110, decoration: BoxDecoration(color: SiTheme.mint, borderRadius: BorderRadius.circular(30)), child: Center(child: Image.asset('assets/logo.png', width: 78))),
    const SizedBox(height: 26), const Text('خوش برگشتی 👋', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: SiTheme.text)), const SizedBox(height: 7), const Text('برای دیدن وضعیت امروزت وارد حساب شو.', style: TextStyle(color: SiTheme.subtext)), const SizedBox(height: 28),
    SiCard(child: Column(children: [TextField(controller: email, keyboardType: TextInputType.emailAddress, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'ایمیل', prefixIcon: Icon(Icons.mail_outline))), const SizedBox(height: 14), TextField(controller: password, obscureText: obscure, textDirection: TextDirection.ltr, decoration: InputDecoration(labelText: 'رمز عبور', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(onPressed: () => setState(() => obscure = !obscure), icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined)))), const SizedBox(height: 22), SizedBox(width: double.infinity, height: 54, child: ElevatedButton(onPressed: loading ? null : login, style: ElevatedButton.styleFrom(backgroundColor: SiTheme.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17))), child: loading ? const CircularProgressIndicator(color: Colors.white) : const Text('ورود', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16))))])),
    const SizedBox(height: 18), Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Text('حساب نداری؟ '), TextButton(onPressed: () => Navigator.pushReplacementNamed(context, '/signup'), child: const Text('ثبت‌نام کن'))]),
  ])))))));
}

class ModernSignupPage extends StatefulWidget {
  const ModernSignupPage({super.key});
  @override
  State<ModernSignupPage> createState() => _ModernSignupPageState();
}

class _ModernSignupPageState extends State<ModernSignupPage> {
  final username = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final year = TextEditingController();
  String? day;
  String? month;
  String? gender;
  bool loading = false;
  final months = const ['01','02','03','04','05','06','07','08','09','10','11','12'];

  @override
  void dispose() { username.dispose(); email.dispose(); password.dispose(); year.dispose(); super.dispose(); }

  Future<void> signup() async {
    if (username.text.trim().isEmpty || email.text.trim().isEmpty || password.text.isEmpty || day == null || month == null || year.text.trim().isEmpty || gender == null) { _message('همه اطلاعات را کامل کن.'); return; }
    setState(() => loading = true);
    try {
      final res = await Supabase.instance.client.auth.signUp(email: email.text.trim(), password: password.text);
      final user = res.user;
      if (user == null) throw Exception('no-user');
      await Supabase.instance.client.from('users').insert({'id': user.id, 'username': username.text.trim(), 'gender': gender, 'birth_date': '${year.text.trim()}-$month-$day'});
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/calibrate');
    } on AuthException catch (e) { _message(e.message); } catch (_) { _message('ثبت‌نام انجام نشد. ممکن است این ایمیل قبلاً استفاده شده باشد.'); } finally { if (mounted) setState(() => loading = false); }
  }

  void _message(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));
  InputDecoration dec(String label, IconData icon) => InputDecoration(labelText: label, prefixIcon: Icon(icon));

  @override
  Widget build(BuildContext context) => Directionality(textDirection: TextDirection.rtl, child: Scaffold(body: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Row(children: [SiIconButton(icon: Icons.arrow_forward_rounded, onTap: () => Navigator.maybePop(context)), const Spacer(), Image.asset('assets/logo.png', width: 44), const Spacer(), const SizedBox(width: 44)]),
    const SizedBox(height: 22), const Text('حساب خودت را بساز', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: SiTheme.text)), const SizedBox(height: 7), const Text('چند اطلاعات ساده برای شخصی‌سازی تجربه سی.', style: TextStyle(color: SiTheme.subtext)), const SizedBox(height: 24),
    SiCard(child: Column(children: [TextField(controller: username, decoration: dec('نام کاربری', Icons.person_outline)), const SizedBox(height: 13), TextField(controller: email, keyboardType: TextInputType.emailAddress, textDirection: TextDirection.ltr, decoration: dec('ایمیل', Icons.mail_outline)), const SizedBox(height: 13), TextField(controller: password, obscureText: true, textDirection: TextDirection.ltr, decoration: dec('رمز عبور', Icons.lock_outline)), const SizedBox(height: 13),
      Row(children: [Expanded(child: DropdownButtonFormField<String>(value: day, decoration: dec('روز', Icons.calendar_today_outlined), items: List.generate(31, (i) => '${i+1}').map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setState(() => day = v))), const SizedBox(width: 9), Expanded(child: DropdownButtonFormField<String>(value: month, decoration: dec('ماه', Icons.date_range_outlined), items: months.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setState(() => month = v))), const SizedBox(width: 9), Expanded(child: TextField(controller: year, keyboardType: TextInputType.number, decoration: dec('سال', Icons.event_outlined))) ]), const SizedBox(height: 13),
      DropdownButtonFormField<String>(value: gender, decoration: dec('جنسیت', Icons.wc_outlined), items: const [DropdownMenuItem(value: 'male', child: Text('آقا')), DropdownMenuItem(value: 'female', child: Text('خانم'))], onChanged: (v) => setState(() => gender = v)), const SizedBox(height: 22), SizedBox(width: double.infinity, height: 54, child: ElevatedButton(onPressed: loading ? null : signup, style: ElevatedButton.styleFrom(backgroundColor: SiTheme.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17))), child: loading ? const CircularProgressIndicator(color: Colors.white) : const Text('ساخت حساب و ادامه', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16))))])),
    const SizedBox(height: 16), Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Text('قبلاً حساب داری؟ '), TextButton(onPressed: () => Navigator.pushReplacementNamed(context, '/login'), child: const Text('ورود'))]),
  ]))));
}

class ModernDashboardPage extends StatefulWidget {
  final String gender;
  final List<CameraDescription> cameras;
  const ModernDashboardPage({super.key, required this.gender, required this.cameras});
  @override
  State<ModernDashboardPage> createState() => _ModernDashboardPageState();
}

class _ModernDashboardPageState extends State<ModernDashboardPage> {
  int selected = 0;
  bool loading = true;
  List<DailyHealthMetric> metrics = [];
  int water = 0;
  int? mood;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = await HealthDataRepository.instance.getDailyMetrics(days: 7);
    final parsed = raw.map((e) => DailyHealthMetric.fromMap(e)).toList();
    if (!mounted) return;
    setState(() { metrics = parsed; water = prefs.getInt('si_water_${DateTime.now().toIso8601String().substring(0,10)}') ?? 0; mood = prefs.getInt('si_mood_${DateTime.now().toIso8601String().substring(0,10)}'); loading = false; });
  }

  Future<void> addWater() async { final prefs = await SharedPreferences.getInstance(); final key = 'si_water_${DateTime.now().toIso8601String().substring(0,10)}'; final next = (water + 1).clamp(0, 12); await prefs.setInt(key, next); if (mounted) setState(() => water = next); }
  Future<void> setMood(int value) async { final prefs = await SharedPreferences.getInstance(); final key = 'si_mood_${DateTime.now().toIso8601String().substring(0,10)}'; await prefs.setInt(key, value); if (mounted) setState(() => mood = value); }

  void openProfile() => setState(() => selected = 3);

  @override
  Widget build(BuildContext context) {
    final pages = [
      _home(),
      const PostureAnalysisPage(),
      const ExerciseCenterPage(),
      ModernProfilePage(cameras: widget.cameras),
    ];
    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(body: SafeArea(child: IndexedStack(index: selected, children: pages)), bottomNavigationBar: NavigationBar(selectedIndex: selected, onDestinationSelected: (v) => setState(() => selected = v), backgroundColor: Colors.white, indicatorColor: SiTheme.mint, destinations: const [NavigationDestination(icon: Icon(Icons.grid_view_rounded), label: 'امروز'), NavigationDestination(icon: Icon(Icons.accessibility_new_rounded), label: 'بدن'), NavigationDestination(icon: Icon(Icons.fitness_center_rounded), label: 'ورزش'), NavigationDestination(icon: Icon(Icons.person_rounded), label: 'پروفایل')])));
  }

  Widget _home() {
    final latest = metrics.isNotEmpty ? metrics.first : null;
    final score = latest?.healthScore ?? 0;
    return RefreshIndicator(onRefresh: load, child: ListView(padding: const EdgeInsets.fromLTRB(20, 14, 20, 30), children: [
      Row(children: [Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('امروزت چطور می‌گذره؟', style: TextStyle(color: SiTheme.subtext, fontSize: 13)), const SizedBox(height: 4), const Text('داشبورد سلامت', style: TextStyle(color: SiTheme.text, fontSize: 25, fontWeight: FontWeight.w900))]), const Spacer(), SiIconButton(icon: Icons.person_outline_rounded, onTap: openProfile)]),
      const SizedBox(height: 18),
      SiCard(child: Row(children: [Container(width: 72, height: 72, decoration: const BoxDecoration(color: SiTheme.mint, shape: BoxShape.circle), child: Center(child: Text('$score', style: const TextStyle(color: SiTheme.green, fontSize: 24, fontWeight: FontWeight.w900)))), const SizedBox(width: 16), const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('امتیاز سلامت امروز', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: SiTheme.text)), SizedBox(height: 6), Text('از داده‌های پایش روزانه برای یک تصویر کلی استفاده می‌کنیم.', style: TextStyle(fontSize: 12, color: SiTheme.subtext, height: 1.6))])), IconButton(onPressed: load, icon: const Icon(Icons.refresh_rounded, color: SiTheme.green))])),
      const SizedBox(height: 20), SiSectionTitle('پایش امروز', action: 'جزئیات', onAction: () => setState(() => selected = 1)), const SizedBox(height: 9),
      Row(children: [_metric('گردن', latest?.neck ?? 0, Icons.accessibility_new_rounded), const SizedBox(width: 10), _metric('قوز', latest?.hunch ?? 0, Icons.airline_seat_recline_normal_rounded), const SizedBox(width: 10), _metric('فاصله', latest?.tooClose ?? 0, Icons.remove_red_eye_outlined)]),
      const SizedBox(height: 20), SiSectionTitle('سلامت روزمره'), const SizedBox(height: 9), Row(children: [Expanded(child: _waterCard()), const SizedBox(width: 10), Expanded(child: _moodCard())]),
      const SizedBox(height: 20), SiSectionTitle('پیشنهاد سی'), const SizedBox(height: 9), SiCard(child: Row(children: [Container(width: 46, height: 46, decoration: const BoxDecoration(color: SiTheme.mint, shape: BoxShape.circle), child: const Icon(Icons.tips_and_updates_outlined, color: SiTheme.green)), const SizedBox(width: 12), const Expanded(child: Text('اگر مدت زیادی نشسته‌ای، یک وقفه کوتاه بگیر و چند حرکت کششی ساده انجام بده.', style: TextStyle(color: SiTheme.text, height: 1.7, fontSize: 13, fontWeight: FontWeight.w600))), const Icon(Icons.chevron_left_rounded, color: SiTheme.subtext)])),
    ]));
  }

  Widget _metric(String label, double value, IconData icon) => Expanded(child: SiCard(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: SiTheme.green), const SizedBox(height: 10), Text(label, style: const TextStyle(color: SiTheme.subtext, fontSize: 11)), const SizedBox(height: 4), Text('${value.toStringAsFixed(0)} دقیقه', style: const TextStyle(color: SiTheme.text, fontSize: 13, fontWeight: FontWeight.w800))])));
  Widget _waterCard() => SiCard(padding: const EdgeInsets.all(15), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.water_drop_outlined, color: SiTheme.teal), const SizedBox(height: 8), const Text('آب امروز', style: TextStyle(fontWeight: FontWeight.w800, color: SiTheme.text)), const SizedBox(height: 3), Text('$water از ۸ لیوان', style: const TextStyle(color: SiTheme.subtext, fontSize: 11)), const SizedBox(height: 8), LinearProgressIndicator(value: water / 8, minHeight: 6, borderRadius: BorderRadius.circular(8), color: SiTheme.teal, backgroundColor: SiTheme.line), Align(alignment: Alignment.centerLeft, child: IconButton(onPressed: addWater, icon: const Icon(Icons.add_circle_rounded, color: SiTheme.teal)))]));
  Widget _moodCard() => SiCard(padding: const EdgeInsets.all(15), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.psychology_alt_outlined, color: SiTheme.green), const SizedBox(height: 8), const Text('حال امروز', style: TextStyle(fontWeight: FontWeight.w800, color: SiTheme.text)), const SizedBox(height: 3), const Text('یک ثبت کوتاه', style: TextStyle(color: SiTheme.subtext, fontSize: 11)), const SizedBox(height: 6), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: List.generate(5, (i) => GestureDetector(onTap: () => setMood(i), child: Text(['😞','😕','😐','🙂','😄'][i], style: TextStyle(fontSize: mood == i ? 25 : 19)))))]));
}

class ModernProfilePage extends StatefulWidget {
  final List<CameraDescription> cameras;
  const ModernProfilePage({super.key, required this.cameras});
  @override
  State<ModernProfilePage> createState() => _ModernProfilePageState();
}

class _ModernProfilePageState extends State<ModernProfilePage> {
  final supabase = Supabase.instance.client;
  bool loading = true;
  String name = '';
  String username = '';
  String gender = 'male';
  String birthDate = '';
  double divisor = 0;
  int healthScore = 0;
  int healthyDays = 0;
  int screenTime = 0;
  DateTime? calibrated;

  @override
  void initState() { super.initState(); load(); }
  Future<void> load() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    final data = await supabase.from('users').select().eq('id', user.id).maybeSingle();
    if (!mounted) return;
    setState(() { name = '${data?['full_name'] ?? ''}'.trim(); username = '${data?['username'] ?? ''}'.trim(); gender = '${data?['gender'] ?? 'male'}'; birthDate = '${data?['birth_date'] ?? ''}'; divisor = (data?['hunch_divisor'] as num?)?.toDouble() ?? 0; healthScore = (data?['health_score'] as num?)?.toInt() ?? 0; healthyDays = (data?['healthy_days'] as num?)?.toInt() ?? 0; screenTime = (data?['screen_time_minutes'] as num?)?.toInt() ?? 0; calibrated = DateTime.tryParse('${data?['last_calibrated_at'] ?? ''}'); loading = false; });
  }

  Future<void> edit() async {
    final nameC = TextEditingController(text: name); final userC = TextEditingController(text: username); final birthC = TextEditingController(text: birthDate); var g = gender;
    await showDialog(context: context, builder: (_) => Directionality(textDirection: TextDirection.rtl, child: AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), title: const Text('ویرایش اطلاعات'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: nameC, decoration: const InputDecoration(labelText: 'نام و نام خانوادگی')), const SizedBox(height: 10), TextField(controller: userC, decoration: const InputDecoration(labelText: 'نام کاربری')), const SizedBox(height: 10), TextField(controller: birthC, decoration: const InputDecoration(labelText: 'تاریخ تولد')), const SizedBox(height: 10), StatefulBuilder(builder: (ctx, set) => DropdownButtonFormField<String>(value: g == 'female' ? 'female' : 'male', decoration: const InputDecoration(labelText: 'جنسیت'), items: const [DropdownMenuItem(value: 'male', child: Text('آقا')), DropdownMenuItem(value: 'female', child: Text('خانم'))], onChanged: (v) { if (v != null) { g = v; set(() {}); } }))]), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')), FilledButton(onPressed: () async { final user = supabase.auth.currentUser; if (user != null) { await supabase.from('users').update({'full_name': nameC.text.trim(), 'username': userC.text.trim(), 'birth_date': birthC.text.trim(), 'gender': g, 'last_active_at': DateTime.now().toIso8601String()}).eq('id', user.id); } if (mounted) { Navigator.pop(context); load(); } }, child: const Text('ذخیره'))])));
  }

  @override
  Widget build(BuildContext context) => Directionality(textDirection: TextDirection.rtl, child: Scaffold(body: SafeArea(child: loading ? const Center(child: CircularProgressIndicator(color: SiTheme.green)) : RefreshIndicator(onRefresh: load, child: ListView(padding: const EdgeInsets.fromLTRB(20, 14, 20, 32), children: [
    Row(children: [const Text('پروفایل', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: SiTheme.text)), const Spacer(), SiIconButton(icon: Icons.settings_outlined, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ModernSettingsPage()))) ]), const SizedBox(height: 18),
    SiCard(child: Row(children: [Container(width: 68, height: 68, decoration: const BoxDecoration(color: SiTheme.mint, shape: BoxShape.circle), child: const Icon(Icons.person_rounded, color: SiTheme.green, size: 34)), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name.isEmpty ? 'کاربر سی' : name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: SiTheme.text)), const SizedBox(height: 3), Text(username.isEmpty ? 'اطلاعات تکمیلی ثبت نشده' : '@$username', style: const TextStyle(color: SiTheme.subtext)), const SizedBox(height: 8), Text(gender == 'female' ? 'خانم' : 'آقا', style: const TextStyle(color: SiTheme.green, fontWeight: FontWeight.w700))])), IconButton(onPressed: edit, icon: const Icon(Icons.edit_outlined, color: SiTheme.green))])),
    const SizedBox(height: 18), SiSectionTitle('خلاصه سلامت'), const SizedBox(height: 9), Row(children: [_stat('امتیاز', '$healthScore', Icons.favorite_outline), const SizedBox(width: 9), _stat('روز سالم', '$healthyDays', Icons.local_fire_department_outlined), const SizedBox(width: 9), _stat('صفحه', '$screenTimeد', Icons.phone_android_outlined)]),
    const SizedBox(height: 20), SiSectionTitle('اقدامات مهم'), const SizedBox(height: 9),
    SiCard(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CalibrationScreen(cameras: widget.cameras))), child: _action(Icons.center_focus_strong_rounded, 'کالیبراسیون وضعیت بدن', divisor > 0 ? 'کالیبراسیون فعال است' : 'برای شروع پایش انجام بده', Icons.chevron_left_rounded)),
    const SizedBox(height: 10), SiCard(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ModernSettingsPage())), child: _action(Icons.tune_rounded, 'تنظیمات و پایش', 'کنترل سرویس‌ها و حریم خصوصی', Icons.chevron_left_rounded)),
    const SizedBox(height: 20), SiSectionTitle('وضعیت حساب'), const SizedBox(height: 9), SiCard(child: Column(children: [_row('تاریخ تولد', birthDate.isEmpty ? 'ثبت نشده' : birthDate), _divider(), _row('آخرین کالیبراسیون', calibrated == null ? 'ثبت نشده' : _ago(calibrated!)), _divider(), _row('وضعیت پایش', divisor > 0 ? 'آماده' : 'نیازمند کالیبراسیون')])),
  ]))));

  Widget _stat(String title, String value, IconData icon) => Expanded(child: SiCard(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: SiTheme.green), const SizedBox(height: 8), Text(title, style: const TextStyle(color: SiTheme.subtext, fontSize: 11)), const SizedBox(height: 3), Text(value, style: const TextStyle(color: SiTheme.text, fontSize: 15, fontWeight: FontWeight.w900))])));
  Widget _action(IconData icon, String title, String sub, IconData trailing) => Row(children: [Container(width: 46, height: 46, decoration: const BoxDecoration(color: SiTheme.mint, shape: BoxShape.circle), child: Icon(icon, color: SiTheme.green)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: SiTheme.text, fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text(sub, style: const TextStyle(color: SiTheme.subtext, fontSize: 11))])), Icon(trailing, color: SiTheme.subtext)]);
  Widget _row(String a, String b) => Row(children: [Text(a, style: const TextStyle(color: SiTheme.subtext, fontSize: 12)), const Spacer(), Text(b, style: const TextStyle(color: SiTheme.text, fontWeight: FontWeight.w700, fontSize: 12))]);
  Widget _divider() => const Padding(padding: EdgeInsets.symmetric(vertical: 13), child: Divider(height: 1, color: SiTheme.line));
  String _ago(DateTime d) { final x = DateTime.now().difference(d); if (x.inDays > 0) return '${x.inDays} روز پیش'; if (x.inHours > 0) return '${x.inHours} ساعت پیش'; return 'امروز'; }
}

class ModernSettingsPage extends StatefulWidget {
  const ModernSettingsPage({super.key});
  @override
  State<ModernSettingsPage> createState() => _ModernSettingsPageState();
}

class _ModernSettingsPageState extends State<ModernSettingsPage> {
  bool monitoring = false;
  bool nsfw = false;
  bool loading = true;
  @override
  void initState() { super.initState(); load(); }
  Future<void> load() async { final p = await SharedPreferences.getInstance(); final running = await BackgroundMonitorService.isRunning; if (!mounted) return; setState(() { monitoring = running || (p.getBool('monitoring_enabled') ?? false); nsfw = p.getBool('nsfw_monitoring_enabled') ?? false; loading = false; }); }
  Future<void> toggleMonitoring(bool value) async { final p = await SharedPreferences.getInstance(); if (value) { final user = Supabase.instance.client.auth.currentUser; final data = user == null ? null : await Supabase.instance.client.from('users').select('hunch_divisor').eq('id', user.id).maybeSingle(); final divisor = (data?['hunch_divisor'] as num?)?.toDouble(); if (divisor == null || divisor <= 0) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ابتدا کالیبراسیون را انجام بده.'))); return; } await BackgroundMonitorService.saveHunchDivisor(divisor); await BackgroundMonitorService.initialize(); BackgroundMonitorService.start(); await p.setBool('monitoring_enabled', true); } else { BackgroundMonitorService.stop(); await p.setBool('monitoring_enabled', false); } if (mounted) setState(() => monitoring = value); }
  Future<void> toggleNsfw(bool value) async { final p = await SharedPreferences.getInstance(); if (value) { final ok = await NSFWDetectionController().enable(); if (!ok) return; await p.setBool('nsfw_monitoring_enabled', true); } else { await NSFWDetectionController().disable(); await p.setBool('nsfw_monitoring_enabled', false); } if (mounted) setState(() => nsfw = value); }
  @override
  Widget build(BuildContext context) => Directionality(textDirection: TextDirection.rtl, child: Scaffold(body: SafeArea(child: loading ? const Center(child: CircularProgressIndicator(color: SiTheme.green)) : ListView(padding: const EdgeInsets.fromLTRB(20, 14, 20, 32), children: [Row(children: [SiIconButton(icon: Icons.arrow_forward_rounded, onTap: () => Navigator.pop(context)), const Spacer(), const Text('تنظیمات', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: SiTheme.text)), const Spacer(), const SizedBox(width: 44)]), const SizedBox(height: 22), _section('پایش', [_toggle(Icons.monitor_heart_outlined, 'پایش سلامت', 'وضعیت بدن، فاصله و نور محیط', monitoring, toggleMonitoring), _toggle(Icons.visibility_off_outlined, 'پایش محتوای نامناسب', 'هشدار در صورت تشخیص محتوای نامناسب', nsfw, toggleNsfw)]), const SizedBox(height: 14), _section('حساب', [SiCard(onTap: () => Supabase.instance.client.auth.signOut().then((_) { if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false); }), child: Row(children: [Container(width: 44, height: 44, decoration: BoxDecoration(color: Colors.red.withOpacity(.08), shape: BoxShape.circle), child: const Icon(Icons.logout_rounded, color: Colors.redAccent)), const SizedBox(width: 12), const Expanded(child: Text('خروج از حساب', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w800))), const Icon(Icons.chevron_left_rounded, color: SiTheme.subtext)]))])]))));
  Widget _section(String title, List<Widget> children) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Padding(padding: const EdgeInsets.only(bottom: 9, right: 3), child: Text(title, style: const TextStyle(color: SiTheme.text, fontWeight: FontWeight.w800, fontSize: 15))), ...children]);
  Widget _toggle(IconData icon, String title, String sub, bool value, ValueChanged<bool> onChanged) => Padding(padding: const EdgeInsets.only(bottom: 10), child: SiCard(child: Row(children: [Container(width: 46, height: 46, decoration: const BoxDecoration(color: SiTheme.mint, shape: BoxShape.circle), child: Icon(icon, color: SiTheme.green)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: SiTheme.text, fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text(sub, style: const TextStyle(color: SiTheme.subtext, fontSize: 11))])), Switch.adaptive(value: value, onChanged: onChanged, activeColor: SiTheme.green)]));
}
