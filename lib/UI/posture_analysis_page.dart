import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../backend/health_data_repository.dart';
import '../services/background_service.dart';

class PostureAnalysisPage extends StatefulWidget {
  const PostureAnalysisPage({super.key});

  @override
  State<PostureAnalysisPage> createState() => _PostureAnalysisPageState();
}

class _PostureAnalysisPageState extends State<PostureAnalysisPage> {
  // ===========================================================================
  // THEME
  // ===========================================================================

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

  // ===========================================================================
  // STATE
  // ===========================================================================

  StreamSubscription<Map<String, dynamic>?>? _statusSubscription;

  bool _loadingHistory = true;
  String? _historyError;

  List<Map<String, dynamic>> _dailyMetrics = [];

  /// These are LIVE values coming directly from BackgroundMonitorService.
  ///
  /// They are seconds, not minutes.
  final Map<String, int> _liveMetrics = {
    'hunch': 0,
    'neck': 0,
    'wrist': 0,
    'tooClose': 0,
    'lowLight': 0,
  };

  // ===========================================================================
  // LIFECYCLE
  // ===========================================================================

  @override
  void initState() {
    super.initState();

    // IMPORTANT:
    // Subscribe first so we don't miss the first background-service update.
    _listenToBackgroundService();

    // Then load the historical data from Supabase.
    _loadDailyMetrics();
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    super.dispose();
  }

  // ===========================================================================
  // LIVE BACKGROUND SERVICE
  // ===========================================================================

  void _listenToBackgroundService() {
    _statusSubscription?.cancel();

    _statusSubscription =
        BackgroundMonitorService.statusStream.listen((data) {
          if (!mounted || data == null) {
            return;
          }

          _updateLiveMetrics(data);
        });
  }

  void _updateLiveMetrics(Map<String, dynamic> data) {
    /*
     * The background service has historically sent metrics in two possible
     * forms:
     *
     * 1. Directly:
     *
     * {
     *   "hunch": 10,
     *   "neck": 20,
     *   "wrist": 5,
     *   "tooClose": 3,
     *   "lowLight": 2
     * }
     *
     * 2. Nested:
     *
     * {
     *   "metrics": {
     *      "hunch": 10,
     *      ...
     *   }
     * }
     *
     * We support both.
     */

    final updated = <String, int>{
      ..._liveMetrics,
    };

    bool changed = false;

    void readMetric(
        String key,
        dynamic value,
        ) {
      if (value == null) {
        return;
      }

      final parsed = _toInt(
        value,
        fallback: updated[key] ?? 0,
      );

      if (updated[key] != parsed) {
        updated[key] = parsed;
        changed = true;
      }
    }

    // -------------------------------------------------------------------------
    // Direct payload
    // -------------------------------------------------------------------------

    if (data.containsKey('hunch')) {
      readMetric('hunch', data['hunch']);
    }

    if (data.containsKey('neck')) {
      readMetric('neck', data['neck']);
    }

    if (data.containsKey('wrist')) {
      readMetric('wrist', data['wrist']);
    }

    if (data.containsKey('tooClose')) {
      readMetric('tooClose', data['tooClose']);
    }

    if (data.containsKey('lowLight')) {
      readMetric('lowLight', data['lowLight']);
    }

    // Some versions may call it lowLight/badLight.
    if (data.containsKey('badLight')) {
      readMetric('lowLight', data['badLight']);
    }

    // -------------------------------------------------------------------------
    // Nested metrics payload
    // -------------------------------------------------------------------------

    final dynamic payload = data['metrics'];

    if (payload is Map) {
      readMetric('hunch', payload['hunch']);
      readMetric('neck', payload['neck']);
      readMetric('wrist', payload['wrist']);
      readMetric('tooClose', payload['tooClose']);
      readMetric('lowLight', payload['lowLight']);

      if (payload['badLight'] != null) {
        readMetric('lowLight', payload['badLight']);
      }
    }

    if (!changed) {
      return;
    }

    setState(() {
      _liveMetrics
        ..clear()
        ..addAll(updated);
    });
  }

  int _toInt(
      dynamic value, {
        int fallback = 0,
      }) {
    if (value == null) {
      return fallback;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString()) ?? fallback;
  }

  // ===========================================================================
  // SUPABASE HISTORY
  // ===========================================================================

  Future<void> _loadDailyMetrics() async {
    if (mounted) {
      setState(() {
        _loadingHistory = true;
        _historyError = null;
      });
    }

    try {
      /*
       * DO NOT query Supabase directly here.
       *
       * HealthDataRepository is responsible for:
       * - authenticated user
       * - timezone handling
       * - daily_metrics query
       * - database mapping
       *
       * This is the same path used by the dashboard.
       */
      final rows =
      await HealthDataRepository.instance.getDailyMetrics(days: 7);

      if (!mounted) {
        return;
      }

      final metrics =
      rows.map<Map<String, dynamic>>((row) {
        return Map<String, dynamic>.from(row);
      }).toList();

      metrics.sort((a, b) {
        final dateA = _parseDate(a['date']);
        final dateB = _parseDate(b['date']);

        return dateA.compareTo(dateB);
      });

      setState(() {
        _dailyMetrics = metrics;
        _loadingHistory = false;
      });

      debugPrint(
        '[PostureAnalysisPage] Loaded ${metrics.length} daily metric rows',
      );

      for (final row in metrics) {
        debugPrint(
          '[PostureAnalysisPage] '
              'date=${row['date']} '
              'neck=${row['neck_bad_minutes']} '
              'hunch=${row['hunch_bad_minutes']} '
              'wrist=${row['wrist_bad_minutes']} '
              'tooClose=${row['too_close_minutes']} '
              'light=${row['bad_light_minutes']}',
        );
      }
    } catch (e, stack) {
      debugPrint(
        '[PostureAnalysisPage] Failed to load Supabase history: $e',
      );

      debugPrintStack(stackTrace: stack);

      if (!mounted) {
        return;
      }

      setState(() {
        _loadingHistory = false;
        _historyError = 'بارگذاری تاریخچه سلامت با مشکل مواجه شد.';
      });
    }
  }

  Future<void> _refresh() async {
    await _loadDailyMetrics();
  }

  // ===========================================================================
  // DATA HELPERS
  // ===========================================================================

  DateTime _parseDate(dynamic value) {
    if (value == null) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    if (value is DateTime) {
      return value;
    }

    return DateTime.tryParse(value.toString()) ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  double _number(
      Map<String, dynamic> row,
      String key,
      ) {
    final value = row[key];

    if (value == null) {
      return 0;
    }

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
    if (minutes <= 0) {
      return '۰ث';
    }

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
    if (seconds < 0) {
      seconds = 0;
    }

    final duration = Duration(seconds: seconds);

    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final remainingSeconds = duration.inSeconds.remainder(60);

    String twoDigits(int value) {
      return value.toString().padLeft(2, '0');
    }

    if (hours > 0) {
      return '${twoDigits(hours)}:'
          '${twoDigits(minutes)}:'
          '${twoDigits(remainingSeconds)}';
    }

    return '${twoDigits(minutes)}:'
        '${twoDigits(remainingSeconds)}';
  }

  String _formatDate(dynamic value) {
    final date = _parseDate(value);

    return '${date.month}/${date.day}';
  }

  String _persianDateLabel(dynamic value) {
    final date = _parseDate(value);

    final now = DateTime.now();

    final currentDay =
    DateTime(now.year, now.month, now.day);

    final metricDay =
    DateTime(date.year, date.month, date.day);

    if (metricDay == currentDay) {
      return 'امروز';
    }

    if (metricDay ==
        currentDay.subtract(const Duration(days: 1))) {
      return 'دیروز';
    }

    return '${date.month}/${date.day}';
  }

  // ===========================================================================
  // TODAY
  // ===========================================================================

  Map<String, dynamic>? get _today {
    if (_dailyMetrics.isEmpty) {
      return null;
    }

    final now = DateTime.now();

    for (final row in _dailyMetrics) {
      final date = _parseDate(row['date']);

      if (date.year == now.year &&
          date.month == now.month &&
          date.day == now.day) {
        return row;
      }
    }

    /*
     * If today's row has not been generated yet by the backend,
     * don't pretend yesterday's data is today's data.
     *
     * This is important because the page should reflect the actual
     * Supabase state.
     */
    return null;
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

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

  // ===========================================================================
  // HEADER
  // ===========================================================================

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
            color: primaryGreen.withValues(alpha: 0.11),
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

  // ===========================================================================
  // LIVE MONITORING
  // ===========================================================================

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
            color: primaryGreen.withValues(alpha: 0.20),
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
                  color: Colors.white.withValues(alpha: 0.18),
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
                  color: Colors.white.withValues(alpha: 0.18),
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
              color: Colors.white.withValues(alpha: 0.13),
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
                  _liveMetrics['neck'] ?? 0,
                  Icons.person_outline_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildLiveMiniMetric(
                  'قوز',
                  _liveMetrics['hunch'] ?? 0,
                  Icons.accessibility_new_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildLiveMiniMetric(
                  'مچ',
                  _liveMetrics['wrist'] ?? 0,
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
        color: Colors.white.withValues(alpha: 0.13),
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

  // ===========================================================================
  // TODAY
  // ===========================================================================

  Widget _buildTodaySection() {
    if (_loadingHistory) {
      return _buildLoadingCard();
    }

    if (_historyError != null) {
      return _buildEmptyCard(
        'خطا در دریافت اطلاعات',
        _historyError!,
      );
    }

    final today = _today;

    if (today == null) {
      return _buildEmptyCard(
        'هنوز داده‌ای برای امروز ثبت نشده',
        'کمی از سی استفاده کنید تا تحلیل وضعیت بدن امروز شما در اینجا نمایش داده شود.',
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
                color: primaryGreen.withValues(alpha: 0.10),
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
          childAspectRatio: 1.3,
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.10),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---------------------------------------------------------------------
          // ICON + EVENT COUNT
          // ---------------------------------------------------------------------

          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.11),
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

          const SizedBox(height: 12),

          // ---------------------------------------------------------------------
          // TITLE
          // ---------------------------------------------------------------------

          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 11,
              color: textMuted,
            ),
          ),

          const SizedBox(height: 3),

          // ---------------------------------------------------------------------
          // VALUE
          // ---------------------------------------------------------------------

          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // CHART
  // ===========================================================================

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
            color: Colors.black.withValues(alpha: 0.035),
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
                  color: teal.withValues(alpha: 0.10),
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
      final values = [
        _number(row, 'neck_bad_minutes'),
        _number(row, 'hunch_bad_minutes'),
        _number(row, 'wrist_bad_minutes'),
        _number(row, 'too_close_minutes'),
        _number(row, 'bad_light_minutes'),
      ];

      for (final value in values) {
        if (value > maxValue) {
          maxValue = value;
        }
      }
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
          return const FlLine(
            color: Color(0xFFE8EEEC),
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
    return const Wrap(
      spacing: 14,
      runSpacing: 9,
      children: [
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

  // ===========================================================================
  // HISTORY BREAKDOWN
  // ===========================================================================

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
            color: Colors.black.withValues(alpha: 0.035),
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
                  color: primaryGreen.withValues(alpha: 0.10),
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

    const maxForBar = 60.0;

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

  // ===========================================================================
  // LOADING
  // ===========================================================================

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

  // ===========================================================================
  // EMPTY / ERROR
  // ===========================================================================

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
              color: primaryGreen.withValues(alpha: 0.10),
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

          if (_historyError != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _loadDailyMetrics,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('تلاش دوباره'),
            ),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// LEGEND ITEM
// =============================================================================

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