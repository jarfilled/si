import 'package:supabase_flutter/supabase_flutter.dart';

class HealthDataRepository {
  HealthDataRepository._();

  static final HealthDataRepository instance = HealthDataRepository._();

  SupabaseClient get _supabase => Supabase.instance.client;

  // ===========================================================================
  // AUTH
  // ===========================================================================

  User? get currentUser => _supabase.auth.currentUser;

  String? get currentUserId => currentUser?.id;

  String _requireUserId() {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw StateError('No authenticated user is available.');
    }

    return user.id;
  }

  // ===========================================================================
  // HEALTH EVENTS
  // ===========================================================================

  Future<void> recordHealthEvent({
    required String eventType,
    required DateTime startedAt,
    required DateTime endedAt,
    required double durationSeconds,
  }) async {
    final userId = _requireUserId();

    if (durationSeconds < 0) {
      throw ArgumentError.value(
        durationSeconds,
        'durationSeconds',
        'Duration cannot be negative.',
      );
    }

    final eventId = _eventId(
      userId: userId,
      eventType: eventType,
      startedAt: startedAt,
      endedAt: endedAt,
    );

    final payload = <String, dynamic>{
      'event_id': eventId,
      'user_id': userId,
      'event_type': eventType,
      'started_at': startedAt.toUtc().toIso8601String(),
      'ended_at': endedAt.toUtc().toIso8601String(),
      'duration_seconds': durationSeconds,
    };

    try {
      await _supabase.from('health_events').upsert(
        payload,
        onConflict: 'event_id',
        ignoreDuplicates: true,
      );
    } catch (e) {
      // Keep the background monitoring loop alive if a single upload fails.
      // The event can be retried by the synchronization layer.
      print('[HealthDataRepository] Failed to record health event: $e');
    }
  }

  String _eventId({
    required String userId,
    required String eventType,
    required DateTime startedAt,
    required DateTime endedAt,
  }) {
    final raw = [
      userId,
      eventType,
      startedAt.toUtc().microsecondsSinceEpoch,
      endedAt.toUtc().microsecondsSinceEpoch,
    ].join('|');

    // FNV-1a 64-bit style deterministic hash.
    var hash = 0xcbf29ce484222325;

    for (final byte in raw.codeUnits) {
      hash ^= byte;
      hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
    }

    return _uint64ToUuid(hash);
  }

  String _uint64ToUuid(int value) {
    final hex = value.toRadixString(16).padLeft(16, '0');

    return [
      hex.substring(0, 8),
      hex.substring(8, 12),
      '4000',
      '8000',
      hex.substring(0, 4) + hex.substring(12, 16),
    ].join('-');
  }

  // ===========================================================================
  // DAILY METRICS
  // ===========================================================================

  Future<List<Map<String, dynamic>>> getDailyMetrics({
    int days = 7,
    String timezone = 'Asia/Tehran',
  }) async {
    final userId = _requireUserId();

    if (days <= 0) {
      return <Map<String, dynamic>>[];
    }

    try {
      final response = await _supabase
          .from('daily_metrics')
          .select()
          .eq('user_id', userId)
          .order('date', ascending: false)
          .limit(days);

      return (response as List)
          .map(
            (row) => Map<String, dynamic>.from(
          row as Map,
        ),
      )
          .toList();
    } catch (e) {
      print('[HealthDataRepository] Failed to load daily metrics: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getDailyMetric({
    required DateTime date,
    String timezone = 'Asia/Tehran',
  }) async {
    final userId = _requireUserId();

    final dateString = _dateOnly(date);

    try {
      final response = await _supabase
          .from('daily_metrics')
          .select()
          .eq('user_id', userId)
          .eq('date', dateString)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return Map<String, dynamic>.from(response);
    } catch (e) {
      print('[HealthDataRepository] Failed to load daily metric: $e');
      rethrow;
    }
  }

  Future<void> updateDailyMetrics({
    required DateTime date,
    String timezone = 'Asia/Tehran',
  }) async {
    final userId = _requireUserId();

    final dateString = _dateOnly(date);

    try {
      // The database function is responsible for aggregating the
      // hourly_metrics table into daily_metrics.
      //
      // This matches the architecture currently used by the background
      // service: events -> hourly aggregation -> daily aggregation.
      await _supabase.rpc(
        'calculate_daily_metrics',
        params: {
          'p_user_id': userId,
          'p_date': dateString,
          'p_timezone': timezone,
        },
      );
    } catch (e) {
      print(
        '[HealthDataRepository] RPC calculate_daily_metrics failed: $e',
      );

      // Do not silently swallow this. The caller should know that the
      // aggregation failed.
      rethrow;
    }
  }

  // ===========================================================================
  // HOURLY METRICS
  // ===========================================================================

  Future<List<Map<String, dynamic>>> getHourlyMetrics({
    int hours = 24,
  }) async {
    final userId = _requireUserId();

    if (hours <= 0) {
      return <Map<String, dynamic>>[];
    }

    try {
      final response = await _supabase
          .from('hourly_metrics')
          .select()
          .eq('user_id', userId)
          .order('hour_start', ascending: false)
          .limit(hours);

      return (response as List)
          .map(
            (row) => Map<String, dynamic>.from(
          row as Map,
        ),
      )
          .toList();
    } catch (e) {
      print('[HealthDataRepository] Failed to load hourly metrics: $e');
      rethrow;
    }
  }

  // ===========================================================================
  // WOMEN'S HEALTH
  // ===========================================================================

  Future<Map<String, dynamic>?> getWomensHealthProfile() async {
    final userId = _requireUserId();

    try {
      final response = await _supabase
          .from('womens_health_profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return Map<String, dynamic>.from(response);
    } catch (e) {
      print(
        '[HealthDataRepository] Failed to load women\'s health profile: $e',
      );
      rethrow;
    }
  }

  Future<Map<String, dynamic>> saveWomensHealthProfile({
    required DateTime lastPeriodStart,
    int cycleLength = 28,
    int periodLength = 5,
    String? timezone,
  }) async {
    final userId = _requireUserId();

    if (cycleLength < 15 || cycleLength > 90) {
      throw ArgumentError.value(
        cycleLength,
        'cycleLength',
        'Cycle length must be between 15 and 90 days.',
      );
    }

    if (periodLength < 1 || periodLength > 20) {
      throw ArgumentError.value(
        periodLength,
        'periodLength',
        'Period length must be between 1 and 20 days.',
      );
    }

    final payload = <String, dynamic>{
      'user_id': userId,
      'last_period_start': _dateOnly(lastPeriodStart),
      'cycle_length': cycleLength,
      'period_length': periodLength,
      'timezone': timezone ?? 'Asia/Tehran',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      final response = await _supabase
          .from('womens_health_profiles')
          .upsert(
        payload,
        onConflict: 'user_id',
      )
          .select()
          .single();

      return Map<String, dynamic>.from(response);
    } catch (e) {
      print(
        '[HealthDataRepository] Failed to save women\'s health profile: $e',
      );
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getPeriodHistory({
    int limit = 24,
  }) async {
    final userId = _requireUserId();

    if (limit <= 0) {
      return <Map<String, dynamic>>[];
    }

    try {
      final response = await _supabase
          .from('period_history')
          .select()
          .eq('user_id', userId)
          .order('period_start', ascending: false)
          .limit(limit);

      return (response as List)
          .map(
            (row) => Map<String, dynamic>.from(
          row as Map,
        ),
      )
          .toList();
    } catch (e) {
      print(
        '[HealthDataRepository] Failed to load period history: $e',
      );
      rethrow;
    }
  }

  Future<bool> recordPeriodStart(DateTime startDate) async {
    try {
      print('========== WOMENS HEALTH: RECORD PERIOD ==========');
      print('[WH] Received date: $startDate');
      print('[WH] Date only: ${startDate.year}-${startDate.month}-${startDate.day}');

      final user = _supabase.auth.currentUser;

      print('[WH] Current user: ${user?.id}');

      if (user == null) {
        print('[WH] ERROR: No authenticated user');
        return false;
      }

      final dateString =
          '${startDate.year.toString().padLeft(4, '0')}-'
          '${startDate.month.toString().padLeft(2, '0')}-'
          '${startDate.day.toString().padLeft(2, '0')}';

      print('[WH] Gregorian date being sent to Supabase: $dateString');

      final payload = {
        'user_id': user.id,
        'start_date': dateString,
      };

      print('[WH] Insert payload: $payload');

      final response = await _supabase
          .from('womens_health_periods')
          .insert(payload)
          .select();

      print('[WH] Supabase response: $response');
      print('[WH] Period successfully recorded');
      print('====================================================');

      return true;
    } catch (e, stackTrace) {
      print('========== WOMENS HEALTH: RECORD PERIOD ERROR ==========');
      print('[WH] Exception type: ${e.runtimeType}');
      print('[WH] Exception: $e');
      print('[WH] Stack trace:');
      print(stackTrace);
      print('========================================================');

      return false;
    }
  }

  // ===========================================================================
  // WOMEN'S HEALTH HELPERS
  // ===========================================================================

  Future<void> deletePeriodStart(DateTime periodStart) async {
    final userId = _requireUserId();

    await _supabase
        .from('period_history')
        .delete()
        .eq('user_id', userId)
        .eq('period_start', _dateOnly(periodStart));
  }

  Future<void> clearWomensHealthProfile() async {
    final userId = _requireUserId();

    await _supabase
        .from('womens_health_profiles')
        .delete()
        .eq('user_id', userId);
  }

  // ===========================================================================
  // UTILITIES
  // ===========================================================================

  String _dateOnly(DateTime date) {
    final local = date.toLocal();

    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');

    return '${local.year}-$month-$day';
  }

  int? _asInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString());
  }
}