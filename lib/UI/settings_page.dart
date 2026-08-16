import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import '../services/background_service.dart';
import '../backend/nsfw_detection.dart';

enum MonitoringMode {
  passive,
  overlay,
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with WidgetsBindingObserver {
  // ---------------------------------------------------------------------------
  // Same theme as ProfilePage
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // Preferences
  // ---------------------------------------------------------------------------

  static const String _monitoringEnabledKey = 'monitoring_enabled';
  static const String _monitoringModeKey = 'monitoring_mode';
  static const String _nsfwEnabledKey = 'nsfw_monitoring_enabled';

  bool _monitoringEnabled = false;
  MonitoringMode _monitoringMode = MonitoringMode.passive;
  bool _nsfwEnabled = false;

  bool _loading = true;
  bool _changingMonitoring = false;
  bool _changingNsfw = false;

  // Set right before we send the user to the system settings screen to
  // grant the overlay permission. requestPermission() returns as soon as
  // that screen opens, not once the user actually grants it and comes
  // back, so we watch for app resume and retry automatically instead of
  // requiring a second manual tap on the switch.
  bool _nsfwPermissionPending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _nsfwPermissionPending) {
      _nsfwPermissionPending = false;
      _retryNsfwEnableIfPermissionGranted();
    }
  }

  Future<void> _retryNsfwEnableIfPermissionGranted() async {
    final granted = await FlutterOverlayWindow.isPermissionGranted();

    if (granted && mounted && !_nsfwEnabled) {
      await _setNsfwEnabled(true);
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final mode = prefs.getString(_monitoringModeKey);

    bool monitoringEnabled =
        prefs.getBool(_monitoringEnabledKey) ?? false;

    // If the service is already running, reflect reality in the UI.
    final serviceRunning = await BackgroundMonitorService.isRunning;

    if (serviceRunning) {
      monitoringEnabled = true;
    }

    if (!mounted) return;

    setState(() {
      _monitoringEnabled = monitoringEnabled;
      _monitoringMode = mode == 'overlay'
          ? MonitoringMode.overlay
          : MonitoringMode.passive;
      _nsfwEnabled = prefs.getBool(_nsfwEnabledKey) ?? false;
      _loading = false;
    });
  }

  // ---------------------------------------------------------------------------
  // Monitoring
  // ---------------------------------------------------------------------------

  Future<void> _setMonitoringEnabled(bool enabled) async {
    if (_changingMonitoring) return;

    setState(() {
      _changingMonitoring = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool(
        _monitoringEnabledKey,
        enabled,
      );

      if (enabled) {
        await BackgroundMonitorService.initialize();
        BackgroundMonitorService.start();
      } else {
        BackgroundMonitorService.stop();

        // Also close any currently visible posture overlay.
        try {
          if (await FlutterOverlayWindow.isActive()) {
            await FlutterOverlayWindow.closeOverlay();
          }
        } catch (_) {}
      }

      if (!mounted) return;

      setState(() {
        _monitoringEnabled = enabled;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'خطا در تغییر وضعیت پایش: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _changingMonitoring = false;
        });
      }
    }
  }

  Future<void> _setMonitoringMode(
      MonitoringMode mode,
      ) async {
    if (!_monitoringEnabled) return;

    setState(() {
      _monitoringMode = mode;
    });

    await BackgroundMonitorService.setMonitoringMode(
      mode == MonitoringMode.overlay
          ? 'overlay'
          : 'passive',
    );
  }

  // ---------------------------------------------------------------------------
  // NSFW
  // ---------------------------------------------------------------------------

  Future<void> _setNsfwEnabled(bool enabled) async {
    if (_changingNsfw) return;

    setState(() {
      _changingNsfw = true;
    });

    try {
      final prefs =
      await SharedPreferences.getInstance();

      if (enabled) {
        final controller =
        NSFWDetectionController();

        final started =
        await controller.enable();

        if (!started) {
          await prefs.setBool(
            _nsfwEnabledKey,
            false,
          );

          if (!mounted) return;

          setState(() {
            _nsfwEnabled = false;
          });

          // The permission prompt (system Settings screen) is likely
          // still open or was just dismissed. Watch for the app coming
          // back to the foreground and retry automatically instead of
          // making the user flip this switch a second time.
          _nsfwPermissionPending = true;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'برای فعال کردن پایش محتوای نامناسب، '
                    'اجازه نمایش روی سایر برنامه‌ها را فعال کنید.',
              ),
            ),
          );

          return;
        }

        await prefs.setBool(
          _nsfwEnabledKey,
          true,
        );

        if (!mounted) return;

        setState(() {
          _nsfwEnabled = true;
        });
      } else {
        await NSFWDetectionController().disable();

        await prefs.setBool(
          _nsfwEnabledKey,
          false,
        );

        if (!mounted) return;

        setState(() {
          _nsfwEnabled = false;
        });
      }
    } catch (e) {
      debugPrint(
        '[Settings] NSFW toggle error: $e',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'فعال‌سازی پایش محتوای نامناسب با خطا مواجه شد.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _changingNsfw = false;
        });
      }
    }
  }
  // ---------------------------------------------------------------------------
  // UI helpers
  // ---------------------------------------------------------------------------

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: _buildCircleIconButton(
              Icons.arrow_forward_rounded,
            ),
          ),
          const Spacer(),
          const Text(
            'تنظیمات',
            style: TextStyle(
              color: kText,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          const SizedBox(
            width: 42,
            height: 42,
          ),
        ],
      ),
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
      child: Icon(
        icon,
        color: kText,
        size: 20,
      ),
    );
  }

  Widget _buildSectionTitle(
      String title, {
        String? subtitle,
      }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: kText,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                color: kSubtext,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCard({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(16),
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: padding,
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
        child: child,
      ),
    );
  }

  Widget _buildSwitch({
    required bool value,
    required ValueChanged<bool> onChanged,
    bool loading = false,
  }) {
    return Switch.adaptive(
      value: value,
      onChanged: loading ? null : onChanged,
      activeColor: kPrimary,
      activeTrackColor: kMint,
      inactiveThumbColor: kSubtext,
      inactiveTrackColor: kLine,
    );
  }

  Widget _buildFeatureIcon({
    required IconData icon,
    Color color = kPrimaryDark,
    Color background = kMintSoft,
  }) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: color,
        size: 23,
      ),
    );
  }

  Widget _buildMonitoringCard() {
    return _buildCard(
      child: Column(
        children: [
          Row(
            children: [
              _buildFeatureIcon(
                icon: Icons.monitor_heart_outlined,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'پایش سلامت',
                      style: TextStyle(
                        color: kText,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'وضعیت بدن، فاصله از صفحه و نور محیط را پایش می‌کند.',
                      style: TextStyle(
                        color: kSubtext,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              _buildSwitch(
                value: _monitoringEnabled,
                loading: _changingMonitoring,
                onChanged: _setMonitoringEnabled,
              ),
            ],
          ),
          if (_monitoringEnabled) ...[
            const SizedBox(height: 18),
            Container(
              height: 1,
              color: kLine,
            ),
            const SizedBox(height: 16),
            _buildModeSelector(),
          ],
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'حالت پایش',
          style: TextStyle(
            color: kText,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: kMintSoft,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: kLine,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildModeButton(
                  mode: MonitoringMode.passive,
                  icon: Icons.visibility_off_outlined,
                  title: 'پایش پس‌زمینه',
                  subtitle: 'بدون هشدار شناور',
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildModeButton(
                  mode: MonitoringMode.overlay,
                  icon: Icons.picture_in_picture_alt_outlined,
                  title: 'حالت شناور',
                  subtitle: 'نمایش هشدار روی صفحه',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModeButton({
    required MonitoringMode mode,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final selected = _monitoringMode == mode;

    return GestureDetector(
      onTap: () => _setMonitoringMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: selected ? kCard : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
          boxShadow: selected
              ? const [
            BoxShadow(
              color: kShadow,
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ]
              : null,
          border: Border.all(
            color: selected ? kPrimary.withOpacity(0.35) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: selected ? kMint : kCard,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: selected ? kPrimaryDark : kSubtext,
                size: 19,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: selected ? kText : kSubtext,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: kSubtext,
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle_rounded,
                color: kPrimary,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    if (!_monitoringEnabled) {
      return _buildInfoCard(
        icon: Icons.pause_circle_outline_rounded,
        title: 'پایش خاموش است',
        description:
        'در حال حاضر اطلاعات جدیدی از وضعیت بدن و عادت‌های استفاده شما ثبت نمی‌شود.',
        color: kSubtext,
        background: kMintSoft,
      );
    }

    if (_monitoringMode == MonitoringMode.overlay) {
      return _buildInfoCard(
        icon: Icons.notifications_active_outlined,
        title: 'حالت شناور فعال است',
        description:
        'پایش در پس‌زمینه انجام می‌شود و هنگام تشخیص وضعیت نامناسب، هشدار روی صفحه نمایش داده می‌شود.',
        color: kPrimaryDark,
        background: kMintSoft,
      );
    }

    return _buildInfoCard(
      icon: Icons.sync_outlined,
      title: 'پایش پس‌زمینه فعال است',
      description:
      'داده‌ها در پس‌زمینه جمع‌آوری می‌شوند و برای تحلیل عادت‌ها و پیشنهاد تمرین‌های مناسب استفاده خواهند شد.',
      color: kPrimaryDark,
      background: kMintSoft,
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required Color background,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: color,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      color: kSubtext,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNsfwCard() {
    return _buildCard(
      child: Column(
        children: [
          Row(
            children: [
              _buildFeatureIcon(
                icon: Icons.shield_outlined,
                color: kPrimaryDark,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'پایش محتوای نامناسب',
                      style: TextStyle(
                        color: kText,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'صفحه نمایش را برای شناسایی محتوای نامناسب بررسی می‌کند.',
                      style: TextStyle(
                        color: kSubtext,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              _buildSwitch(
                value: _nsfwEnabled,
                loading: _changingNsfw,
                onChanged: _setNsfwEnabled,
              ),
            ],
          ),
          if (_nsfwEnabled) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kMintSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: kPrimaryDark,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'این قابلیت به اجازه ضبط صفحه و نمایش روی سایر برنامه‌ها نیاز دارد و تصاویر را برای تشخیص محتوای نامناسب به صورت دوره‌ای بررسی می‌کند.',
                      style: TextStyle(
                        color: kSubtext,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPrivacyCard() {
    return _buildCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFeatureIcon(
            icon: Icons.lock_outline_rounded,
            background: const Color(0xFFF5F7F6),
            color: kText,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'کنترل اطلاعات',
                  style: TextStyle(
                    color: kText,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'تنظیمات پایش روی همین دستگاه ذخیره می‌شوند. داده‌های پایش برای تحلیل عادت‌ها و قابلیت‌های سلامت Si استفاده خواهند شد.',
                  style: TextStyle(
                    color: kSubtext,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
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
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: kBg,
          body: Center(
            child: CircularProgressIndicator(
              color: kPrimary,
            ),
          ),
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
              SliverToBoxAdapter(
                child: _buildHeader(),
              ),

              SliverToBoxAdapter(
                child: _buildSectionTitle(
                  'پایش سلامت',
                  subtitle: 'نحوه عملکرد سیستم پایش Si را کنترل کنید',
                ),
              ),

              SliverToBoxAdapter(
                child: _buildMonitoringCard(),
              ),

              SliverToBoxAdapter(
                child: _buildStatusCard(),
              ),

              SliverToBoxAdapter(
                child: _buildSectionTitle(
                  'امنیت و سلامت دیجیتال',
                  subtitle: 'قابلیت‌های محافظتی Si را کنترل کنید',
                ),
              ),

              SliverToBoxAdapter(
                child: _buildNsfwCard(),
              ),

              SliverToBoxAdapter(
                child: _buildSectionTitle(
                  'حریم خصوصی',
                ),
              ),

              SliverToBoxAdapter(
                child: _buildPrivacyCard(),
              ),

              const SliverToBoxAdapter(
                child: SizedBox(height: 30),
              ),
            ],
          ),
        ),
      ),
    );
  }
}