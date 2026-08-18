import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../backend/daily_health_metric.dart';
import '../backend/health_data_repository.dart';
import '../services/background_service.dart';
import 'exercise_center_page.dart';
import 'posture_analysis_page.dart';
import 'profile_page.dart';
import 'womens_health_page.dart';

class MainNavigationScreen extends StatefulWidget {
  final String userGender;

  const MainNavigationScreen({
    super.key,
    required this.userGender,
  });

  @override
  State<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  static const Color green = Color(0xFF42D2A7);
  static const Color teal = Color(0xFF45C4D0);
  static const Color bg = Color(0xFFF4F9F7);
  static const Color subtext = Color(0xFF7D8D89);

  int currentIndex = 0;

  late List<Widget> pages;
  late List<_NavItem> navItems;

  StreamSubscription<Map<String, dynamic>?>? statusSubscription;
  Timer? monitoringPollTimer;

  bool serviceAlive = false;

  bool get monitoringActive => serviceAlive;

  @override
  void initState() {
    super.initState();

    pages = <Widget>[
      _DashboardHome(
        isMonitoringActive: () => monitoringActive,
        onPosture: () => _goTo(1),
        onExercise: () => _goTo(2),
      ),
      const PostureAnalysisPage(),
      const ExerciseCenterPage(),
    ];

    navItems = <_NavItem>[
      const _NavItem(
        Icons.grid_view_rounded,
        'سلامت',
      ),
      const _NavItem(
        Icons.accessibility_new_rounded,
        'بدن',
      ),
      const _NavItem(
        Icons.fitness_center_rounded,
        'ورزش',
      ),
    ];

    if (widget.userGender == 'female') {
      pages.add(
        const WomensHealthPage(),
      );

      navItems.add(
        const _NavItem(
          Icons.favorite_rounded,
          'بانوان',
        ),
      );
    }

    pages.add(
      const ProfilePage(),
    );

    navItems.add(
      const _NavItem(
        Icons.person_rounded,
        'پروفایل',
      ),
    );

    // We ONLY observe the monitoring service here.
    //
    // IMPORTANT:
    // There is deliberately NO automatic monitoring startup.
    // Opening the dashboard will not:
    // - request camera permission
    // - request notification permission
    // - request overlay permission
    // - check calibration
    // - initialize the background service
    // - start the background service
    //
    // Monitoring must be explicitly started elsewhere by the user.

    _listenToService();
    _refreshMonitoringState();

    monitoringPollTimer = Timer.periodic(
      const Duration(seconds: 2),
          (_) => _refreshMonitoringState(),
    );
  }

  void _goTo(int index) {
    if (!mounted) return;

    if (index < 0 || index >= pages.length) {
      return;
    }

    setState(() {
      currentIndex = index;
    });
  }

  Future<void> _refreshMonitoringState() async {
    try {
      final running =
      await BackgroundMonitorService.isRunning;

      if (!mounted || running == serviceAlive) {
        return;
      }

      setState(() {
        serviceAlive = running;
      });
    } catch (e) {
      debugPrint(
        '[Dashboard] monitoring state error: $e',
      );

      if (!mounted) return;

      if (serviceAlive) {
        setState(() {
          serviceAlive = false;
        });
      }
    }
  }

  void _listenToService() {
    statusSubscription?.cancel();

    statusSubscription =
        BackgroundMonitorService.statusStream.listen(
              (event) {
            if (!mounted || event == null) {
              return;
            }

            final running = event['running'] == true;

            if (running == serviceAlive) {
              return;
            }

            setState(() {
              serviceAlive = running;
            });
          },
        );
  }

  void _message(
      String message, {
        bool error = false,
      }) {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor:
          error ? Colors.red.shade600 : green,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  void dispose() {
    statusSubscription?.cancel();
    monitoringPollTimer?.cancel();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: IndexedStack(
            index: currentIndex,
            children: pages,
          ),
        ),
        bottomNavigationBar:
        _buildBottomNavigationBar(),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      color: bg,
      padding: const EdgeInsets.fromLTRB(
        14,
        6,
        14,
        12,
      ),
      child: Container(
        height: 68,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 24,
              offset: Offset(0, 7),
            ),
          ],
        ),
        child: Row(
          children: List.generate(
            navItems.length,
                (index) {
              final selected =
                  index == currentIndex;

              final item = navItems[index];

              return Expanded(
                child: InkWell(
                  onTap: () => _goTo(index),
                  borderRadius:
                  BorderRadius.circular(17),
                  child: AnimatedContainer(
                    duration:
                    const Duration(milliseconds: 180),
                    margin: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: selected
                          ? green.withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius:
                      BorderRadius.circular(17),
                    ),
                    child: Column(
                      mainAxisAlignment:
                      MainAxisAlignment.center,
                      children: [
                        Icon(
                          item.icon,
                          size: 21,
                          color: selected
                              ? green
                              : subtext,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.label,
                          style: TextStyle(
                            color: selected
                                ? green
                                : subtext,
                            fontSize: 9,
                            fontWeight: selected
                                ? FontWeight.w900
                                : FontWeight.w600,
                          ),
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

class _NavItem {
  final IconData icon;
  final String label;

  const _NavItem(
      this.icon,
      this.label,
      );
}

// ============================================================================
// DASHBOARD
// ============================================================================

class _DashboardHome extends StatefulWidget {
  final bool Function() isMonitoringActive;
  final VoidCallback onPosture;
  final VoidCallback onExercise;

  const _DashboardHome({
    required this.isMonitoringActive,
    required this.onPosture,
    required this.onExercise,
  });

  @override
  State<_DashboardHome> createState() =>
      _DashboardHomeState();
}

class _DashboardHomeState
    extends State<_DashboardHome> {
  static const Color green = Color(0xFF42D2A7);
  static const Color teal = Color(0xFF45C4D0);
  static const Color bg = Color(0xFFF4F9F7);
  static const Color text = Color(0xFF263B37);
  static const Color subtext = Color(0xFF7D8D89);
  static const Color line = Color(0xFFE8EFEC);
  static const Color mint = Color(0xFFE8F8F1);

  DailyHealthMetric? today;

  bool loading = true;

  int water = 0;

  String? socialCheckIn;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs =
      await SharedPreferences.getInstance();

      final rows =
      await HealthDataRepository.instance
          .getDailyMetrics(days: 1);

      if (!mounted) return;

      setState(() {
        today = rows.isEmpty
            ? null
            : DailyHealthMetric.fromMap(
          rows.first,
        );

        water = prefs.getInt(_waterKey()) ?? 0;

        socialCheckIn =
            prefs.getString(_socialKey());

        loading = false;
      });
    } catch (e) {
      debugPrint(
        '[Dashboard] load error: $e',
      );

      if (!mounted) return;

      setState(() {
        loading = false;
      });
    }
  }

  String _waterKey() {
    final date = DateTime.now();

    return 'si_water_'
        '${date.year}_'
        '${date.month}_'
        '${date.day}';
  }

  String _socialKey() {
    final date = DateTime.now();

    return 'si_social_'
        '${date.year}_'
        '${date.month}_'
        '${date.day}';
  }

  Future<void> _addWater() async {
    if (water >= 8) {
      return;
    }

    final next = water + 1;

    final prefs =
    await SharedPreferences.getInstance();

    await prefs.setInt(
      _waterKey(),
      next,
    );

    if (!mounted) return;

    setState(() {
      water = next;
    });
  }

  Future<void> _setSocialCheckIn(
      String value,
      ) async {
    final prefs =
    await SharedPreferences.getInstance();

    await prefs.setString(
      _socialKey(),
      value,
    );

    if (!mounted) return;

    setState(() {
      socialCheckIn = value;
    });
  }

  double get risk {
    if (today == null) {
      return 0;
    }

    return today!.neck +
        today!.hunch +
        today!.wrist +
        today!.tooClose +
        today!.badLight;
  }

  int get score {
    final healthScore =
        today?.healthScore;

    if (healthScore != null) {
      return healthScore.clamp(0, 100);
    }

    if (risk == 0) {
      return 100;
    }

    final calculated =
        100 - (risk * 0.8);

    return calculated
        .clamp(0, 100)
        .round();
  }

  String _minutes(double value) {
    if (value < 1) {
      return '${(value * 60).round()}ث';
    }

    if (value < 60) {
      return '${value.round()}د';
    }

    final hours = value ~/ 60;
    final minutes = value.round() % 60;

    if (minutes == 0) {
      return '${hours}س';
    }

    return '${hours}س ${minutes}د';
  }

  Color get _scoreColor {
    if (score >= 85) {
      return green;
    }

    if (score >= 65) {
      return teal;
    }

    if (score >= 40) {
      return const Color(0xFFFFA62B);
    }

    return const Color(0xFFD95C5C);
  }

  String get _scoreTitle {
    if (score >= 85) {
      return 'عالی';
    }

    if (score >= 65) {
      return 'خوب';
    }

    if (score >= 40) {
      return 'نیازمند توجه';
    }

    return 'نیازمند استراحت';
  }

  String get _scoreDescription {
    if (score >= 85) {
      return 'امروز الگوی استفاده و وضعیت بدنت خوب بوده. همین روند را حفظ کن.';
    }

    if (score >= 65) {
      return 'وضعیتت قابل قبول است، اما چند استراحت کوتاه می‌تواند امتیازت را بهتر کند.';
    }

    if (score >= 40) {
      return 'بدنت امروز کمی بیشتر تحت فشار بوده. زمان بیشتری برای استراحت و اصلاح وضعیت در نظر بگیر.';
    }

    return 'امروز فشار زیادی روی بدنت بوده. چند دقیقه از صفحه فاصله بگیر و وضعیت بدنت را اصلاح کن.';
  }

  Widget _card({
    required Widget child,
    EdgeInsets padding =
    const EdgeInsets.all(16),
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(
          color: line,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: green,
      onRefresh: _load,
      child: ListView(
        physics:
        const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          18,
          12,
          18,
          28,
        ),
        children: [
          _buildHeader(),

          const SizedBox(height: 14),

          _monitorCard(),

          const SizedBox(height: 14),

          _scoreCard(),

          const SizedBox(height: 14),

          _buildMetrics(),

          const SizedBox(height: 14),

          _dailySupport(),

          const SizedBox(height: 14),

          _quickActions(),

          const SizedBox(height: 14),

          _recommendation(),
        ],
      ),
    );
  }

  // ==========================================================================
  // HEADER
  // ==========================================================================

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                _greeting(),
                style: const TextStyle(
                  color: subtext,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'امروزت را بهتر مدیریت کن',
                style: TextStyle(
                  color: text,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 46,
          height: 46,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                green,
                teal,
              ],
            ),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.favorite_rounded,
            color: Colors.white,
            size: 23,
          ),
        ),
      ],
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;

    if (hour < 12) {
      return 'صبح بخیر 👋';
    }

    if (hour < 18) {
      return 'روز بخیر 👋';
    }

    return 'عصر بخیر 👋';
  }

  // ==========================================================================
  // MONITOR
  // ==========================================================================

  Widget _monitorCard() {
    final active =
    widget.isMonitoringActive();

    final gradientColors = active
        ? const [
      green,
      teal,
    ]
        : const [
      Color(0xFF9AA4AD),
      Color(0xFF6E7983),
    ];

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
        ),
        borderRadius:
        BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(
                alpha: 0.18,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              active
                  ? Icons.radar_rounded
                  : Icons.radar_outlined,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  active
                      ? 'پایش فعال است'
                      : 'پایش فعال نیست',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight:
                    FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  active
                      ? 'سی در حال ثبت الگوهای سلامت توست.'
                      : 'برای دریافت داده‌های سلامت، پایش را از بخش بدن فعال کن.',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 9,
            height: 9,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // HEALTH SCORE
  // ==========================================================================

  Widget _scoreCard() {
    final color = _scoreColor;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(24),
        border: Border.all(
          color: line,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 20,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'امتیاز سلامت امروز',
                      style: TextStyle(
                        color: text,
                        fontSize: 16,
                        fontWeight:
                        FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      loading
                          ? 'در حال دریافت داده‌ها...'
                          : _scoreTitle,
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight:
                        FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(
                    alpha: 0.10,
                  ),
                  borderRadius:
                  BorderRadius.circular(12),
                ),
                child: Text(
                  '$score / 100',
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight:
                    FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          Row(
            crossAxisAlignment:
            CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment:
                      CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$score',
                          style: const TextStyle(
                            color: text,
                            fontSize: 52,
                            height: 0.95,
                            fontWeight:
                            FontWeight.w900,
                            letterSpacing: -2,
                          ),
                        ),
                        const SizedBox(width: 7),
                        const Padding(
                          padding:
                          EdgeInsets.only(
                            bottom: 5,
                          ),
                          child: Text(
                            'از ۱۰۰',
                            style: TextStyle(
                              color: subtext,
                              fontSize: 11,
                              fontWeight:
                              FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius:
                      BorderRadius.circular(8),
                      child:
                      LinearProgressIndicator(
                        value: score / 100,
                        minHeight: 10,
                        backgroundColor: mint,
                        valueColor:
                        AlwaysStoppedAnimation<
                            Color>(
                          color,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _scoreDescription,
                      style: const TextStyle(
                        color: subtext,
                        fontSize: 10,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin:
                    Alignment.topLeft,
                    end:
                    Alignment.bottomRight,
                    colors: [
                      color,
                      color.withValues(
                        alpha: 0.72,
                      ),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(
                        alpha: 0.20,
                      ),
                      blurRadius: 18,
                      offset:
                      const Offset(0, 7),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment:
                  MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.favorite_rounded,
                      color: Colors.white,
                      size: 19,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _scoreTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight:
                        FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Container(
            padding:
            const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF7FAF9),
              borderRadius:
              BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.phone_android_rounded,
                  color: teal,
                  size: 18,
                ),
                const SizedBox(width: 8),
                const Text(
                  'زمان صفحه امروز',
                  style: TextStyle(
                    color: subtext,
                    fontSize: 10,
                  ),
                ),
                const Spacer(),
                Text(
                  _minutes(
                    today?.screenTime ?? 0,
                  ),
                  style: const TextStyle(
                    color: text,
                    fontSize: 12,
                    fontWeight:
                    FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // METRICS
  // ==========================================================================

  Widget _buildMetrics() {
    return Row(
      children: [
        _metric(
          'گردن',
          _minutes(today?.neck ?? 0),
          Icons.accessibility_new_rounded,
          green,
        ),
        const SizedBox(width: 7),
        _metric(
          'قوز',
          _minutes(today?.hunch ?? 0),
          Icons.airline_seat_recline_normal_rounded,
          teal,
        ),
        const SizedBox(width: 7),
        _metric(
          'مچ',
          _minutes(today?.wrist ?? 0),
          Icons.back_hand_rounded,
          const Color(0xFFFFA62B),
        ),
      ],
    );
  }

  Widget _metric(
      String title,
      String value,
      IconData icon,
      Color color,
      ) {
    return Expanded(
      child: _card(
        padding:
        const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 6,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: color,
              size: 19,
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                color: text,
                fontSize: 15,
                fontWeight:
                FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: subtext,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // DAILY SUPPORT
  // ==========================================================================

  Widget _dailySupport() {
    return LayoutBuilder(
      builder: (
          context,
          constraints,
          ) {
        final stack =
            constraints.maxWidth < 390;

        final waterCard = _card(
          child: _waterContent(),
        );

        final socialCard = _card(
          child: _socialContent(),
        );

        if (stack) {
          return Column(
            children: [
              waterCard,
              const SizedBox(height: 10),
              socialCard,
            ],
          );
        }

        return Row(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Expanded(child: waterCard),
            const SizedBox(width: 10),
            Expanded(child: socialCard),
          ],
        );
      },
    );
  }

  Widget _waterContent() {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(
              Icons.water_drop_rounded,
              color: teal,
              size: 18,
            ),
            SizedBox(width: 6),
            Text(
              'آب امروز',
              style: TextStyle(
                color: text,
                fontSize: 12,
                fontWeight:
                FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '$water/8 لیوان',
          style: const TextStyle(
            color: text,
            fontSize: 15,
            fontWeight:
            FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius:
          BorderRadius.circular(5),
          child: LinearProgressIndicator(
            value: water / 8,
            minHeight: 5,
            backgroundColor: line,
            valueColor:
            const AlwaysStoppedAnimation<
                Color>(
              teal,
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed:
            water >= 8 ? null : _addWater,
            style:
            OutlinedButton.styleFrom(
              foregroundColor: teal,
              side:
              const BorderSide(
                color: teal,
              ),
              padding:
              const EdgeInsets.symmetric(
                vertical: 7,
              ),
            ),
            child: const Text(
              '+ یک لیوان',
              style: TextStyle(
                fontSize: 10,
                fontWeight:
                FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _socialContent() {
    final checked =
        socialCheckIn != null;

    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(
              Icons.groups_rounded,
              color: green,
              size: 18,
            ),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'ارتباط امروز',
                style: TextStyle(
                  color: text,
                  fontSize: 12,
                  fontWeight:
                  FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Text(
          checked
              ? socialCheckIn!
              : 'یک ارتباط کوتاه با آدم‌های مهم زندگی هم بخشی از مراقبت از خود است.',
          style: const TextStyle(
            color: subtext,
            fontSize: 10,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 5,
          runSpacing: 5,
          children: [
            _socialChip(
              'با یک دوست صحبت کردم',
              'گفتگو',
            ),
            _socialChip(
              'بیرون رفتم',
              'بیرون',
            ),
            _socialChip(
              'امروز وقتش را ندارم',
              'بعداً',
            ),
          ],
        ),
      ],
    );
  }

  Widget _socialChip(
      String label,
      String value,
      ) {
    final selected =
        socialCheckIn == label;

    return InkWell(
      onTap: () =>
          _setSocialCheckIn(label),
      borderRadius:
      BorderRadius.circular(10),
      child: Container(
        padding:
        const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 7,
        ),
        decoration: BoxDecoration(
          color: selected
              ? mint
              : const Color(0xFFF7FAF9),
          borderRadius:
          BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? green.withValues(
              alpha: 0.35,
            )
                : line,
          ),
        ),
        child: Text(
          value,
          style: TextStyle(
            color: selected
                ? green
                : subtext,
            fontSize: 9,
            fontWeight:
            FontWeight.w800,
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // QUICK ACTIONS
  // ==========================================================================

  Widget _quickActions() {
    return LayoutBuilder(
      builder: (
          context,
          constraints,
          ) {
        if (constraints.maxWidth < 330) {
          return Column(
            children: [
              _action(
                'وضعیت بدن',
                Icons.accessibility_new_rounded,
                widget.onPosture,
              ),
              const SizedBox(height: 8),
              _action(
                'تمرین کوتاه',
                Icons.fitness_center_rounded,
                widget.onExercise,
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: _action(
                'وضعیت بدن',
                Icons.accessibility_new_rounded,
                widget.onPosture,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _action(
                'تمرین کوتاه',
                Icons.fitness_center_rounded,
                widget.onExercise,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _action(
      String title,
      IconData icon,
      VoidCallback onTap,
      ) {
    return InkWell(
      onTap: onTap,
      borderRadius:
      BorderRadius.circular(20),
      child: _card(
        padding:
        const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 14,
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration:
              const BoxDecoration(
                color: mint,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: green,
                size: 18,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: text,
                  fontSize: 11,
                  fontWeight:
                  FontWeight.w900,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_left_rounded,
              color: subtext,
              size: 19,
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // RECOMMENDATION
  // ==========================================================================

  Widget _recommendation() {
    final excellent = score >= 85;

    final title = excellent
        ? 'همین روند را حفظ کن'
        : 'یک استراحت کوتاه داشته باش';

    final body = excellent
        ? 'آب کافی بنوش و در طول استفاده از گوشی وضعیت گردن و مچ را هر چند دقیقه تغییر بده.'
        : 'چند دقیقه از صفحه فاصله بگیر، شانه‌ها را آزاد کن و یک حرکت کششی کوتاه انجام بده.';

    return _card(
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration:
            const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  green,
                  teal,
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lightbulb_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: text,
                    fontSize: 12,
                    fontWeight:
                    FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    color: subtext,
                    fontSize: 10,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}