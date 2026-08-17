import 'package:flutter/material.dart';
import '../backend/daily_health_metric.dart';
import '../backend/health_data_repository.dart';

class HealthSummaryPage extends StatefulWidget {
  const HealthSummaryPage({super.key});

  @override
  State<HealthSummaryPage> createState() => _HealthSummaryPageState();
}

class _HealthSummaryPageState extends State<HealthSummaryPage> {
  static const bg = Color(0xFFF4F9F7);
  static const green = Color(0xFF42D2A7);
  static const teal = Color(0xFF45C4D0);
  static const text = Color(0xFF263B37);
  static const subtext = Color(0xFF7D8D89);
  static const mint = Color(0xFFE8F8F1);
  static const line = Color(0xFFE8EFEC);

  bool loading = true;
  String? error;
  List<DailyHealthMetric> metrics = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await HealthDataRepository.instance.getDailyMetrics(days: 7);
      if (!mounted) return;
      setState(() {
        metrics = rows.map(DailyHealthMetric.fromMap).toList();
        loading = false;
        error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'داده‌های سلامت فعلاً در دسترس نیست.';
      });
    }
  }

  DailyHealthMetric? get today => metrics.isEmpty ? null : metrics.first;

  double get risk => today == null ? 0 : today!.neck + today!.hunch + today!.wrist + today!.tooClose + today!.badLight;

  int get score => today?.healthScore ?? (risk == 0 ? 0 : (100 - risk * .8).clamp(0, 100).round());

  String _minutes(double value) {
    if (value < 1) return '${(value * 60).round()} ثانیه';
    if (value < 60) return '${value.round()} دقیقه';
    final hours = value ~/ 60;
    final minutes = value.round() % 60;
    return minutes == 0 ? '$hours ساعت' : '$hours ساعت و $minutes دقیقه';
  }

  Widget _card({required Widget child, EdgeInsets padding = const EdgeInsets.all(18)}) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: line),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 20, offset: Offset(0, 7))],
      ),
      child: child,
    );
  }

  Widget _metric(String title, String value, IconData icon, Color color) {
    return _card(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: color.withValues(alpha: .10), shape: BoxShape.circle), child: Icon(icon, color: color, size: 20)),
          const SizedBox(height: 8),
          FittedBox(fit: BoxFit.scaleDown, child: Text(value, textAlign: TextAlign.center, maxLines: 1, style: const TextStyle(color: text, fontSize: 14, fontWeight: FontWeight.w900))),
          const SizedBox(height: 3),
          Text(title, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: subtext, fontSize: 9)),
        ],
      ),
    );
  }

  Widget _metricsSection(BoxConstraints constraints) {
    final compact = constraints.maxWidth < 390;
    final items = [
      _metric('گردن', _minutes(today?.neck ?? 0), Icons.accessibility_new_rounded, green),
      _metric('قوز', _minutes(today?.hunch ?? 0), Icons.airline_seat_recline_normal_rounded, teal),
      _metric('مچ', _minutes(today?.wrist ?? 0), Icons.back_hand_rounded, const Color(0xFFFFA62B)),
    ];

    if (compact) {
      return GridView.count(
        crossAxisCount: 3,
        crossAxisSpacing: 7,
        childAspectRatio: .82,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: items,
      );
    }

    return Row(children: [
      Expanded(child: items[0]),
      const SizedBox(width: 8),
      Expanded(child: items[1]),
      const SizedBox(width: 8),
      Expanded(child: items[2]),
    ]);
  }

  Widget _riskRow(String title, double value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(width: 38, height: 38, decoration: BoxDecoration(color: color.withValues(alpha: .10), shape: BoxShape.circle), child: Icon(icon, color: color, size: 19)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: text, fontSize: 12, fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                ClipRRect(borderRadius: BorderRadius.circular(5), child: LinearProgressIndicator(minHeight: 6, value: (value / 60).clamp(0, 1), backgroundColor: line, valueColor: AlwaysStoppedAnimation(color))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: Text(_minutes(value), maxLines: 1, style: const TextStyle(color: subtext, fontSize: 10, fontWeight: FontWeight.w700)))),
        ],
      ),
    );
  }

  String get recommendation {
    final d = today;
    if (d == null) return 'مانیتورینگ را فعال کن تا سی بتواند توصیه‌های شخصی‌تری بسازد.';
    if (d.hunch >= d.neck && d.hunch >= d.wrist && d.hunch >= d.tooClose) return 'امروز فرم نشستن مهم‌ترین نقطه قابل بهبود توست. چند استراحت کوتاه و اصلاح ارتفاع صفحه کمک می‌کند.';
    if (d.tooClose >= d.neck && d.tooClose >= d.wrist) return 'امروز فاصله‌ات از صفحه بیشتر از بقیه موارد نیاز به توجه دارد. صفحه را کمی دورتر قرار بده.';
    if (d.neck >= d.wrist) return 'گردن امروز بیشترین فشار را گرفته است. صفحه را هم‌سطح چشم قرار بده و شانه‌ها را رها کن.';
    return 'مچ‌ها امروز بیشتر درگیر بوده‌اند. یک وقفه کوتاه و کشش ملایم برای مچ‌ها داشته باش.';
  }

  Widget _scoreCard(BoxConstraints constraints) {
    final compact = constraints.maxWidth < 420;
    final scoreRing = SizedBox(
      width: compact ? 82 : 96,
      height: compact ? 82 : 96,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(value: score / 100, strokeWidth: compact ? 8 : 9, backgroundColor: mint, valueColor: const AlwaysStoppedAnimation(green)),
          Text('$score', style: TextStyle(color: text, fontSize: compact ? 21 : 24, fontWeight: FontWeight.w900)),
        ],
      ),
    );

    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('امتیاز سلامت امروز', style: TextStyle(color: subtext, fontSize: 11)),
        const SizedBox(height: 5),
        Text(
          today == null ? 'هنوز داده‌ای نداریم' : score >= 80 ? 'وضعیت امروز خوب است' : score >= 60 ? 'چند مورد برای اصلاح وجود دارد' : 'امروز به بدنت بیشتر توجه کن',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: text, fontSize: 16, fontWeight: FontWeight.w900, height: 1.25),
        ),
        const SizedBox(height: 6),
        const Text('بر اساس داده‌های واقعی پایش', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: subtext, fontSize: 10)),
      ],
    );

    return _card(
      child: compact
          ? Column(crossAxisAlignment: CrossAxisAlignment.center, children: [scoreRing, const SizedBox(height: 12), Align(alignment: Alignment.centerRight, child: copy)])
          : Row(children: [scoreRing, const SizedBox(width: 16), Expanded(child: copy)]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: loading
              ? const Center(child: CircularProgressIndicator(color: green))
              : RefreshIndicator(
                  color: green,
                  onRefresh: _load,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(constraints.maxWidth < 380 ? 12 : 18, 12, constraints.maxWidth < 380 ? 12 : 18, 30),
                        children: [
                          Row(children: [
                            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('گزارش سلامت', style: TextStyle(color: text, fontSize: 23, fontWeight: FontWeight.w900)), SizedBox(height: 4), Text('تحلیل داده‌های ثبت‌شده و توصیه‌های قابل اجرا', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: subtext, fontSize: 10))])),
                            IconButton(onPressed: _load, tooltip: 'به‌روزرسانی', icon: const Icon(Icons.refresh_rounded, color: text)),
                          ]),
                          const SizedBox(height: 14),
                          if (error != null) ...[
                            Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.orange.withValues(alpha: .08), borderRadius: BorderRadius.circular(16)), child: Text(error!, style: const TextStyle(color: text, fontSize: 11))),
                            const SizedBox(height: 14),
                          ],
                          _scoreCard(constraints),
                          const SizedBox(height: 12),
                          _metricsSection(constraints),
                          const SizedBox(height: 12),
                          _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('جزئیات عوامل خطر', style: TextStyle(color: text, fontSize: 14, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 4),
                            const Text('داده‌های پایش در این بخش به شکل قابل استفاده نمایش داده می‌شوند.', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: subtext, fontSize: 10)),
                            const SizedBox(height: 8),
                            _riskRow('نزدیک بودن به صفحه', today?.tooClose ?? 0, Icons.phone_android_rounded, const Color(0xFF8B7CF6)),
                            _riskRow('نور نامناسب', today?.badLight ?? 0, Icons.light_mode_rounded, const Color(0xFFFFB020)),
                          ])),
                          const SizedBox(height: 12),
                          _card(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Container(width: 44, height: 44, decoration: const BoxDecoration(color: mint, shape: BoxShape.circle), child: const Icon(Icons.psychology_alt_rounded, color: green)),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('پیشنهاد امروز', style: TextStyle(color: text, fontSize: 13, fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(recommendation, style: const TextStyle(color: subtext, fontSize: 10, height: 1.6))])),
                          ])),
                          const SizedBox(height: 12),
                          _card(child: Row(children: [
                            const Icon(Icons.history_rounded, color: teal),
                            const SizedBox(width: 10),
                            Expanded(child: Text(metrics.isEmpty ? 'هنوز تاریخچه‌ای ثبت نشده است.' : '${metrics.length} روز داده برای مقایسه در دسترس است.', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: text, fontSize: 11, fontWeight: FontWeight.w700))),
                            TextButton(onPressed: _load, child: const Text('به‌روزرسانی', style: TextStyle(color: green, fontWeight: FontWeight.w800))),
                          ])),
                        ],
                      );
                    },
                  ),
                ),
        ),
      ),
    );
  }
}
