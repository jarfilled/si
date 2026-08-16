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

  const MainNavigationScreen({
    Key? key,
    required this.userGender,
  }) : super(key: key);

  @override
  State<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  // ---------------------------------------------------------------------------
  // THEME
  // ---------------------------------------------------------------------------

  static const Color primaryGreen = Color(0xFF42D2A7);
  static const Color teal = Color(0xFF45C4D0);
  static const Color background = Color(0xFFF5F7FA);
  static const Color darkText = Color(0xFF2D3142);
  static const Color secondaryText = Color(0xFF7B8190);

  late List<Widget> _pages;
  late List<_NavigationItem> _navigationItems;

  // ---------------------------------------------------------------------------
  // MONITORING STATE
  // ---------------------------------------------------------------------------

  StreamSubscription<Map<String, dynamic>?>? _statusSubscription;

  bool _isServiceAlive = false;
  DateTime? _lastHeartbeat;
  bool _isStartingMonitoring = false;

  @override
  void initState() {
    super.initState();

    _setupPages();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPrivacyAgreement();
    });
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // NAVIGATION
  // ---------------------------------------------------------------------------

  void _setupPages() {
    _pages = [
      _DashboardPage(
        onOpenPosture: () {
          setState(() {
            _currentIndex = 1;
          });
        },
        onOpenExercise: () {
          setState(() {
            _currentIndex = 2;
          });
        },
        isMonitoringActive: _isMonitoringActive,
      ),

      const PostureAnalysisPage(),

      const ExerciseCenterPage(),
    ];

    _navigationItems = [
      const _NavigationItem(
        icon: Icons.grid_view_rounded,
        label: 'سلامت',
      ),
      const _NavigationItem(
        icon: Icons.accessibility_new_rounded,
        label: 'وضعیت بدن',
      ),
      const _NavigationItem(
        icon: Icons.fitness_center_rounded,
        label: 'ورزش',
      ),
    ];

    if (widget.userGender == 'female') {
      _pages.add(const WomensHealthPage());

      _navigationItems.add(
        const _NavigationItem(
          icon: Icons.favorite_rounded,
          label: 'بانوان',
        ),
      );
    }

    _pages.add(const ProfilePage());

    _navigationItems.add(
      const _NavigationItem(
        icon: Icons.person_rounded,
        label: 'پروفایل',
      ),
    );
  }

  bool get _isMonitoringActive {
    if (!_isServiceAlive || _lastHeartbeat == null) {
      return false;
    }

    return DateTime.now().difference(_lastHeartbeat!) <
        const Duration(seconds: 12);
  }

  // ---------------------------------------------------------------------------
  // PRIVACY / MONITORING
  // ---------------------------------------------------------------------------

  Future<void> _checkPrivacyAgreement() async {
    final prefs = await SharedPreferences.getInstance();

    final hasAgreed =
        prefs.getBool('has_agreed_privacy') ?? false;

    if (!mounted) return;

    if (!hasAgreed) {
      _showPrivacyDialog(prefs);
    } else {
      await _startMonitoring();
    }
  }

  Future<void> _startMonitoring() async {
    if (_isStartingMonitoring) return;

    _isStartingMonitoring = true;

    try {
      final permissions = await [
        Permission.camera,
        Permission.notification,
      ].request();

      if (!permissions[Permission.camera]!.isGranted) {
        _showMessage(
          'برای فعال‌سازی مانیتورینگ، اجازه دسترسی به دوربین لازم است.',
          isError: true,
        );
        return;
      }

      final isOverlayGranted =
      await FlutterOverlayWindow.isPermissionGranted();

      if (!isOverlayGranted) {
        await FlutterOverlayWindow.requestPermission();
      }

      final user =
          Supabase.instance.client.auth.currentUser;

      if (user == null) {
        debugPrint(
          'Monitoring not started: no authenticated user.',
        );

        _showMessage(
          'جلسه ورود شما پیدا نشد. لطفاً دوباره وارد شوید.',
          isError: true,
        );
        return;
      }

      final calibrationData =
      await Supabase.instance.client
          .from('users')
          .select('hunch_divisor')
          .eq('id', user.id)
          .maybeSingle();

      final divisor =
      (calibrationData?['hunch_divisor'] as num?)
          ?.toDouble();

      if (divisor == null ||
          !divisor.isFinite ||
          divisor <= 0) {
        debugPrint(
          'Monitoring not started: hunch_divisor is missing or invalid.',
        );

        _showMessage(
          'کالیبراسیون وضعیت بدن پیدا نشد. لطفاً ابتدا کالیبراسیون را انجام دهید.',
          isError: true,
        );
        return;
      }

      await BackgroundMonitorService.saveHunchDivisor(
        divisor,
      );

      debugPrint(
        'Saved hunch_divisor for monitoring: $divisor',
      );

      final alreadyRunning =
      await BackgroundMonitorService.isRunning;

      await BackgroundMonitorService.initialize();

      if (!alreadyRunning) {
        await Future.delayed(
          const Duration(milliseconds: 500),
        );

        BackgroundMonitorService.start();
      }

      _listenToServiceStatus();

      _showMessage(
        'سرویس‌های نظارتی با موفقیت فعال شدند.',
      );
    } catch (e, stackTrace) {
      debugPrint(
        'Error starting monitoring: $e',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      _showMessage(
        'خطا در فعال‌سازی سرویس‌های نظارتی.',
        isError: true,
      );
    } finally {
      _isStartingMonitoring = false;
    }
  }

  void _listenToServiceStatus() {
    _statusSubscription?.cancel();

    _statusSubscription =
        BackgroundMonitorService.statusStream.listen(
              (event) {
            if (event == null || !mounted) return;

            setState(() {
              _isServiceAlive =
                  event['running'] == true;

              _lastHeartbeat = DateTime.now();
            });
          },
        );
  }

  // ---------------------------------------------------------------------------
  // MESSAGES
  // ---------------------------------------------------------------------------

  void _showMessage(
      String message, {
        bool isError = false,
      }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: 'Vazirmatn',
          ),
        ),
        backgroundColor: isError
            ? Colors.red.shade600
            : primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PRIVACY DIALOG
  // ---------------------------------------------------------------------------

  void _showPrivacyDialog(
      SharedPreferences prefs,
      ) {
    bool isChecked = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: StatefulBuilder(
            builder: (
                context,
                setDialogState,
                ) {
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(24),
                ),
                backgroundColor: Colors.white,
                title: const Text(
                  'حریم خصوصی و دسترسی‌ها',
                  style: TextStyle(
                    color: darkText,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Vazirmatn',
                  ),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'برای عملکرد صحیح این برنامه، نیاز به پردازش تصویر دوربین شما در پس‌زمینه است.\n\nتمامی پردازش‌های مربوط به وضعیت بدن روی دستگاه شما انجام می‌شوند و هیچ تصویری ذخیره یا به سروری ارسال نمی‌شود.',
                      style: TextStyle(
                        fontSize: 14,
                        color: darkText,
                        height: 1.7,
                        fontFamily: 'Vazirmatn',
                      ),
                      textAlign: TextAlign.justify,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Checkbox(
                          value: isChecked,
                          activeColor: primaryGreen,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(5),
                          ),
                          onChanged: (value) {
                            setDialogState(() {
                              isChecked =
                                  value ?? false;
                            });
                          },
                        ),
                        const Expanded(
                          child: Text(
                            'شرایط را خوانده و با دسترسی‌ها موافقم.',
                            style: TextStyle(
                              fontSize: 13,
                              color: darkText,
                              fontFamily: 'Vazirmatn',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                actions: [
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: isChecked
                          ? () async {
                        await prefs.setBool(
                          'has_agreed_privacy',
                          true,
                        );

                        if (!mounted) return;

                        Navigator.of(ctx).pop();

                        await _startMonitoring();
                      }
                          : null,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor:
                        isChecked
                            ? primaryGreen
                            : Colors.grey.shade300,
                        disabledForegroundColor:
                        Colors.white,
                        shape:
                        RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(14),
                        ),
                        padding:
                        const EdgeInsets.symmetric(
                          vertical: 15,
                        ),
                      ),
                      child: const Text(
                        'تأیید و ادامه',
                        style: TextStyle(
                          fontWeight:
                          FontWeight.bold,
                          fontFamily:
                          'Vazirmatn',
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
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
          child: IndexedStack(
            index: _currentIndex,
            children: _pages,
          ),
        ),

        bottomNavigationBar:
        _buildBottomNavigation(),
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      color: background,
      padding: const EdgeInsets.fromLTRB(
        18,
        8,
        18,
        14,
      ),
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
          BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 25,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: List.generate(
            _navigationItems.length,
                (index) {
              final selected =
                  index == _currentIndex;

              final item =
              _navigationItems[index];

              return Expanded(
                child: GestureDetector(
                  behavior:
                  HitTestBehavior.opaque,
                  onTap: () {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                  child: AnimatedContainer(
                    duration:
                    const Duration(
                      milliseconds: 200,
                    ),
                    margin:
                    const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: selected
                          ? primaryGreen
                          .withOpacity(0.12)
                          : Colors.transparent,
                      borderRadius:
                      BorderRadius.circular(18),
                    ),
                    child: Column(
                      mainAxisAlignment:
                      MainAxisAlignment.center,
                      children: [
                        Icon(
                          item.icon,
                          size: 22,
                          color: selected
                              ? primaryGreen
                              : Colors.grey
                              .shade400,
                        ),
                        const SizedBox(
                          height: 4,
                        ),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontFamily:
                            'Vazirmatn',
                            fontSize: 10,
                            fontWeight:
                            selected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: selected
                                ? primaryGreen
                                : Colors.grey
                                .shade500,
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

// =============================================================================
// NAVIGATION ITEM
// =============================================================================

class _NavigationItem {
  final IconData icon;
  final String label;

  const _NavigationItem({
    required this.icon,
    required this.label,
  });
}

// =============================================================================
// NEW DASHBOARD
// =============================================================================

class _DashboardPage extends StatefulWidget {
  final VoidCallback onOpenPosture;
  final VoidCallback onOpenExercise;
  final bool isMonitoringActive;

  const _DashboardPage({
    required this.onOpenPosture,
    required this.onOpenExercise,
    required this.isMonitoringActive,
  });

  @override
  State<_DashboardPage> createState() =>
      _DashboardPageState();
}

class _DashboardPageState
    extends State<_DashboardPage> {
  static const Color primaryGreen =
  Color(0xFF42D2A7);

  static const Color teal =
  Color(0xFF45C4D0);

  static const Color background =
  Color(0xFFF5F7FA);

  static const Color darkText =
  Color(0xFF2D3142);

  static const Color secondaryText =
  Color(0xFF7B8190);

  DailyHealthMetric? _today;
  DailyHealthMetric? _yesterday;

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMetrics();
  }

  Future<void> _loadMetrics() async {
    try {
      final rows =
      await HealthDataRepository.instance
          .getDailyMetrics(days: 2);

      if (!mounted) return;

      DailyHealthMetric? today;
      DailyHealthMetric? yesterday;

      for (final row in rows) {
        final metric =
        DailyHealthMetric.fromMap(row);

        final date = DateTime(
          metric.date.year,
          metric.date.month,
          metric.date.day,
        );

        final now = DateTime.now();

        final todayDate = DateTime(
          now.year,
          now.month,
          now.day,
        );

        final yesterdayDate =
        todayDate.subtract(
          const Duration(days: 1),
        );

        if (date == todayDate) {
          today = metric;
        } else if (date == yesterdayDate) {
          yesterday = metric;
        }
      }

      setState(() {
        _today = today;
        _yesterday = yesterday;
        _loading = false;
      });
    } catch (e) {
      debugPrint(
        '[Dashboard] Failed to load metrics: $e',
      );

      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'داده‌های امروز قابل دریافت نیست.';
      });
    }
  }

  double get _totalRiskMinutes {
    final data = _today;

    if (data == null) return 0;

    return data.neck +
        data.hunch +
        data.wrist +
        data.tooClose +
        data.badLight;
  }

  int get _healthScore {
    final data = _today;

    if (data == null) return 100;

    final risk = _totalRiskMinutes;

    // A simple presentation score.
    // This is deliberately NOT stored as the official health_score.
    final score =
    (100 - risk * 0.8).clamp(0, 100);

    return score.round();
  }

  String get _statusTitle {
    if (_today == null) {
      return 'هنوز داده‌ای ثبت نشده';
    }

    if (_totalRiskMinutes < 15) {
      return 'روز خیلی خوبی داری';
    }

    if (_totalRiskMinutes < 40) {
      return 'وضعیتت خوبه';
    }

    if (_totalRiskMinutes < 70) {
      return 'کمی بیشتر مراقب باش';
    }

    return 'امروز به بدنت بیشتر توجه کن';
  }

  String get _statusSubtitle {
    if (_today == null) {
      return 'با فعال بودن مانیتورینگ، وضعیت امروزت اینجا نمایش داده می‌شود.';
    }

    if (_totalRiskMinutes < 15) {
      return 'بدنت امروز عملکرد خوبی داشته. همین روند را ادامه بده.';
    }

    if (_totalRiskMinutes < 40) {
      return 'چند مورد برای اصلاح وجود دارد، اما شرایط کلی خوب است.';
    }

    return 'چند الگوی نامناسب ثبت شده. بهتر است کمی استراحت و اصلاح وضعیت داشته باشی.';
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: primaryGreen,
      onRefresh: _loadMetrics,
      child: SingleChildScrollView(
        physics:
        const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(
          20,
          18,
          20,
          30,
        ),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            _buildHeader(),

            const SizedBox(height: 22),

            _buildMonitoringCard(),

            const SizedBox(height: 18),

            _buildHealthOverview(),

            const SizedBox(height: 22),

            _buildSectionTitle(
              'وضعیت امروز',
              'جزئیات پایش بدنت',
            ),

            const SizedBox(height: 12),

            _buildMetricGrid(),

            const SizedBox(height: 22),

            _buildQuickActions(),

            const SizedBox(height: 22),

            _buildRecommendation(),

            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HEADER
  // ---------------------------------------------------------------------------

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
                  fontFamily: 'Vazirmatn',
                  fontSize: 14,
                  color: secondaryText,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'خلاصه سلامت',
                style: TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: darkText,
                ),
              ),
            ],
          ),
        ),

        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black
                    .withOpacity(0.05),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: const Icon(
            Icons.notifications_none_rounded,
            color: darkText,
            size: 24,
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

  // ---------------------------------------------------------------------------
  // MONITORING CARD
  // ---------------------------------------------------------------------------

  Widget _buildMonitoringCard() {
    final active =
        widget.isMonitoringActive;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: active
              ? const [
            Color(0xFF42D2A7),
            Color(0xFF45C4D0),
          ]
              : const [
            Color(0xFF8D98A8),
            Color(0xFF6F7A89),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius:
        BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: (active
                ? primaryGreen
                : Colors.grey)
                .withOpacity(0.22),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white
                  .withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(
              active
                  ? Icons.radar_rounded
                  : Icons.radar_outlined,
              color: Colors.white,
              size: 28,
            ),
          ),

          const SizedBox(width: 15),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  active
                      ? 'مانیتورینگ فعال است'
                      : 'مانیتورینگ فعال نیست',
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Vazirmatn',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  active
                      ? 'S در حال بررسی وضعیت بدن و محیط اطراف توست.'
                      : 'برای ثبت اطلاعات سلامت، مانیتورینگ را فعال کن.',
                  style: TextStyle(
                    color: Colors.white
                        .withOpacity(0.9),
                    fontFamily: 'Vazirmatn',
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                if (active)
                  BoxShadow(
                    color: Colors.white
                        .withOpacity(0.5),
                    blurRadius: 8,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HEALTH OVERVIEW
  // ---------------------------------------------------------------------------

  Widget _buildHealthOverview() {
    final score = _healthScore;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withOpacity(0.035),
            blurRadius: 25,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 112,
            height: 112,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 105,
                  height: 105,
                  child: CircularProgressIndicator(
                    value: score / 100,
                    strokeWidth: 10,
                    backgroundColor:
                    primaryGreen
                        .withOpacity(0.10),
                    valueColor:
                    const AlwaysStoppedAnimation(
                      primaryGreen,
                    ),
                    strokeCap:
                    StrokeCap.round,
                  ),
                ),
                Column(
                  mainAxisSize:
                  MainAxisSize.min,
                  children: [
                    Text(
                      '$score',
                      style: const TextStyle(
                        fontFamily:
                        'Vazirmatn',
                        fontSize: 28,
                        fontWeight:
                        FontWeight.w800,
                        color: darkText,
                      ),
                    ),
                    const Text(
                      'امتیاز',
                      style: TextStyle(
                        fontFamily:
                        'Vazirmatn',
                        fontSize: 11,
                        color:
                        secondaryText,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 20),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                const Text(
                  'وضعیت کلی امروز',
                  style: TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 13,
                    color: secondaryText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _statusTitle,
                  style: const TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: darkText,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  _statusSubtitle,
                  style: const TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 11,
                    color: secondaryText,
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

  // ---------------------------------------------------------------------------
  // SECTION TITLE
  // ---------------------------------------------------------------------------

  Widget _buildSectionTitle(
      String title,
      String subtitle,
      ) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: darkText,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontSize: 11,
                  color: secondaryText,
                ),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: widget.onOpenPosture,
          child: const Text(
            'جزئیات',
            style: TextStyle(
              fontFamily: 'Vazirmatn',
              color: primaryGreen,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // METRIC GRID
  // ---------------------------------------------------------------------------

  Widget _buildMetricGrid() {
    final data = _today;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: 'گردن',
                value:
                _formatMinutes(
                  data?.neck ?? 0,
                ),
                subtitle: 'زمان وضعیت نامناسب',
                icon:
                Icons.accessibility_new_rounded,
                color: primaryGreen,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                title: 'قوز کردن',
                value:
                _formatMinutes(
                  data?.hunch ?? 0,
                ),
                subtitle: 'زمان وضعیت نامناسب',
                icon:
                Icons.airline_seat_recline_normal_rounded,
                color: teal,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: 'مچ دست',
                value:
                _formatMinutes(
                  data?.wrist ?? 0,
                ),
                subtitle: 'زمان وضعیت نامناسب',
                icon:
                Icons.back_hand_rounded,
                color:
                const Color(0xFFFFA62B),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                title: 'فاصله',
                value:
                _formatMinutes(
                  data?.tooClose ?? 0,
                ),
                subtitle: 'نزدیک بودن به صفحه',
                icon:
                Icons.phone_android_rounded,
                color:
                const Color(0xFF8B7CF6),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        _buildLightCard(),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(20),
        border: Border.all(
          color: Colors.black
              .withOpacity(0.035),
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color
                      .withOpacity(0.10),
                  borderRadius:
                  BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontSize: 12,
                  fontWeight:
                  FontWeight.bold,
                  color: darkText,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: darkText,
            ),
          ),

          const SizedBox(height: 2),

          Text(
            subtitle,
            style: const TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 9,
              color: secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLightCard() {
    final value = _today?.badLight ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 15,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(20),
        border: Border.all(
          color: Colors.black
              .withOpacity(0.035),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(
                0xFFFFC857,
              ).withOpacity(0.12),
              borderRadius:
              BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.light_mode_rounded,
              color: Color(0xFFFFB020),
            ),
          ),

          const SizedBox(width: 13),

          const Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  'نور نامناسب',
                  style: TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: darkText,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'مدت زمانی که نور محیط مناسب نبوده',
                  style: TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 9,
                    color: secondaryText,
                  ),
                ),
              ],
            ),
          ),

          Text(
            _formatMinutes(value),
            style: const TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: darkText,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // QUICK ACTIONS
  // ---------------------------------------------------------------------------

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        const Text(
          'دسترسی سریع',
          style: TextStyle(
            fontFamily: 'Vazirmatn',
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: darkText,
          ),
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                title: 'تحلیل وضعیت بدن',
                subtitle: 'مشاهده جزئیات',
                icon:
                Icons.accessibility_new_rounded,
                color: primaryGreen,
                onTap:
                widget.onOpenPosture,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: _buildActionCard(
                title: 'تمرین امروز',
                subtitle: 'حرکت مناسب تو',
                icon:
                Icons.fitness_center_rounded,
                color: teal,
                onTap:
                widget.onOpenExercise,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
        const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
          BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black
                  .withOpacity(0.025),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color
                    .withOpacity(0.10),
                borderRadius:
                BorderRadius.circular(13),
              ),
              child: Icon(
                icon,
                color: color,
                size: 22,
              ),
            ),

            const SizedBox(height: 14),

            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: 12,
                fontWeight:
                FontWeight.bold,
                color: darkText,
              ),
            ),

            const SizedBox(height: 3),

            Text(
              subtitle,
              style: const TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: 9,
                color: secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // RECOMMENDATION
  // ---------------------------------------------------------------------------

  Widget _buildRecommendation() {
    final data = _today;

    String title;
    String description;
    IconData icon;
    Color color;

    if (data == null) {
      title = 'مانیتورینگ را شروع کن';
      description =
      'با فعال بودن پایش، S می‌تواند وضعیت نشستن و شرایط محیطی تو را بررسی کند.';
      icon = Icons.radar_rounded;
      color = primaryGreen;
    } else if (data.hunch >= data.neck &&
        data.hunch >= data.wrist &&
        data.hunch >= data.tooClose) {
      title = 'امروز بیشتر به فرم نشستن توجه کن';
      description =
      'بیشترین زمان وضعیت نامناسب امروز مربوط به قوز کردن بوده است. چند دقیقه استراحت و اصلاح فرم می‌تواند کمک کند.';
      icon =
          Icons.airline_seat_recline_normal_rounded;
      color = teal;
    } else if (data.tooClose >=
        data.neck &&
        data.tooClose >= data.wrist) {
      title = 'کمی از صفحه فاصله بگیر';
      description =
      'امروز چند بار فاصله‌ات از صفحه کمتر از حد مناسب بوده. صفحه را کمی دورتر قرار بده.';
      icon = Icons.phone_android_rounded;
      color = const Color(0xFF8B7CF6);
    } else if (data.neck >= data.wrist) {
      title = 'به گردنت استراحت بده';
      description =
      'زمان قابل توجهی با وضعیت نامناسب گردن ثبت شده. شانه‌ها را رها کن و صفحه را بالاتر بیاور.';
      icon =
          Icons.accessibility_new_rounded;
      color = primaryGreen;
    } else {
      title = 'یک استراحت کوتاه برای مچ‌ها';
      description =
      'مچ دستت امروز تحت فشار بوده. چند حرکت ساده کششی انجام بده.';
      icon = Icons.back_hand_rounded;
      color = const Color(0xFFFFA62B);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius:
        BorderRadius.circular(22),
        border: Border.all(
          color: color.withOpacity(0.12),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 23,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                const Text(
                  'پیشنهاد S برای امروز',
                  style: TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 10,
                    color: secondaryText,
                    fontWeight:
                    FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 13,
                    fontWeight:
                    FontWeight.bold,
                    color: darkText,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: const TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 9,
                    height: 1.6,
                    color: secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  String _formatMinutes(double minutes) {
    if (minutes < 1) {
      return '${(minutes * 60).round()} ثانیه';
    }

    if (minutes < 60) {
      return '${minutes.round()} دقیقه';
    }

    final hours = minutes ~/ 60;
    final remaining =
        minutes.round() % 60;

    if (remaining == 0) {
      return '$hours ساعت';
    }

    return '$hours ساعت و $remaining دقیقه';
  }
}