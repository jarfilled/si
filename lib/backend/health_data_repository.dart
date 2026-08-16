import 'package:supabase_flutter/supabase_flutter.dart';

class HealthDataRepository {
  HealthDataRepository._();

  static final HealthDataRepository instance = HealthDataRepository._();

  final SupabaseClient _supabase = Supabase.instance.client;

  String? get userId => _supabase.auth.currentUser?.id;

  bool get isAuthenticated => userId != null;

  Future<List<Map<String, dynamic>>> getDailyMetrics({
    int days = 7,
  }) async {
    final id = userId;

    if (id == null) {
      return [];
    }

    try {
      final result = await _supabase
          .from('daily_metrics')
          .select()
          .eq('user_id', id)
          .order('date', ascending: false)
          .limit(days);

      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      print('[HealthDataRepository] Failed to fetch daily metrics: $e');
      return [];
    }
  }

  Future<List<String>> insertHealthEventsBatch(
      List<Map<String, dynamic>> events,
      ) async {
    final id = userId;
    if (id == null || events.isEmpty) {
      return [];
    }

    final rows = events
        .where((event) {
      final eventUserId = event['user_id']?.toString();
      return eventUserId == null || eventUserId == id;
    })
        .map((event) {
      final duration =
          (event['duration_seconds'] as num?)?.toDouble() ?? 0.0;

      return <String, dynamic>{
        'event_id': event['event_id'],
        'user_id': id,
        'event_type': event['event_type'],
        'started_at': event['started_at'],
        'ended_at': event['ended_at'],
        'duration_seconds': duration < 0 ? 0.0 : duration,
        'severity': event['severity'],
        'metadata': event['metadata'],
      };
    })
        .toList();

    if (rows.isEmpty) {
      return [];
    }

    try {
      await _supabase
          .from('health_events')
          .upsert(
        rows,
        onConflict: 'user_id,event_id',
        ignoreDuplicates: true,
      );

      final ids = rows
          .map((row) => row['event_id']?.toString())
          .whereType<String>()
          .toList();

      print(
        '[HealthDataRepository] Uploaded ${ids.length} health events '
            'in one batch.',
      );

      return ids;
    } catch (e, stackTrace) {
      print('[HealthDataRepository] Batch event upload failed: $e');
      print(stackTrace);
      return [];
    }
  }

  Future<Map<String, int>> upsertHourlyMetricsBatch(
      List<Map<String, dynamic>> metrics,
      ) async {
    final id = userId;
    if (id == null || metrics.isEmpty) {
      return {};
    }

    final rows = metrics.map((metric) {
      return <String, dynamic>{
        'user_id': id,
        'hour_start': metric['hour_start'],
        'screen_time_seconds':
        (metric['screen_time_seconds'] as num?)?.toInt() ?? 0,
        'hunch_bad_seconds':
        (metric['hunch_bad_seconds'] as num?)?.toDouble() ?? 0.0,
        'neck_bad_seconds':
        (metric['neck_bad_seconds'] as num?)?.toDouble() ?? 0.0,
        'wrist_bad_seconds':
        (metric['wrist_bad_seconds'] as num?)?.toDouble() ?? 0.0,
        'too_close_seconds':
        (metric['too_close_seconds'] as num?)?.toDouble() ?? 0.0,
        'low_light_seconds':
        (metric['low_light_seconds'] as num?)?.toDouble() ?? 0.0,
        'hunch_event_count':
        (metric['hunch_event_count'] as num?)?.toInt() ?? 0,
        'neck_event_count':
        (metric['neck_event_count'] as num?)?.toInt() ?? 0,
        'wrist_event_count':
        (metric['wrist_event_count'] as num?)?.toInt() ?? 0,
        'too_close_event_count':
        (metric['too_close_event_count'] as num?)?.toInt() ?? 0,
        'low_light_event_count':
        (metric['low_light_event_count'] as num?)?.toInt() ?? 0,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
    }).toList();

    try {
      await _supabase
          .from('hourly_metrics')
          .upsert(
        rows,
        onConflict: 'user_id,hour_start',
      );

      return {
        for (final metric in metrics)
          metric['hour_start'].toString():
          (metric['version'] as num?)?.toInt() ?? 0,
      };
    } catch (e, stackTrace) {
      print('[HealthDataRepository] Hourly batch upload failed: $e');
      print(stackTrace);
      return {};
    }
  }

  Future<void> updateDailyMetrics({
    required DateTime date,
    required String timezone,
  }) async {
    final id = userId;

    if (id == null) {
      print(
        '[HealthDataRepository] No authenticated user. '
            'Skipping daily metrics update.',
      );
      return;
    }

    try {
      await _supabase.rpc(
        'calculate_daily_metrics',
        params: {
          'target_user_id': id,
          'target_date': date.toIso8601String().substring(0, 10),
          'target_timezone': timezone,
        },
      );

      print(
        '[HealthDataRepository] Daily metrics updated: '
            '${date.toIso8601String().substring(0, 10)}',
      );
    } catch (e) {
      print('[HealthDataRepository] Failed to update daily metrics: $e');
    }
  }

  Future<void> upsertDailyMetrics({
    required DateTime date,
    required int screenTimeMinutes,
    required int neckBadMinutes,
    required int hunchBadMinutes,
    required int wristBadMinutes,
    required int tooCloseMinutes,
    required int badLightMinutes,
    required int combinedRiskMinutes,
    required int neckEventCount,
    required int hunchEventCount,
    required int wristEventCount,
    required int tooCloseEventCount,
    required int eyeBreakCount,
    required int postureCorrectionCount,
    required int nsfwBlockCount,
    int? healthScore,
  }) async {
    final id = userId;
    if (id == null) {
      return;
    }

    final dateString = date.toIso8601String().substring(0, 10);

    try {
      await _supabase.from('daily_metrics').upsert(
        {
          'user_id': id,
          'date': dateString,
          'screen_time_minutes': screenTimeMinutes,
          'neck_bad_minutes': neckBadMinutes,
          'hunch_bad_minutes': hunchBadMinutes,
          'wrist_bad_minutes': wristBadMinutes,
          'too_close_minutes': tooCloseMinutes,
          'bad_light_minutes': badLightMinutes,
          'combined_risk_minutes': combinedRiskMinutes,
          'neck_event_count': neckEventCount,
          'hunch_event_count': hunchEventCount,
          'wrist_event_count': wristEventCount,
          'too_close_event_count': tooCloseEventCount,
          'eye_break_count': eyeBreakCount,
          'posture_correction_count': postureCorrectionCount,
          'nsfw_block_count': nsfwBlockCount,
          'health_score': healthScore,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'user_id,date',
      );
    } catch (e) {
      print('[HealthDataRepository] Daily upsert failed: $e');
    }
  }
}
