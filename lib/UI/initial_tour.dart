import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'calibration_screen.dart';
import 'dashboard.dart';
import 'profile_page.dart';

class InitialTourPage extends StatefulWidget {
  final String userGender;
  final bool needsCalibration;

  const InitialTourPage({super.key, required this.userGender, required this.needsCalibration});

  @override
  State<InitialTourPage> createState() => _InitialTourPageState();
}

class _InitialTourPageState extends State<InitialTourPage> {
  OverlayEntry? _entry;
  bool _ready = false;
  bool _completed = false;
  bool _settingsOpened = false;

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
      WidgetsBinding.instance.addPostFrameCallback((_) => _goToDestination());
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (mounted) _showTour();
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
          if (mounted) await _goToDestination();
        },
        onSkipped: () async {
          await InitialTour.markCompleted();
          entry.remove();
          _entry = null;
          if (mounted) await _goToDestination();
        },
        onSettingsOpened: () async {
          _settingsOpened = true;
          await InitialTour.markCompleted();
          entry.remove();
          _entry = null;
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
            MaterialPageRoute(builder: (_) => CalibrationScreen(cameras: cameras)),
          );
          return;
        }
      } catch (e) {
        debugPrint('[InitialTour] Failed to open calibration: $e');
      }
    }
    if (!mounted) return;
    await Navigator.pushReplacementNamed(context, '/dashboard', arguments: widget.userGender);
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
        body: Center(child: CircularProgressIndicator(color: Color(0xFF42D2A7))),
      );
    }
    if (_completed || _settingsOpened) {
      return const Scaffold(backgroundColor: Color(0xFFF4F9F7));
    }
    return MainNavigationScreen(userGender: widget.userGender);
  }
}

class InitialTour {
  static const String completionKey = 'initial_app_tour_completed';
  static Future<bool> hasCompleted() async => false;
  static Future<void> markCompleted() async {}
  static Future<void> reset() async {}
}

class _TourStep {
  final String title;
  final String message;
  final _TourTarget target;
  final String? textTarget;
  final String? textPrefix;
  final IconData? iconTarget;
  final bool settingsEntry;
  final String? keyTarget;

  const _TourStep({
    required this.title,
    required this.message,
    required this.target,
    this.textTarget,
    this.textPrefix,
    this.iconTarget,
    this.settingsEntry = false,
    this.keyTarget,
  });
}

enum _TourTarget { dashboardSummary, monitoring, navigation, settingsEntry }

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
    _steps = [
      const _TourStep(
        title: 'مرکز سلامت تو',
        message: 'اینجا خلاصه وضعیت روزانه، امتیاز سلامت و مهم‌ترین اطلاعات امروز را می‌بینی.',
        target: _TourTarget.dashboardSummary,
        textTarget: 'امتیاز سلامت امروز',
      ),
      const _TourStep(
        title: 'پایش بدن',
        message: 'سی می‌تواند گردن، قوز، مچ دست، فاصله از صفحه و نور محیط را در پس‌زمینه بررسی و ثبت کند.',
        target: _TourTarget.monitoring,
        iconTarget: Icons.radar_rounded,
      ),
      const _TourStep(
        title: 'تحلیل وضعیت بدن',
        message: 'برای دیدن جزئیات هشدارها و روند وضعیت بدنی، روی تب «بدن» بزن.',
        target: _TourTarget.navigation,
        keyTarget: 'tour-nav-بدن',
      ),
      const _TourStep(
        title: 'تمرین و حرکت',
        message: 'در «ورزش» می‌توانی تمرین‌های کوتاه و حرکات مناسب را پیدا کنی.',
        target: _TourTarget.navigation,
        keyTarget: 'tour-nav-ورزش',
      ),
      if (female)
        const _TourStep(
          title: 'سلامت و قاعدگی',
          message: 'در بخش «بانوان» می‌توانی چرخه، علائم روزانه و روند تغییراتت را ثبت و دنبال کنی.',
          target: _TourTarget.navigation,
          keyTarget: 'tour-nav-بانوان',
        ),
      const _TourStep(
        title: 'پروفایل',
        message: 'پروفایل یکی از مهم‌ترین بخش‌های برنامه است؛ اطلاعات حساب، مشخصات شخصی و کالیبراسیون را از اینجا مدیریت می‌کنی.',
        target: _TourTarget.navigation,
        keyTarget: 'tour-nav-پروفایل',
      ),
      const _TourStep(
        title: 'تنظیمات',
        message: 'از داخل پروفایل وارد «تنظیمات پایش» می‌شوی. آنجا پایش پس‌زمینه، هشدار شناور، صداها، محافظت دیجیتال و مجوزها را کنترل می‌کنی.',
        target: _TourTarget.settingsEntry,
        keyTarget: 'tour-settings-entry',
        settingsEntry: true,
      ),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepareStep());
  }

  Future<void> _prepareStep() async {
    if (!mounted) return;

    // The settings action is below the initial profile viewport. Because the
    // profile uses a lazy ListView, its row may not exist in the element tree
    // until we scroll. Put it on-screen before looking up the spotlight.
    if (_index == _steps.length - 1) {
      final profileState = ProfilePage.tourKey.currentState;
      if (profileState != null) {
        await profileState.ensureTourSettingsVisible();
      }
      await WidgetsBinding.instance.endOfFrame;
    }

    setState(() {
      _targetRect = null;
      _targetElement = null;
    });
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _calculateTarget();
    });
  }

  void _calculateTarget() {
    final step = _steps[_index];
    Element? element;
    if (step.settingsEntry) {
      element = ProfilePage.tourKey.currentState?.tourSettingsContext as Element?;
    } else if (step.keyTarget != null) {
      element = _findElementByKey(step.keyTarget!);
    } else if (step.iconTarget != null) {
      element = _findIconElement(step.iconTarget!);
    } else if (step.textTarget != null) {
      element = _findTextElement(step.textTarget!, prefix: step.textPrefix);
    }
    if (element == null) {
      debugPrint('[InitialTour] Target not found for step $_index');
      return;
    }
    final renderElement = step.target == _TourTarget.navigation || step.settingsEntry
        ? (_targetAncestor(element) ?? element)
        : element;
    final renderObject = renderElement.renderObject;
    if (renderObject is! RenderBox || !renderObject.hasSize) return;
    final rect = renderObject.localToGlobal(Offset.zero) & renderObject.size;
    if (!mounted) return;
    setState(() {
      _targetElement = renderElement;
      _targetRect = rect;
    });
  }

  Element? _findElementByKey(String value) {
    Element? found;
    void visit(Element element) {
      if (found != null) return;
      final key = element.widget.key;
      if (key is ValueKey<String> && key.value == value) {
        found = element;
        return;
      }
      element.visitChildElements(visit);
    }
    widget.hostContext.visitChildElements(visit);
    return found;
  }

  Element? _findTextElement(String target, {String? prefix}) {
    Element? found;
    void visit(Element element) {
      if (found != null) return;
      final w = element.widget;
      if (w is Text) {
        final data = w.data ?? '';
        if ((prefix != null && data.startsWith(prefix)) || (prefix == null && data == target)) {
          found = element;
          return;
        }
      }
      element.visitChildElements(visit);
    }
    widget.hostContext.visitChildElements(visit);
    return found;
  }

  Element? _findIconElement(IconData icon) {
    Element? found;
    void visit(Element element) {
      if (found != null) return;
      final w = element.widget;
      if (w is Icon && (w.icon == icon || (icon == Icons.radar_rounded && w.icon == Icons.radar_outlined))) {
        found = element;
        return;
      }
      element.visitChildElements(visit);
    }
    widget.hostContext.visitChildElements(visit);
    return found;
  }

  Element? _targetAncestor(Element element) {
    Element? found;
    element.visitAncestorElements((ancestor) {
      if (ancestor.widget is InkWell) {
        found = ancestor;
        return false;
      }
      return true;
    });
    return found;
  }

  Future<void> _handleOverlayTap(TapUpDetails details) async {
    if (_busy || _targetRect == null || !_targetRect!.contains(details.globalPosition)) return;
    setState(() => _busy = true);
    try {
      final step = _steps[_index];
      if (step.target == _TourTarget.navigation) {
        final activated = await _invokeTargetTap();
        if (!activated) {
          debugPrint('[InitialTour] Navigation target was not activated.');
          return;
        }
        await WidgetsBinding.instance.endOfFrame;
        await Future<void>.delayed(const Duration(milliseconds: 280));
      } else if (step.settingsEntry) {
        final activated = await _invokeTargetTap();
        if (!activated) {
          debugPrint('[InitialTour] Settings target was not activated.');
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 350));
        await widget.onSettingsOpened();
        return;
      }

      if (_index >= _steps.length - 1) {
        await widget.onFinished();
        return;
      }

      setState(() {
        _index++;
        _targetRect = null;
        _targetElement = null;
      });
      await _prepareStep();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _invokeTargetTap() async {
    final element = _targetElement;
    if (element == null) return false;
    final inkElement = element.widget is InkWell ? element : _targetAncestor(element);
    if (inkElement == null) return false;
    final w = inkElement.widget;
    if (w is InkWell && w.onTap != null) {
      w.onTap!();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      return true;
    }
    return false;
  }

  Future<void> _skip() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onSkipped();
    } finally {
      if (mounted) setState(() => _busy = false);
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
          Positioned.fill(child: CustomPaint(painter: _TourSpotlightPainter(targetRect: _targetRect))),
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
    final width = math.min(340.0, size.width - 32.0).toDouble();
    final maxTop = math.max(20.0, size.height - 205.0);
    final top = _targetRect == null
        ? (size.height - 205.0) / 2.0
        : (_targetRect!.top > size.height * .55
            ? (_targetRect!.top - 225).clamp(20.0, maxTop).toDouble()
            : (_targetRect!.bottom + 18).clamp(20.0, maxTop).toDouble());
    final instruction = step.settingsEntry
        ? 'برای باز کردن تنظیمات روی گزینه مشخص‌شده بزن.'
        : step.target == _TourTarget.navigation
            ? 'روی تب مشخص‌شده بزن تا وارد این بخش شوی.'
            : step.iconTarget != null
                ? 'روی آیکون مشخص‌شده بزن تا به مرحله بعد برویم.'
                : 'روی بخش مشخص‌شده بزن تا به مرحله بعد برویم.';
    return Positioned(
      left: (size.width - width) / 2,
      top: top,
      width: width,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 30, offset: Offset(0, 12))],
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
                      gradient: LinearGradient(colors: [green, teal]),
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                    child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 19),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(step.title, style: const TextStyle(color: text, fontSize: 15, fontWeight: FontWeight.w900))),
                  Text('${_index + 1}/${_steps.length}', style: const TextStyle(color: subtext, fontSize: 10, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 10),
              Text(step.message, style: const TextStyle(color: subtext, fontSize: 11, height: 1.65)),
              const SizedBox(height: 9),
              Row(
                children: [
                  const Icon(Icons.touch_app_rounded, color: green, size: 16),
                  const SizedBox(width: 5),
                  Expanded(child: Text(instruction, style: const TextStyle(color: green, fontSize: 9, fontWeight: FontWeight.w800, height: 1.4))),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton(
                    onPressed: _busy ? null : _skip,
                    child: const Text('رد کردن تور', style: TextStyle(color: subtext, fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                  const Spacer(),
                  Text(step.settingsEntry ? 'آخرین مرحله' : 'روی بخش مشخص‌شده بزن', style: const TextStyle(color: subtext, fontSize: 9, fontWeight: FontWeight.w700)),
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
      ..color = Colors.black.withValues(alpha: .62)
      ..style = PaintingStyle.fill;
    if (targetRect == null) {
      canvas.drawRect(Offset.zero & size, dimPaint);
      return;
    }
    final spotlight = targetRect!.inflate(8);
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(spotlight, const Radius.circular(18)));
    canvas.drawPath(path, dimPaint);
    final borderPaint = Paint()
      ..color = const Color(0xFFEFFFF9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(RRect.fromRectAndRadius(spotlight, const Radius.circular(18)), borderPaint);
  }

  @override
  bool shouldRepaint(covariant _TourSpotlightPainter oldDelegate) => oldDelegate.targetRect != targetRect;
}
