import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'calibration_screen.dart';
import 'dashboard.dart';
import 'settings_page.dart';

class InitialTourPage extends StatefulWidget {
  final String userGender;
  final bool needsCalibration;

  const InitialTourPage({
    super.key,
    required this.userGender,
    required this.needsCalibration,
  });

  @override
  State<InitialTourPage> createState() => _InitialTourPageState();
}

class _InitialTourPageState extends State<InitialTourPage> {
  bool _ready = false;
  bool _completed = false;
  OverlayEntry? _entry;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    final completed = await InitialTour.hasCompleted();

    if (!mounted) return;

    setState(() {
      _ready = true;
      _completed = completed;
    });

    if (completed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _goToDestination();
      });
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(
        const Duration(milliseconds: 350),
      );

      if (mounted) {
        _showTour();
      }
    });
  }

  void _showTour() {
    if (!mounted || _entry != null) return;

    final overlay = Overlay.of(context, rootOverlay: true);

    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => _InitialTourOverlay(
        userGender: widget.userGender,
        onFinished: () async {
          await InitialTour.markCompleted();

          entry.remove();
          _entry = null;

          if (mounted) {
            await _goToDestination();
          }
        },
        onSkipped: () async {
          await InitialTour.markCompleted();

          entry.remove();
          _entry = null;

          if (mounted) {
            await _goToDestination();
          }
        },
      ),
    );

    _entry = entry;
    overlay.insert(entry);
  }

  Future<void> _goToDestination() async {
    if (!mounted) return;

    if (widget.needsCalibration) {
      try {
        final cameras = await availableCameras();

        if (!mounted) return;

        if (cameras.isNotEmpty) {
          await Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => CalibrationScreen(
                cameras: cameras,
              ),
            ),
          );
          return;
        }
      } catch (e) {
        debugPrint(
          '[InitialTour] Failed to open calibration: $e',
        );
      }
    }

    if (!mounted) return;

    await Navigator.pushReplacementNamed(
      context,
      '/dashboard',
      arguments: widget.userGender,
    );
  }

  @override
  void dispose() {
    _entry?.remove();
    _entry = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        backgroundColor: Color(0xFFF4F9F7),
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF42D2A7),
          ),
        ),
      );
    }

    if (_completed) {
      return const Scaffold(
        backgroundColor: Color(0xFFF4F9F7),
      );
    }

    return MainNavigationScreen(
      userGender: widget.userGender,
    );
  }
}

class InitialTour {
  static const String completionKey =
      'initial_app_tour_completed';

  static Future<bool> hasCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(completionKey) ?? false;
  }

  static Future<void> markCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(completionKey, true);
  }

  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(completionKey);
  }
}

class _InitialTourOverlay extends StatefulWidget {
  final String userGender;
  final Future<void> Function() onFinished;
  final Future<void> Function() onSkipped;

  const _InitialTourOverlay({
    required this.userGender,
    required this.onFinished,
    required this.onSkipped,
  });

  @override
  State<_InitialTourOverlay> createState() =>
      _InitialTourOverlayState();
}

class _TourStep {
  final String title;
  final String message;
  final _TourTarget target;
  final int? navigationIndex;
  final bool openSettings;

  const _TourStep({
    required this.title,
    required this.message,
    required this.target,
    this.navigationIndex,
    this.openSettings = false,
  });
}

enum _TourTarget {
  dashboardSummary,
  monitoring,
  navigation,
  settings,
}

class _InitialTourOverlayState extends State<_InitialTourOverlay> {
  static const green = Color(0xFF42D2A7);
  static const teal = Color(0xFF45C4D0);
  static const text = Color(0xFF263B37);
  static const subtext = Color(0xFF7D8D89);

  late final List<_TourStep> _steps;

  int _index = 0;
  Rect? _targetRect;
  bool _busy = false;
  bool _settingsOpened = false;

  @override
  void initState() {
    super.initState();

    final female = widget.userGender == 'female';

    _steps = [
      const _TourStep(
        title: 'مرکز سلامت تو',
        message:
            'اینجا خلاصه وضعیت روزانه، امتیاز سلامت و اطلاعات مهم مربوط به استفاده از گوشی را می‌بینی. این صفحه نقطه شروع اصلی سی است.',
        target: _TourTarget.dashboardSummary,
      ),
      const _TourStep(
        title: 'پایش بدن',
        message:
            'سی می‌تواند گردن، قوز، مچ دست، فاصله از صفحه و نور محیط را در پس‌زمینه بررسی و ثبت کند. وضعیت فعال بودن پایش را از این قسمت متوجه می‌شوی.',
        target: _TourTarget.monitoring,
      ),
      const _TourStep(
        title: 'تحلیل وضعیت بدن',
        message:
            'برای دیدن جزئیات هشدارها و روند وضعیت بدنی، تب «بدن» را انتخاب کن.',
        target: _TourTarget.navigation,
        navigationIndex: 1,
      ),
      const _TourStep(
        title: 'تمرین و حرکت',
        message:
            'در «ورزش» می‌توانی تمرین‌های کوتاه و حرکات مناسب را پیدا کنی. هر زمان احساس خستگی یا فشار کردی، این بخش را به یاد داشته باش.',
        target: _TourTarget.navigation,
        navigationIndex: 2,
      ),
      if (female)
        const _TourStep(
          title: 'سلامت و قاعدگی',
          message:
              'در بخش «بانوان» می‌توانی چرخه، علائم روزانه و روند تغییراتت را ثبت و دنبال کنی.',
          target: _TourTarget.navigation,
          navigationIndex: 3,
        ),
      _TourStep(
        title: 'پروفایل',
        message:
            'پروفایل یکی از مهم‌ترین بخش‌های برنامه است. اطلاعات حساب، مشخصات شخصی، وضعیت کالیبراسیون و گزینه‌های مرتبط با حساب کاربری را از اینجا مدیریت می‌کنی.',
        target: _TourTarget.navigation,
        navigationIndex: female ? 4 : 3,
      ),
      const _TourStep(
        title: 'تنظیمات',
        message:
            'در تنظیمات کنترل‌های اصلی سی قرار دارند: پایش پس‌زمینه، حالت هشدار شناور، صدای هشدارها و صداهای اختصاصی، محافظت دیجیتال و مجوزها. این صفحه را باز کرده‌ایم تا جای آن را هم بشناسی.',
        target: _TourTarget.settings,
        openSettings: true,
      ),
    ];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prepareStep();
    });
  }

  Future<void> _prepareStep() async {
    final step = _steps[_index];

    if (step.openSettings && !_settingsOpened) {
      _settingsOpened = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const SettingsPage(),
          ),
        );
      });
    }

    if (!mounted) return;

    await Future<void>.delayed(
      const Duration(milliseconds: 120),
    );

    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _calculateTarget();
      }
    });
  }

  void _calculateTarget() {
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.viewPaddingOf(context);
    final step = _steps[_index];

    Rect rect;

    switch (step.target) {
      case _TourTarget.dashboardSummary:
        rect = Rect.fromLTWH(
          16,
          padding.top + 140,
          size.width - 32,
          math.min(255, size.height * 0.34),
        );
        break;

      case _TourTarget.monitoring:
        rect = Rect.fromLTWH(
          16,
          padding.top + 67,
          size.width - 32,
          95,
        );
        break;

      case _TourTarget.navigation:
        rect = _navigationTarget(
          size,
          padding,
          step.navigationIndex ?? 0,
        );
        break;

      case _TourTarget.settings:
        rect = Rect.fromLTWH(
          16,
          padding.top + 76,
          size.width - 32,
          math.min(190, size.height * 0.27),
        );
        break;
    }

    if (_targetRect != rect) {
      setState(() {
        _targetRect = rect;
      });
    }
  }

  Rect _navigationTarget(
    Size size,
    EdgeInsets padding,
    int index,
  ) {
    const horizontal = 14.0;
    const bottomPadding = 12.0;
    const barHeight = 68.0;

    final count = widget.userGender == 'female' ? 5 : 4;
    final availableWidth =
        size.width - (horizontal * 2);
    final itemWidth = availableWidth / count;

    final bottom = math.max(
      padding.bottom + bottomPadding,
      12,
    );

    return Rect.fromLTWH(
      horizontal + itemWidth * index + 3,
      size.height - bottom - barHeight - 3,
      itemWidth - 6,
      barHeight,
    );
  }

  Future<void> _next() async {
    if (_busy) return;

    setState(() => _busy = true);

    try {
      if (_index == _steps.length - 1) {
        if (_settingsOpened && mounted) {
          Navigator.of(context).pop();
        }

        await widget.onFinished();
        return;
      }

      setState(() {
        _index += 1;
        _targetRect = null;
      });

      await _prepareStep();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _skip() async {
    if (_busy) return;

    setState(() => _busy = true);

    try {
      if (_settingsOpened && mounted) {
        Navigator.of(context).pop();
      }

      await widget.onSkipped();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final step = _steps[_index];

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _TourSpotlightPainter(
                  targetRect: _targetRect,
                ),
              ),
            ),
          ),
          _buildHint(size, step),
        ],
      ),
    );
  }

  Widget _buildHint(Size size, _TourStep step) {
    final width = math.min(340.0, size.width - 32);

    double top;

    if (_targetRect == null) {
      top = (size.height - 190) / 2;
    } else if (_targetRect!.top > size.height * 0.55) {
      top = (_targetRect!.top - 205).clamp(
        20.0,
        size.height - 185,
      );
    } else {
      top = (_targetRect!.bottom + 18).clamp(
        20.0,
        size.height - 185,
      );
    }

    return Positioned(
      left: (size.width - width) / 2,
      top: top,
      width: width,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          18,
          16,
          18,
          15,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 30,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [green, teal],
                      ),
                      borderRadius:
                          BorderRadius.all(
                        Radius.circular(12),
                      ),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      step.title,
                      style: const TextStyle(
                        color: text,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    '${_index + 1}/${_steps.length}',
                    style: const TextStyle(
                      color: subtext,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                step.message,
                style: const TextStyle(
                  color: subtext,
                  fontSize: 11,
                  height: 1.65,
                ),
              ),
              if (step.navigationIndex != null) ...[
                const SizedBox(height: 8),
                const Text(
                  'برای دیدن این بخش می‌توانی روی تب مشخص‌شده بزنـی؛ سپس «بعدی» را انتخاب کن.',
                  style: TextStyle(
                    color: subtext,
                    fontSize: 9,
                    height: 1.5,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  TextButton(
                    onPressed: _busy ? null : _skip,
                    child: const Text(
                      'رد کردن تور',
                      style: TextStyle(
                        color: subtext,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _busy ? null : _next,
                    style: FilledButton.styleFrom(
                      backgroundColor: green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _index == _steps.length - 1
                          ? 'شروع کنیم'
                          : 'بعدی',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
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
  }
}

class _TourSpotlightPainter extends CustomPainter {
  final Rect? targetRect;

  const _TourSpotlightPainter({required this.targetRect});

  @override
  void paint(Canvas canvas, Size size) {
    final dimPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.62)
      ..style = PaintingStyle.fill;

    if (targetRect == null) {
      canvas.drawRect(
        Offset.zero & size,
        dimPaint,
      );
      return;
    }

    final spotlight = targetRect!.inflate(8);

    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(
        RRect.fromRectAndRadius(
          spotlight,
          const Radius.circular(18),
        ),
      );

    canvas.drawPath(path, dimPaint);

    final borderPaint = Paint()
      ..color = const Color(0xFFEFFFF9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        spotlight,
        const Radius.circular(18),
      ),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _TourSpotlightPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect;
  }
}
