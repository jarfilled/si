import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../backend/health_data_repository.dart';

class PostureAnalysisPage extends StatefulWidget {
  const PostureAnalysisPage({super.key});

  @override
  State<PostureAnalysisPage> createState() => _PostureAnalysisPageState();
}

class _PostureAnalysisPageState extends State<PostureAnalysisPage> {
  static const green = Color(0xFF42D2A7);
  static const teal = Color(0xFF45C4D0);
  static const background = Color(0xFFF4F9F7);
  static const text = Color(0xFF263B37);
  static const muted = Color(0xFF7D8D89);
  static const line = Color(0xFFE8EFEC);
  static const mint = Color(0xFFE8F8F1);
  static const orange = Color(0xFFFFA62B);
  static const red = Color(0xFFFF6B6B);
  static const purple = Color(0xFF9B8AFB);

  bool loading = true;
  String? error;
  List<Map<String, dynamic>> daily = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() { loading = true; error = null; });
    try {
      final rows = await HealthDataRepository.instance.getDailyMetrics(days: 7);
      rows.sort((a, b) => DateTime.parse(a['date'].toString()).compareTo(DateTime.parse(b['date'].toString())));
      if (mounted) setState(() { daily = rows; loading = false; });
    } catch (e) {
      debugPrint('[PostureAnalysisPage] $e');
      if (mounted) setState(() { loading = false; error = 'بارگذاری تاریخچه سلامت با مشکل مواجه شد.'; });
    }
  }

  double _number(Map<String, dynamic> row, String key) {
    final value = row[key];
    return value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
  }

  String _duration(double minutes) {
    if (minutes < 1) return '${(minutes * 60).round()}ث';
    if (minutes < 60) return '${minutes.round()}د';
    final hours = minutes ~/ 60;
    final remaining = minutes.round() % 60;
    return remaining == 0 ? '${hours}س' : '${hours}س ${remaining}د';
  }

  Map<String, dynamic>? get today {
    if (daily.isEmpty) return null;
    final now = DateTime.now();
    for (final row in daily.reversed) {
      final date = DateTime.parse(row['date'].toString());
      if (date.year == now.year && date.month == now.month && date.day == now.day) return row;
    }
    return daily.last;
  }

  double _todayRisk() {
    final row = today;
    if (row == null) return 0;
    return _number(row, 'neck') + _number(row, 'hunch') + _number(row, 'wrist') + _number(row, 'tooClose') + _number(row, 'badLight');
  }

  int _score() {
    final row = today;
    final stored = row == null ? 0 : _number(row, 'health_score');
    return stored > 0 ? stored.round().clamp(0, 100) : (100 - _todayRisk() * .8).round().clamp(0, 100);
  }

  Widget _card({required Widget child, EdgeInsets padding = const EdgeInsets.all(17)}) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: line),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 18, offset: Offset(0, 6))],
      ),
      child: child,
    );
  }

  Widget _header(BuildContext context) {
    return LayoutBuilder(builder: (_, constraints) {
      final narrow = constraints.maxWidth < 340;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('وضعیت بدن', style: TextStyle(color: text, fontSize: narrow ? 22 : 26, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text('بررسی عادت‌های بدنی و وضعیت نشستن شما', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: muted, fontSize: narrow ? 10 : 12)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(width: 46, height: 46, decoration: const BoxDecoration(color: mint, shape: BoxShape.circle), child: const Icon(Icons.accessibility_new_rounded, color: green, size: 26)),
        ],
      );
    });
  }

  Widget _todayCard() {
    final row = today;
    final score = _score();
    if (row == null) {
      return _card(child: const Row(children: [Icon(Icons.insights_rounded, color: green), SizedBox(width: 10), Expanded(child: Text('هنوز داده روزانه‌ای برای نمایش وجود ندارد.', style: TextStyle(color: muted, fontSize: 11)))]));
    }

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(builder: (_, constraints) {
            final compact = constraints.maxWidth < 330;
            final scoreView = SizedBox(
              width: compact ? 60 : 66,
              height: compact ? 60 : 66,
              child: Stack(alignment: Alignment.center, children: [
                CircularProgressIndicator(value: score / 100, strokeWidth: 6, backgroundColor: mint, valueColor: const AlwaysStoppedAnimation(green)),
                Text('$score', style: TextStyle(color: text, fontSize: compact ? 13 : 15, fontWeight: FontWeight.w900)),
              ]),
            );
            final title = const Expanded(child: Text('خلاصه امروز', style: TextStyle(color: text, fontSize: 15, fontWeight: FontWeight.w900)));
            return Row(children: [title, const SizedBox(width: 10), scoreView]);
          }),
          const SizedBox(height: 14),
          LayoutBuilder(builder: (_, constraints) {
            final columns = constraints.maxWidth < 360 ? 1 : (constraints.maxWidth < 520 ? 2 : 3);
            final width = columns == 1 ? constraints.maxWidth : (constraints.maxWidth - (columns - 1) * 8) / columns;
            final items = [
              ('گردن', _duration(_number(row, 'neck')), Icons.accessibility_new_rounded, teal),
              ('قوز', _duration(_number(row, 'hunch')), Icons.airline_seat_recline_normal_rounded, green),
              ('مچ', _duration(_number(row, 'wrist')), Icons.back_hand_rounded, orange),
              ('فاصله کم', _duration(_number(row, 'tooClose')), Icons.phone_android_rounded, red),
              ('نور کم', _duration(_number(row, 'badLight')), Icons.wb_sunny_outlined, purple),
            ];
            return Wrap(spacing: 8, runSpacing: 8, children: items.map((item) => SizedBox(width: width, child: _buildPostureMetricCard(item.$1, item.$2, item.$3, item.$4))).toList());
          }),
        ],
      ),
    );
  }

  Widget _buildPostureMetricCard(String title, String value, IconData icon, Color color) {
    return LayoutBuilder(builder: (_, constraints) {
      final compact = constraints.maxWidth < 135;
      return Container(
        constraints: const BoxConstraints(minHeight: 58),
        padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 9 : 11),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(15)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: compact ? 16 : 17),
            SizedBox(width: compact ? 5 : 7),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: muted, fontSize: compact ? 7.5 : 8)),
                  const SizedBox(height: 2),
                  Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: text, fontSize: compact ? 10 : 11, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _chart() {
    if (daily.length < 2) {
      return _card(child: const Row(children: [Icon(Icons.show_chart_rounded, color: teal), SizedBox(width: 9), Expanded(child: Text('با چند روز داده، روند هفتگی اینجا نمایش داده می‌شود.', style: TextStyle(color: muted, fontSize: 11)))]));
    }

    final spots = <FlSpot>[];
    for (var i = 0; i < daily.length; i++) {
      final row = daily[i];
      spots.add(FlSpot(i.toDouble(), _number(row, 'neck') + _number(row, 'hunch') + _number(row, 'wrist')));
    }
    final maxY = spots.map((e) => e.y).fold<double>(1, (a, b) => a > b ? a : b);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('روند فشار بدنی', style: TextStyle(color: text, fontSize: 15, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text('مجموع زمان گردن، قوز و مچ در هفت روز اخیر', style: TextStyle(color: muted, fontSize: 10)),
          const SizedBox(height: 18),
          SizedBox(
            height: 190,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (spots.length - 1).toDouble(),
                minY: 0,
                maxY: maxY * 1.15,
                gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => const FlLine(color: line, strokeWidth: 1)),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32)),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 26, interval: 1, getTitlesWidget: (value, meta) {
                    final index = value.round();
                    if (index < 0 || index >= daily.length) return const SizedBox.shrink();
                    final date = DateTime.parse(daily[index]['date'].toString());
                    return SideTitleWidget(meta: meta, child: Text('${date.month}/${date.day}', style: const TextStyle(color: muted, fontSize: 8)));
                  })),
                ),
                lineBarsData: [LineChartBarData(spots: spots, isCurved: true, color: teal, barWidth: 3, dotData: const FlDotData(show: true), belowBarData: BarAreaData(show: true, color: mint))],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _breakdown() {
    if (daily.isEmpty) return const SizedBox.shrink();
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('جزئیات روزها', style: TextStyle(color: text, fontSize: 15, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          ...daily.reversed.map((row) {
            final date = DateTime.parse(row['date'].toString());
            final now = DateTime.now();
            final label = date.year == now.year && date.month == now.month && date.day == now.day ? 'امروز' : '${date.month}/${date.day}';
            final score = _number(row, 'health_score').round();
            final total = _number(row, 'neck') + _number(row, 'hunch') + _number(row, 'wrist');
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(children: [
                Container(width: 34, height: 34, decoration: const BoxDecoration(color: mint, shape: BoxShape.circle), child: const Icon(Icons.calendar_today_rounded, color: green, size: 16)),
                const SizedBox(width: 9),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: text, fontSize: 11, fontWeight: FontWeight.w800)), const SizedBox(height: 2), Text('فشار بدنی: ${_duration(total)}', style: const TextStyle(color: muted, fontSize: 9))])),
                Text(score > 0 ? '$score' : '—', style: const TextStyle(color: green, fontSize: 13, fontWeight: FontWeight.w900)),
              ]),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: background,
        body: RefreshIndicator(
          color: green,
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 30),
            children: [
              _header(context),
              const SizedBox(height: 14),
              if (loading) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: green))),
              if (error != null) _card(child: Row(children: [const Icon(Icons.error_outline_rounded, color: red), const SizedBox(width: 8), Expanded(child: Text(error!, style: const TextStyle(color: muted, fontSize: 10)))])),
              if (!loading) ...[
                _todayCard(),
                const SizedBox(height: 14),
                _chart(),
                const SizedBox(height: 14),
                _breakdown(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
