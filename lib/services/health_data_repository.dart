import 'package:supabase_flutter/supabase_flutter.dart';

class HealthDataRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> recordHealthEvent({
    required String eventType,
    required DateTime startedAt,
    required DateTime endedAt,
    double? durationSeconds,
  }) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception(
        'Cannot record health event: user is not logged in.',
      );
    }

    await _supabase.from('health_events').insert({
      'user_id': user.id,
      'event_type': eventType,
      'started_at': startedAt.toUtc().toIso8601String(),
      'ended_at': endedAt.toUtc().toIso8601String(),
      'duration_seconds': durationSeconds,
    });
  }

  Future<List<Map<String, dynamic>>> getEventsForDay(
      DateTime day,
      ) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      return [];
    }

    final start = DateTime.utc(
      day.year,
      day.month,
      day.day,
    );

    final end = start.add(const Duration(days: 1));

    final response = await _supabase
        .from('health_events')
        .select()
        .eq('user_id', user.id)
        .gte('started_at', start.toIso8601String())
        .lt('started_at', end.toIso8601String())
        .order('started_at', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getEventsBetween(
      DateTime start,
      DateTime end,
      ) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      return [];
    }

    final response = await _supabase
        .from('health_events')
        .select()
        .eq('user_id', user.id)
        .gte('started_at', start.toUtc().toIso8601String())
        .lt('started_at', end.toUtc().toIso8601String())
        .order('started_at', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }
}
