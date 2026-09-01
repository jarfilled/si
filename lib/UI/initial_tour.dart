import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'calibration_screen.dart';
import 'dashboard.dart';

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
  bool _settingsOpened = false;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    // The tour intentionally runs on every successful login.
    // Keep the legacy completion check in place only so older code that
    // references InitialTour.hasCompleted() still compiles.
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
        hostContext: context,
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
        onSettingsOpened: () async {
          _settingsOpened = true;
          await InitialTour.markCompleted();

          if (_entry != null) {
            _entry!.remove();
            _entry = null;
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

    if (_completed || _settingsOpened) {
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
  static const String completionKey = 'initial_app_tour_completed';

  static Future<bool> hasCompleted() async {
    // Deliberately false: the onboarding tour is shown on every login.
    return false;
  }

  static Future<void> markCompleted() async {
    // Kept as a compatibility no-op. The tour is intentionally not persisted.
  }

  static Future<void> reset() async {}
}

class _InitialTourOverlay extends StatefulWidget {
  final String userGender;
  final BuildContext hostContext;
  final Future<void> Function() onFinished;
  final Future<void> Function() onSkipped;
  final Future<void> Function() onSettingsOpened;

  const _InitialTourOverlay({
    required this.userGender,
    required this.hostContext,
    required this.onFinished,
    required this.onSkipped,
    required this.onSettingsOpened,
  });

  @override
  State<_InitialTourOverlay> createState() => _InitialTourOverlayState();
}

class _TourStep {
  final String title;
  final String message;
  final _TourTarget target;
  final String? textTarget;
  final String? textPrefix;
  final int? navigationIndex;
  final bool clickableTarget;
  final bool settingsEntry;

  const _TourStep({
    required this.title,
    required this.message,
    required this.target,
    this.textTarget,
    this.textPrefix,
    this.navigationIndex,
    this.clickableTarget = true,
    this.settingsEntry = false,
  });
}

enum _TourTarget {
  dashboardSummary,
  monitoring,
  navigation,
  settingsEntry,
}

class _InitialTourOverlayState extends State<_InitialTourOverlay> {
  static const green = Color(0xFF42D2A7);
  static const teal = Color(0xFF45C4D0);
  static const text = Color(0xFF263B37);
  static const subtext = Color(0xFF7D8D89);

  late final List<_TourStep> _steps;

  int _index = 0;
  Rect? _targetRect;
  Element? _targetElement;
  bool _busy = false;

  @override
  void initState() {
    super.initState();

    final female = widget.userGender == 'female';

    // Exact navigation order:
    // male   = سلامت - بدن - ورزش - پروفایل
    // female = سلامت - بدن - ورزش - بانوان - پروفایل
    _steps = [
      const _TourStep(
        title: 'مرکز سلامت تو',
        message:
            'اینجا خلاصه وضعیت روزانه، امتیاز سلامت و مهم‌ترین اطلاعات امروز را می‌بینی.',
        target: _TourTarget.dashboardSummary,
        textTarget: 'امتیاز سلامت امروز',
      ),
      const _TourStep(
        title: 'پایش بدن',
        message:
            'سی می‌تواند گردن، قوز، مچ دست، فاصله از صفحه و نور محیط را در پس‌زمینه بررسی و ثبت کند.',
        target: _TourTarget.monitoring,
        textPrefix: 'پایش فعال',
      ),
      const _TourStep(
        title: 'تحلیل وضعیت بدن',
        message:
            'برای دیدن جزئیات هشدارها و روند وضعیت بدنی، روی تب «بدن» بزن.',
        target: _TourTarget.navigation,
        textTarget: 'بدن',
        navigationIndex: 1,
      ),
      const _TourStep(
        title: 'تمرین و حرکت',
        message:
            'در «ورزش» می‌توانی تمرین‌های کوتاه و حرکات مناسب را پیدا کنی.',
        target: _TourTarget.navigation,
        textTarget: 'ورزش',
        navigationIndex: 2,
      ),
      if (female)
        const _TourStep(
          title: 'سلامت و قاعدگی',
          message:
              'در بخش «بانوان» می‌توانی چرخه، علائم روزانه و روند تغییراتت را ثبت و دنبال کنی.',
          target: _TourTarget.navigation,
          textTarget: 'بانوان',
          navigationIndex: 3,
        ),
      _TourStep(
        title: 'پروفایل',
        message:
            'پروفایل یکی از مهم‌ترین بخش‌های برنامه است؛ اطلاعات حساب، مشخصات شخصی و کالیبراسیون را از اینجا مدیریت می‌کنی.',
        target: _TourTarget.navigation,
        textTarget: 'پروفایل',
        navigationIndex: female ? 4 : 3,
      ),
      const _TourStep(
        title: 'تنظیمات',
        message:
            'از داخل پروفایل وارد «تنظیمات پایش» می‌شوی. آنجا پایش پس‌زمینه، هشدار شناور، صداهای هشدار، صداهای اختصاصی، محافظت دیجیتال و مجوزها را کنترل می‌کنی.',
        target: _TourTarget.settingsEntry,
        textTarget: 'تنظیمات پایش',
        settingsEntry: true,
      ),
    ];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prepareStep();
    });
  }

  Future<void> _prepareStep() async {
    if (!mounted) return;

    setState(() {
      _targetRect = null;
      _targetElement = null;
    });

    await Future<void>.delayed(
      const Duration(milliseconds: 150),
    );

    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _calculateTarget();
      }
    });
  }

  void _calculateTarget() {
    final step = _steps[_index];

    Element? element;

    if (step.textTarget != null) {
      element = _findTextElement(
        step.textTarget!,
        prefix: step.textPrefix,
      );
    }

    if (element == null) {
      debugPrint(
        '[InitialTour] Target not found: '
        '${step.textTarget ?? step.textPrefix ?? step.target}',
      );
      return;
    }

    final targetAncestor = _targetAncestor(element, step.target);
    final renderElement = targetAncestor ?? element;
    final renderObject = renderElement.renderObject;

    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return;
    }

    final rect = renderObject.localToGlobal(Offset.zero) & renderObject.size;

    if (!mounted) return;

    setState(() {
      _targetElement = renderElement;
      _targetRect = rect;
    });
  }

  Element? _findTextElement(
    String target, {
    String? prefix,
  }) {
    Element? found;

    void visit(Element element) {
      if (found != null) return;

      final childWidget = element.widget;

      if (childWidget is Text) {
        final data = childWidget.data ?? '';

        if ((prefix != null && data.startsWith(prefix)) ||
            (prefix == null && data == target)) {
          found = element;
          return;
        }
      }

      element.visitChildElements(visit);
    }

    widget.hostContext.visitChildElements(visit);
    return found;
  }

  Element? _targetAncestor(
    Element element,
    _TourTarget target,
  ) {
    Element? found;

    bool wantsWidget(Widget widget) {
      switch (target) {
        case _TourTarget.navigation:
        case _TourTarget.settingsEntry:
          return widget is InkWell;
        case _TourTarget.dashboardSummary:
        case _TourTarget.monitoring:
          return widget is Container;
      }
    }

    element.visitAncestorElements((ancestor) {
      if (wantsWidget(ancestor.widget)) {
        found = ancestor;
        return false;
      }
      return true;
    });

    return found;
  }

  Future<void> _handleOverlayTap(TapUpDetails details) async {
    if (_busy || _targetRect == null) return;

    if (!_targetRect!.contains(details.globalPosition)) {
      return;
    }

    final step = _steps[_index];

    setState(() => _busy = true);

    try {
      if (step.settingsEntry) {
        await _invokeTargetTap();
        await widget.onSettingsOpened();
        return;
      }

      if (step.target == _TourTarget.navigation ||
          step.settingsEntry) {
        await _invokeTargetTap();
      }

      if (_index >= _steps.length - 1) {
        await widget.onFinished();
        return;
      }

      setState(() {
        _index += 1;
        _targetRect = null;
        _targetElement = null;
      });

      await _prepareStep();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _invokeTargetTap() async {
    final element = _targetElement;

    if (element == null) return;

    final inkElement = _findAncestorInkWell(element);

    if (inkElement == null) {
      return;
    }

    final widget = inkElement.widget;

    if (widget is InkWell && widget.onTap != null) {
      widget.onTap!();
      await Future<void>.delayed(
        const Duration(milliseconds: 220),
      );
    }
  }

  Element? _findAncestorInkWell(Element start) {
    Element? found;

    start.visitAncestorElements((ancestor) {
      if (ancestor.widget is InkWell) {
        found = ancestor;
        return false;
      }
      return true;
    });

    return found;
  }

  Future<void> _skip() async {
    if (_busy) return;

    setState(() => _busy = true);

    try {
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
            child: CustomPaint(
              painter: _TourSpotlightPainter(
                targetRect: _targetRect,
              ),
            ),
          ),

          // The overlay intentionally receives all pointer input.
          // This prevents scrolling the dashboard and moving the spotlight.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: _handleOverlayTap,
              child: const SizedBox.expand(),
            ),
          ),

          _buildHint(size, step),
        ],
      ),
    );
  }

  Widget _buildHint(Size size, _TourStep step) {
    final width = math.min(
      340.0,
      size.width - 32.0,
    ).toDouble();

    double top;

    if (_targetRect == null) {
      top = (size.height - 205.0) / 2.0;
    } else if (_targetRect!.top > size.height * 0.55) {
      top = (_targetRect!.top - 225.0)
          .clamp(20.0, math.max(20.0, size.height - 205.0))
          .toDouble();
    } else {
      top = (_targetRect!.bottom + 18.0)
          .clamp(20.0, math.max(20.0, size.height - 205.0))
          .toDouble();
    }

    return Positioned(
      left: (size.width - width) / 2.0,
      top: top,
      width: width,
      child: IgnorePointer(
        ignoring: false,
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
              crossAxisAlignment: CrossAxisAlignment.start,
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
                        borderRadius: BorderRadius.all(
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
                const SizedBox(height: 9),
                Row(
                  children: [
                    const Icon(
                      Icons.touch_app_rounded,
                      color: green,
                      size: 16,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        step.settingsEntry
                            ? 'برای باز کردن تنظیمات روی گزینه مشخص‌شده بزن.'
                            : step.target == _TourTarget.navigation
                                ? 'روی تب مشخص‌شده بزن تا وارد این بخش شوی.'
                                : 'روی بخش مشخص‌شده بزن تا به مرحله بعد برویم.',
                        style: const TextStyle(
                          color: green,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
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
                    Text(
                      step.settingsEntry
                          ? 'آخرین مرحله'
                          : 'روی بخش مشخص‌شده بزن',
                      style: const TextStyle(
                        color: subtext,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
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
