import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../backend/daily_health_metric.dart';
import '../backend/health_data_repository.dart';
import '../services/background_service.dart';

class PostureAnalysisPage extends StatefulWidget {
  const PostureAnalysisPage({Key? key}) : super(key: key);

  @override
  State<PostureAnalysisPage> createState() =>
      _PostureAnalysisPageState();
}

class _PostureAnalysisPageState extends State<PostureAnalysisPage> {
  // ---------------------------------------------------------------------------
  // THEME
  // ---------------------------------------------------------------------------

  static const Color primaryGreen = Color(0xFF42D2A7);
  static const Color teal = Color(0xFF45C4D0);
  static const Color background = Color(0xFFF4F9F7);
  static const Color textDark = Color(0xFF2D3142);
  static const Color textMuted = Color(0xFF7B8494);

  static const Color neckColor = Color(0xFF45C4D0);
  static const Color hunchColor = Color(0xFF42D2A7);
  static const Color wristColor = Color(0xFFFFA62B);
  static const Color tooCloseColor = Color(0xFFFF6B6B);
  static const Color lightColor = Color(0xFF9B8AFB);

  // ---------------------------------------------------------------------------
  // STATE
  // ---------------------------------------------------------------------------

  StreamSubscription? _statusSubscription;

  bool _loadingHistory = true;
  String? _historyError;

  List<Map<String, dynamic>> _dailyMetrics = [];

  final Map<String, int> _liveMetrics = {
    'hunch': 0,
    'neck': 0,
    'wrist': 0,
    'tooClose': 0,
    'lowLight': 0,
  };

  // ---------------------------------------------------------------------------
  // LIFECYCLE
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();

    _listenToBackgroundService();
    _loadDailyMetrics();
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // LIVE MONITORING
  // ---------------------------------------------------------------------------

  void _listenToBackgroundService() {
    _statusSubscription =
        BackgroundMonitorService.statusStream.listen((data) {
          if (!mounted || data == null) return;

          setState(() {
            _readLiveMetrics(data);
          });
        });
  }

  void _readLiveMetrics(Map<dynamic, dynamic> data) {
    if (data.containsKey('hunch')) {
      _liveMetrics['hunch'] = _toInt(data['hunch']);
      _liveMetrics['neck'] = _toInt(data['neck']);
      _liveMetrics['wrist'] = _toInt(data['wrist']);
      _liveMetrics['tooClose'] = _toInt(data['tooClose']);
      _liveMetrics['lowLight'] = _toInt(data['lowLight']);
    }

    if (data.containsKey('metrics')) {
      final dynamic payload = data['metrics'];

      if (payload is Map) {
        _liveMetrics['hunch'] = _toInt(
          payload['hunch'],
          fallback: _liveMetrics['hunch']!,
        );

        _liveMetrics['neck'] = _toInt(
          payload['neck'],
          fallback: _liveMetrics['neck']!,
        );

        _liveMetrics['wrist'] = _toInt(
          payload['wrist'],
          fallback: _liveMetrics['wrist']!,
        );

        _liveMetrics['tooClose'] = _toInt(
          payload['tooClose'],
          fallback: _liveMetrics['tooClose']!,
        );

        _liveMetrics['lowLight'] = _toInt(
          payload['lowLight'],
          fallback: _liveMetrics['lowLight']!,
        );
      }
    }
  }

  int _toInt(
      dynamic value, {
        int fallback = 0,
      }) {
    if (value == null) return fallback;

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString()) ?? fallback;
  }

  // ---------------------------------------------------------------------------
  // SUPABASE HISTORY
  // ---------------------------------------------------------------------------

  Future<void> _loadDailyMetrics() async {
    if (mounted) {
      setState(() {
        _loadingHistory = true;
        _historyError = null;
      });
    }

    try {
      final rows =
      await HealthDataRepository.instance.getDailyMetrics(days: 7);

      if (!mounted) return;

      setState(() {
        _dailyMetrics = List<Map<String, dynamic>>.from(rows);

        _dailyMetrics.sort((a, b) {
          final dateA = DateTime.parse(a['date'].toString());
          final dateB = DateTime.parse(b['date'].toString());

          return dateA.compareTo(dateB);
        });

        _loadingHistory = false;
      });
    } catch (e) {
      debugPrint(
        '[PostureAnalysisPage] Failed to load history: $e',
      );

      if (!mounted) return;

      setState(() {
        _loadingHistory = false;
        _historyError = 'بارگذاری تاریخچه سلامت با مشکل مواجه شد.';
      });
    }
  }

  Future<void> _refresh() async {
    await _loadDailyMetrics();
  }

  // ---------------------------------------------------------------------------
  // DATA HELPERS
  // ---------------------------------------------------------------------------

  double _number(
      Map<String, dynamic> row,
      String key,
      ) {
    final value = row[key];

    if (value == null) return 0;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString()) ?? 0;
  }

  int _integer(
      Map<String, dynamic> row,
      String key,
      ) {
    return _number(row, key).round();
  }

  String _formatMinutes(double minutes) {
    if (minutes < 1) {
      final seconds = (minutes * 60).round();
      return '${seconds}ث';
    }

    final wholeMinutes = minutes.floor();

    final seconds =
    ((minutes - wholeMinutes) * 60).round();

    if (wholeMinutes < 60) {
      if (seconds == 0) {
        return '${wholeMinutes}د';
      }

      return '${wholeMinutes}د ${seconds}ث';
    }

    final hours = wholeMinutes ~/ 60;
    final remainingMinutes = wholeMinutes % 60;

    if (remainingMinutes == 0) {
      return '${hours}س';
    }

    return '${hours}س ${remainingMinutes}د';
  }

  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);

    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final remainingSeconds = duration.inSeconds.remainder(60);

    String twoDigits(int value) =>
        value.toString().padLeft(2, '0');

    if (hours > 0) {
      return '${twoDigits(hours)}:'
          '${twoDigits(minutes)}:'
          '${twoDigits(remainingSeconds)}';
    }

    return '${twoDigits(minutes)}:'
        '${twoDigits(remainingSeconds)}';
  }

  String _formatDate(dynamic value) {
    final date = DateTime.parse(value.toString());

    return '${date.month}/${date.day}';
  }

  String _persianDateLabel(dynamic value) {
    final date = DateTime.parse(value.toString());

    final today = DateTime.now();

    if (date.year == today.year &&
        date.month == today.month &&
        date.day == today.day) {
      return 'امروز';
    }

    final yesterday = today.subtract(
      const Duration(days: 1),
    );

    if (date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day) {
      return 'دیروز';
    }

    return '${date.month}/${date.day}';
  }

  // ---------------------------------------------------------------------------
  // TODAY
  // ---------------------------------------------------------------------------

  Map<String, dynamic>? get _today {
    if (_dailyMetrics.isEmpty) {
      return null;
    }

    final now = DateTime.now();

    for (final row in _dailyMetrics) {
      final date = DateTime.parse(row['date'].toString());

      if (date.year == now.year &&
          date.month == now.month &&
          date.day == now.day) {
        return row;
      }
    }

    return _dailyMetrics.last;
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
        body: RefreshIndicator(
          color: primaryGreen,
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(
              20,
              18,
              20,
              35,
            ),
            children: [
              _buildHeader(),

              const SizedBox(height: 20),

              _buildLiveMonitoringCard(),

              const SizedBox(height: 24),

              _buildTodaySection(),

              const SizedBox(height: 24),

              _buildHistoryChart(),

              const SizedBox(height: 24),

              _buildHistoryBreakdown(),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HEADER
  // ---------------------------------------------------------------------------

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'وضعیت بدن',
                style: TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: textDark,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'بررسی عادت‌های بدنی و وضعیت نشستن شما',
                style: TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontSize: 13,
                  color: textMuted,
                ),
              ),
            ],
          ),
        ),

        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: primaryGreen.withOpacity(0.11),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.accessibility_new_rounded,
            color: primaryGreen,
            size: 27,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // LIVE MONITORING
  // ---------------------------------------------------------------------------

  Widget _buildLiveMonitoringCard() {
    final totalLiveSeconds =
    _liveMetrics.values.fold<int>(
      0,
          (sum, value) => sum + value,
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF42D2A7),
            Color(0xFF45C4D0),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: primaryGreen.withOpacity(0.20),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.radar_rounded,
                  color: Colors.white,
                  size: 23,
                ),
              ),

              const SizedBox(width: 12),

              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'مانیتورینگ لحظه‌ای',
                      style: TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'وضعیت بدن شما در حال بررسی است',
                      style: TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontSize: 11,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'فعال',
                      style: TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.13),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.timer_outlined,
                  color: Colors.white,
                  size: 21,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'زمان وضعیت نامناسب در این لحظه',
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
                Text(
                  _formatDuration(totalLiveSeconds),
                  style: const TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildLiveMiniMetric(
                  'گردن',
                  _liveMetrics['neck']!,
                  Icons.person_outline_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildLiveMiniMetric(
                  'قوز',
                  _liveMetrics['hunch']!,
                  Icons.accessibility_new_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildLiveMiniMetric(
                  'مچ',
                  _liveMetrics['wrist']!,
                  Icons.back_hand_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLiveMiniMetric(
      String title,
      int seconds,
      IconData icon,
      ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 11,
        horizontal: 7,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.13),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 19,
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 10,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _formatDuration(seconds),
            style: const TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TODAY
  // ---------------------------------------------------------------------------

  Widget _buildTodaySection() {
    final today = _today;

    if (_loadingHistory) {
      return _buildLoadingCard();
    }

    if (today == null) {
      return _buildEmptyCard(
        'هنوز داده‌ای ثبت نشده',
        'کمی از سی استفاده کنید تا تحلیل وضعیت بدن شما در اینجا نمایش داده شود.',
      );
    }

    final totalEvents =
        _integer(today, 'neck_event_count') +
            _integer(today, 'hunch_event_count') +
            _integer(today, 'wrist_event_count') +
            _integer(today, 'too_close_event_count');

    final totalBadMinutes =
        _number(today, 'neck_bad_minutes') +
            _number(today, 'hunch_bad_minutes') +
            _number(today, 'wrist_bad_minutes') +
            _number(today, 'too_close_minutes') +
            _number(today, 'bad_light_minutes');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'امروز',
                style: TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  color: textDark,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: primaryGreen.withOpacity(0.10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$totalEvents هشدار',
                style: const TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: primaryGreen,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 5),

        Text(
          'در مجموع ${_formatMinutes(totalBadMinutes)} در وضعیت نامناسب بوده‌اید.',
          style: const TextStyle(
            fontFamily: 'Vazirmatn',
            fontSize: 12,
            color: textMuted,
          ),
        ),

        const SizedBox(height: 15),

        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.55,
          children: [
            _buildPostureMetricCard(
              title: 'گردن',
              value: _formatMinutes(
                _number(today, 'neck_bad_minutes'),
              ),
              events: _integer(
                today,
                'neck_event_count',
              ),
              icon: Icons.person_outline_rounded,
              color: neckColor,
            ),
            _buildPostureMetricCard(
              title: 'قوز',
              value: _formatMinutes(
                _number(today, 'hunch_bad_minutes'),
              ),
              events: _integer(
                today,
                'hunch_event_count',
              ),
              icon: Icons.accessibility_new_rounded,
              color: hunchColor,
            ),
            _buildPostureMetricCard(
              title: 'مچ دست',
              value: _formatMinutes(
                _number(today, 'wrist_bad_minutes'),
              ),
              events: _integer(
                today,
                'wrist_event_count',
              ),
              icon: Icons.back_hand_outlined,
              color: wristColor,
            ),
            _buildPostureMetricCard(
              title: 'فاصله صفحه',
              value: _formatMinutes(
                _number(today, 'too_close_minutes'),
              ),
              events: _integer(
                today,
                'too_close_event_count',
              ),
              icon: Icons.phone_android_rounded,
              color: tooCloseColor,
            ),
            _buildPostureMetricCard(
              title: 'نور محیط',
              value: _formatMinutes(
                _number(today, 'bad_light_minutes'),
              ),
              events: 0,
              icon: Icons.wb_sunny_outlined,
              color: lightColor,
            ),
            _buildPostureMetricCard(
              title: 'کل هشدارها',
              value: '$totalEvents',
              events: totalEvents,
              icon: Icons.notifications_none_rounded,
              color: primaryGreen,
              isEventCard: true,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPostureMetricCard({
    required String title,
    required String value,
    required int events,
    required IconData icon,
    required Color color,
    bool isEventCard = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.10),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.11),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 19,
                ),
              ),
              const Spacer(),
              if (!isEventCard && events > 0)
                Text(
                  '$events بار',
                  style: TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
            ],
          ),

          const Spacer(),

          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 11,
              color: textMuted,
            ),
          ),

          const SizedBox(height: 3),

          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textDark,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CHART
  // ---------------------------------------------------------------------------

  Widget _buildHistoryChart() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        18,
        20,
        18,
        18,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: teal.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.show_chart_rounded,
                  color: teal,
                  size: 22,
                ),
              ),

              const SizedBox(width: 11),

              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'روند هفتگی',
                      style: TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textDark,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'دقایق سپری‌شده در وضعیت نامناسب',
                      style: TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontSize: 10,
                        color: textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 25),

          if (_loadingHistory)
            const SizedBox(
              height: 240,
              child: Center(
                child: CircularProgressIndicator(
                  color: primaryGreen,
                  strokeWidth: 2.5,
                ),
              ),
            )
          else if (_dailyMetrics.isEmpty)
            const SizedBox(
              height: 240,
              child: Center(
                child: Text(
                  'هنوز داده کافی برای نمایش نمودار وجود ندارد.',
                  style: TextStyle(
                    fontFamily: 'Vazirmatn',
                    color: textMuted,
                    fontSize: 12,
                  ),
                ),
              ),
            )
          else
            SizedBox(
              height: 245,
              child: LineChart(
                _buildChartData(),
              ),
            ),

          const SizedBox(height: 18),

          _buildChartLegend(),
        ],
      ),
    );
  }

  LineChartData _buildChartData() {
    double maxValue = 1;

    for (final row in _dailyMetrics) {
      maxValue = [
        maxValue,
        _number(row, 'neck_bad_minutes'),
        _number(row, 'hunch_bad_minutes'),
        _number(row, 'wrist_bad_minutes'),
        _number(row, 'too_close_minutes'),
        _number(row, 'bad_light_minutes'),
      ].reduce((a, b) => a > b ? a : b);
    }

    maxValue *= 1.2;

    if (maxValue < 5) {
      maxValue = 5;
    }

    final interval = maxValue / 4;

    return LineChartData(
      minY: 0,
      maxY: maxValue,
      clipData: const FlClipData.all(),

      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: interval,
        getDrawingHorizontalLine: (value) {
          return FlLine(
            color: const Color(0xFFE8EEEC),
            strokeWidth: 1,
          );
        },
      ),

      borderData: FlBorderData(show: false),

      titlesData: FlTitlesData(
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),

        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 32,
            interval: interval,
            getTitlesWidget: (value, meta) {
              return Text(
                value.round().toString(),
                style: const TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontSize: 9,
                  color: textMuted,
                ),
              );
            },
          ),
        ),

        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 28,
            interval: 1,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();

              if (index < 0 ||
                  index >= _dailyMetrics.length) {
                return const SizedBox();
              }

              return Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Text(
                  _formatDate(
                    _dailyMetrics[index]['date'],
                  ),
                  style: const TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 9,
                    color: textMuted,
                  ),
                ),
              );
            },
          ),
        ),
      ),

      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              return LineTooltipItem(
                '${spot.y.toStringAsFixed(1)} دقیقه',
                const TextStyle(
                  fontFamily: 'Vazirmatn',
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              );
            }).toList();
          },
        ),
      ),

      lineBarsData: [
        _buildLine(
          'neck_bad_minutes',
          neckColor,
        ),
        _buildLine(
          'hunch_bad_minutes',
          hunchColor,
        ),
        _buildLine(
          'wrist_bad_minutes',
          wristColor,
        ),
        _buildLine(
          'too_close_minutes',
          tooCloseColor,
        ),
        _buildLine(
          'bad_light_minutes',
          lightColor,
        ),
      ],
    );
  }

  LineChartBarData _buildLine(
      String key,
      Color color,
      ) {
    final spots = <FlSpot>[];

    for (int i = 0; i < _dailyMetrics.length; i++) {
      spots.add(
        FlSpot(
          i.toDouble(),
          _number(
            _dailyMetrics[i],
            key,
          ),
        ),
      );
    }

    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.25,
      barWidth: 2.5,
      color: color,
      dotData: FlDotData(
        show: _dailyMetrics.length <= 7,
        getDotPainter: (
            spot,
            percent,
            bar,
            index,
            ) {
          return FlDotCirclePainter(
            radius: 3.5,
            color: color,
            strokeWidth: 2,
            strokeColor: Colors.white,
          );
        },
      ),
      belowBarData: BarAreaData(show: false),
    );
  }

  Widget _buildChartLegend() {
    return Wrap(
      spacing: 14,
      runSpacing: 9,
      children: const [
        _LegendItem(
          label: 'گردن',
          color: neckColor,
        ),
        _LegendItem(
          label: 'قوز',
          color: hunchColor,
        ),
        _LegendItem(
          label: 'مچ',
          color: wristColor,
        ),
        _LegendItem(
          label: 'فاصله',
          color: tooCloseColor,
        ),
        _LegendItem(
          label: 'نور',
          color: lightColor,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // HISTORY BREAKDOWN
  // ---------------------------------------------------------------------------

  Widget _buildHistoryBreakdown() {
    if (_loadingHistory || _dailyMetrics.isEmpty) {
      return const SizedBox();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: primaryGreen.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: primaryGreen,
                  size: 21,
                ),
              ),

              const SizedBox(width: 11),

              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'خلاصه روزانه',
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'مقایسه روزهای اخیر',
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 10,
                      color: textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 18),

          ..._dailyMetrics.reversed.map(
            _buildHistoryRow,
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryRow(
      Map<String, dynamic> row,
      ) {
    final total =
        _number(row, 'neck_bad_minutes') +
            _number(row, 'hunch_bad_minutes') +
            _number(row, 'wrist_bad_minutes') +
            _number(row, 'too_close_minutes') +
            _number(row, 'bad_light_minutes');

    final maxForBar = 60.0;

    final progress =
    (total / maxForBar).clamp(0.0, 1.0);

    final isHigh = total >= 30;

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 8,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Text(
              _persianDateLabel(row['date']),
              style: TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isHigh
                    ? tooCloseColor
                    : textDark,
              ),
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 7,
                    backgroundColor:
                    const Color(0xFFEAF0EE),
                    valueColor:
                    AlwaysStoppedAnimation<Color>(
                      isHigh
                          ? tooCloseColor
                          : primaryGreen,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${total.toStringAsFixed(0)} دقیقه وضعیت نامناسب',
                  style: const TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 9,
                    color: textMuted,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          Text(
            _formatMinutes(total),
            style: const TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: textDark,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // LOADING
  // ---------------------------------------------------------------------------

  Widget _buildLoadingCard() {
    return Container(
      padding: const EdgeInsets.all(35),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          color: primaryGreen,
          strokeWidth: 2.5,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // EMPTY
  // ---------------------------------------------------------------------------

  Widget _buildEmptyCard(
      String title,
      String message,
      ) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Container(
            width: 65,
            height: 65,
            decoration: BoxDecoration(
              color: primaryGreen.withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.insights_rounded,
              size: 32,
              color: primaryGreen,
            ),
          ),

          const SizedBox(height: 15),

          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: textDark,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 12,
              height: 1.7,
              color: textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// LEGEND ITEM
// -----------------------------------------------------------------------------

class _LegendItem extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendItem({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Vazirmatn',
            fontSize: 10,
            color: Colors.red,
          ),
        ),
      ],
    );
  }
}