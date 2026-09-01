import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InitialTour {
  static const String completionKey = 'initial_app_tour_completed';

  static Future<bool> hasCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(completionKey) ?? false;
  }

  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(completionKey);
  }

  static Future<void> maybeStart({
    required BuildContext context,
    required List<GlobalKey> navigationKeys,
    required GlobalKey dashboardScoreKey,
    required GlobalKey monitoringKey,
    required bool isFemale,
    required ValueChanged<int> onNavigate,
    required Future<void> Function() onOpenSettings,
    required Future<void> Function() onCloseSettings,
  }) async {
    final completed = await hasCompleted();

    if (completed || !context.mounted) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!context.mounted) return;

      await Future<void>.delayed(
        const Duration(milliseconds: 350),
      );

      if (!context.mounted) return;

      _show(
        context: context,
        navigationKeys: navigationKeys,
        dashboardScoreKey: dashboardScoreKey,
        monitoringKey: monitoringKey,
        isFemale: isFemale,
        onNavigate: onNavigate,
        onOpenSettings: onOpenSettings,
        onCloseSettings: onCloseSettings,
      );
    });
  }

  static void _show({
    required BuildContext context,
    required List<GlobalKey> navigationKeys,
    required GlobalKey dashboardScoreKey,
    required GlobalKey monitoringKey,
    required bool isFemale,
    required ValueChanged<int> onNavigate,
    required Future<void> Function() onOpenSettings,
    required Future<void> Function() onCloseSettings,
  }) {
    final overlay = Overlay.of(context, rootOverlay: true);

    final steps = <_TourStep>[
      _TourStep(
        title: 'مرکز سلامت تو',
        message:
            'اینجا وضعیت کلی سلامتت، امتیاز روزانه و مهم‌ترین اطلاعات امروز را یکجا می‌بینی.',
        targetKey: dashboardScoreKey,
      ),
      _TourStep(
        title: 'پایش بدن',
        message:
            'سی می‌تواند گردن، قوز، مچ، فاصله از صفحه و نور محیط را در پس‌زمینه بررسی و ثبت کند.',
        targetKey: monitoringKey,
      ),
      _TourStep(
        title: 'تحلیل وضعیت بدن',
        message:
            'در بخش «بدن» جزئیات هشدارها، روند روزهای اخیر و وضعیت هر بخش را بررسی کن.',
        targetKey: navigationKeys[1],
        beforeShow: () async => onNavigate(1),
      ),
      _TourStep(
        title: 'تمرین و حرکت',
        message:
            'از بخش «ورزش» برای تمرین‌های کوتاه و حرکات مناسب استفاده کن.',
        targetKey: navigationKeys[2],
        beforeShow: () async => onNavigate(2),
      ),
    ];

    if (isFemale && navigationKeys.length >= 5) {
      steps.add(
        _TourStep(
          title: 'سلامت و قاعدگی',
          message:
              'بخش «بانوان» برای ثبت علائم روزانه، پیگیری چرخه و مشاهده روند علائم طراحی شده است.',
          targetKey: navigationKeys[3],
          beforeShow: () async => onNavigate(3),
        ),
      );
    }

    final profileIndex = navigationKeys.length - 1;

    steps.add(
      _TourStep(
        title: 'پروفایل',
        message:
            'پروفایل یکی از مهم‌ترین بخش‌های برنامه است؛ اطلاعات حساب، مشخصات شخصی، کالیبراسیون و گزینه‌های حساب را از اینجا مدیریت می‌کنی.',
        targetKey: navigationKeys[profileIndex],
        beforeShow: () async => onNavigate(profileIndex),
      ),
    );

    steps.add(
      _TourStep(
        title: 'تنظیمات',
        message:
            'در تنظیمات کنترل‌های اصلی برنامه قرار دارند: پایش پس‌زمینه، حالت هشدار شناور، صداهای هشدار و صداهای اختصاصی، محافظت دیجیتال و مجوزها. این بخش را هر زمان خواستی می‌توانی دوباره بررسی کنی.',
        beforeShow: onOpenSettings,
        closeAfter: true,
      ),
    );

    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => _InitialTourOverlay(
        steps: steps,
        onFinish: () async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(completionKey, true);

          final needsClose = steps.isNotEmpty && steps.last.closeAfter;

          if (needsClose) {
            try {
              await onCloseSettings();
            } catch (_) {}
          }

          entry.remove();
        },
        onSkip: () async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(completionKey, true);

          final currentStepIsSettings =
              steps.isNotEmpty && steps.last.closeAfter;

          if (currentStepIsSettings) {
            try {
              await onCloseSettings();
            } catch (_) {}
          }

          entry.remove();
        },
      ),
    );

    overlay.insert(entry);
  }
}

class _TourStep {
  final String title;
  final String message;
  final GlobalKey? targetKey;
  final Future<void> Function()? beforeShow;
  final bool closeAfter;

  const _TourStep({
    required this.title,
    required this.message,
    this.targetKey,
    this.beforeShow,
    this.closeAfter = false,
  });
}

class _InitialTourOverlay extends StatefulWidget {
  final List<_TourStep> steps;
  final Future<void> Function() onFinish;
  final Future<void> Function() onSkip;

  const _InitialTourOverlay({
    required this.steps,
    required this.onFinish,
    required this.onSkip,
  });

  @override
  State<_InitialTourOverlay> createState() => _InitialTourOverlayState();
}

class _InitialTourOverlayState extends State<_InitialTourOverlay> {
  static const green = Color(0xFF42D2A7);
  static const teal = Color(0xFF45C4D0);
  static const text = Color(0xFF263B37);
  static const subtext = Color(0xFF7D8D89);

  int index = 0;
  Rect? targetRect;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _prepareStep();
  }

  Future<void> _prepareStep() async {
    final step = widget.steps[index];

    if (step.beforeShow != null) {
      await step.beforeShow!();
    }

    if (!mounted) return;

    await Future<void>.delayed(
      const Duration(milliseconds: 80),
    );

    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateTargetRect();
    });
  }

  void _updateTargetRect() {
    final key = widget.steps[index].targetKey;

    if (key == null || key.currentContext == null) {
      if (targetRect != null) {
        setState(() => targetRect = null);
      }
      return;
    }

    final renderObject = key.currentContext!.findRenderObject();

    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return;
    }

    final rect = renderObject.localToGlobal(Offset.zero) &
        renderObject.size;

    if (rect != targetRect) {
      setState(() => targetRect = rect);
    }
  }

  Future<void> _next() async {
    if (busy) return;

    setState(() => busy = true);

    try {
      if (index >= widget.steps.length - 1) {
        await widget.onFinish();
        return;
      }

      setState(() {
        index += 1;
        targetRect = null;
      });

      await _prepareStep();
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> _skip() async {
    if (busy) return;

    setState(() => busy = true);

    try {
      await widget.onSkip();
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final step = widget.steps[index];

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _SpotlightPainter(
                targetRect: targetRect,
              ),
            ),
          ),
          _buildHintCard(size, step),
        ],
      ),
    );
  }

  Widget _buildHintCard(
    Size size,
    _TourStep step,
  ) {
    const horizontalMargin = 18.0;
    const cardWidth = 340.0;

    final width = size.width < cardWidth + 36
        ? size.width - 36
        : cardWidth;

    double top;

    if (targetRect == null) {
      top = (size.height - 190) / 2;
    } else {
      final below = targetRect!.bottom + 18;
      final above = targetRect!.top - 170;

      if (below + 160 <= size.height - 20) {
        top = below;
      } else {
        top = above.clamp(20.0, size.height - 180);
      }
    }

    final left = (size.width - width) / 2;

    return Positioned(
      left: left.clamp(horizontalMargin, size.width - width - horizontalMargin),
      top: top,
      width: width,
      child: _hintCard(step),
    );
  }

  Widget _hintCard(_TourStep step) {
    final last = index == widget.steps.length - 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 15),
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
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [green, teal],
                    ),
                    borderRadius: BorderRadius.circular(12),
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
                  '${index + 1}/${widget.steps.length}',
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
            const SizedBox(height: 14),
            Row(
              children: [
                TextButton(
                  onPressed: busy ? null : _skip,
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
                  onPressed: busy ? null : _next,
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
                    last ? 'شروع کنیم' : 'بعدی',
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
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final Rect? targetRect;

  const _SpotlightPainter({required this.targetRect});

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
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect;
  }
}
