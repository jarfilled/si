import 'dart:async';
import 'dart:math';

import 'package:hive_flutter/hive_flutter.dart';

class LocalMonitoringStore {
  static const String _boxName = 'si_monitoring_store_v2';

  static final LocalMonitoringStore instance = LocalMonitoringStore._();

  LocalMonitoringStore._();

  Box<dynamic>? _box;
  Future<void> _operationQueue = Future<void>.value();

  Future<void> init() async {
    if (_box?.isOpen == true) {
      return;
    }

    await Hive.initFlutter();
    _box = await Hive.openBox<dynamic>(_boxName);
  }

  Box<dynamic> get _storage {
    final box = _box;
    if (box == null || !box.isOpen) {
      throw StateError(
        'LocalMonitoringStore.init() must be called before use.',
      );
    }
    return box;
  }

  Future<T> _serialized<T>(Future<T> Function() action) {
    final completer = Completer<T>();

    _operationQueue = _operationQueue.then((_) async {
      try {
        completer.complete(await action());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });

    return completer.future;
  }

  String _newEventId() {
    final random = Random.secure();

    String hex(int count) {
      final value = List<int>.generate(
        count,
            (_) => random.nextInt(256),
      );
      return value
          .map((e) => e.toRadixString(16).padLeft(2, '0'))
          .join();
    }

    // RFC-4122 version 4 UUID.
    final raw = List<int>.generate(16, (_) => random.nextInt(256));
    raw[6] = (raw[6] & 0x0f) | 0x40;
    raw[8] = (raw[8] & 0x3f) | 0x80;

    final bytes = raw.map((e) => e.toRadixString(16).padLeft(2, '0')).join();
    return '${bytes.substring(0, 8)}-'
        '${bytes.substring(8, 12)}-'
        '${bytes.substring(12, 16)}-'
        '${bytes.substring(16, 20)}-'
        '${bytes.substring(20)}';
  }

  Future<String?> enqueueHealthEvent({
    required String? userId,
    required String eventType,
    required DateTime startedAt,
    required DateTime endedAt,
    required double durationSeconds,
    double? severity,
    Map<String, dynamic>? metadata,
  }) {
    return _serialized(() async {
      if (durationSeconds <= 0) {
        return null;
      }

      final eventId = _newEventId();

      final event = <String, dynamic>{
        'event_id': eventId,
        'user_id': userId,
        'event_type': eventType,
        'started_at': startedAt.toUtc().toIso8601String(),
        'ended_at': endedAt.toUtc().toIso8601String(),
        'duration_seconds': durationSeconds,
        'severity': severity,
        'metadata': metadata,
      };

      await _storage.put('event:$eventId', event);

      await _addEventToHourlyAggregates(
        userId: userId,
        eventType: eventType,
        startedAt: startedAt.toUtc(),
        endedAt: endedAt.toUtc(),
        durationSeconds: durationSeconds,
      );

      return eventId;
    });
  }

  Future<List<Map<String, dynamic>>> getPendingEvents({
    String? userId,
    int limit = 100,
  }) {
    return _serialized(() async {
      final events = <Map<String, dynamic>>[];

      for (final key in _storage.keys) {
        if (!key.toString().startsWith('event:')) {
          continue;
        }

        final value = _storage.get(key);
        if (value is! Map) {
          continue;
        }

        final event = Map<String, dynamic>.from(value);
        if (userId != null && event['user_id'] != userId) {
          continue;
        }

        events.add(event);

        if (events.length >= limit) {
          break;
        }
      }

      events.sort(
            (a, b) => (a['started_at']?.toString() ?? '')
            .compareTo(b['started_at']?.toString() ?? ''),
      );

      return events;
    });
  }

  Future<void> deleteEvents(Iterable<String> eventIds) {
    return _serialized(() async {
      for (final eventId in eventIds) {
        await _storage.delete('event:$eventId');
      }
    });
  }

  Future<int> pendingEventCount({String? userId}) {
    return _serialized(() async {
      var count = 0;

      for (final key in _storage.keys) {
        if (!key.toString().startsWith('event:')) {
          continue;
        }

        final value = _storage.get(key);
        if (value is! Map) {
          continue;
        }

        if (userId == null || value['user_id'] == userId) {
          count++;
        }
      }

      return count;
    });
  }

  Future<void> _addEventToHourlyAggregates({
    required String? userId,
    required String eventType,
    required DateTime startedAt,
    required DateTime endedAt,
    required double durationSeconds,
  }) async {
    var cursor = startedAt;
    final end = endedAt.isAfter(startedAt)
        ? endedAt
        : startedAt.add(
      Duration(
        milliseconds: (durationSeconds * 1000).round(),
      ),
    );

    bool firstBucket = true;

    while (cursor.isBefore(end)) {
      final hourStart = DateTime.utc(
        cursor.year,
        cursor.month,
        cursor.day,
        cursor.hour,
      );

      final nextHour = hourStart.add(const Duration(hours: 1));
      final segmentEnd = end.isBefore(nextHour) ? end : nextHour;
      final segmentSeconds =
          segmentEnd.difference(cursor).inMilliseconds / 1000.0;

      if (segmentSeconds > 0) {
        await _addHourlyDelta(
          userId: userId,
          hourStart: hourStart,
          eventType: eventType,
          seconds: segmentSeconds,
          countEvent: firstBucket,
        );
      }

      firstBucket = false;
      cursor = segmentEnd;
    }
  }

  Future<void> _addHourlyDelta({
    required String? userId,
    required DateTime hourStart,
    required String eventType,
    required double seconds,
    required bool countEvent,
  }) async {
    final key = 'hour:${hourStart.toIso8601String()}';

    final existing = _storage.get(key);
    final data = existing is Map
        ? Map<String, dynamic>.from(existing)
        : <String, dynamic>{
      'user_id': userId,
      'hour_start': hourStart.toIso8601String(),
      'version': 0,
      'synced_version': -1,
      'screen_time_seconds': 0,
      'hunch_bad_seconds': 0.0,
      'neck_bad_seconds': 0.0,
      'wrist_bad_seconds': 0.0,
      'too_close_seconds': 0.0,
      'low_light_seconds': 0.0,
      'hunch_event_count': 0,
      'neck_event_count': 0,
      'wrist_event_count': 0,
      'too_close_event_count': 0,
      'low_light_event_count': 0,
    };

    if (data['user_id'] == null) {
      data['user_id'] = userId;
    }

    final secondsField = switch (eventType) {
      'hunch' => 'hunch_bad_seconds',
      'neck' => 'neck_bad_seconds',
      'wrist' => 'wrist_bad_seconds',
      'too_close' => 'too_close_seconds',
      'low_light' => 'low_light_seconds',
      _ => null,
    };

    final countField = switch (eventType) {
      'hunch' => 'hunch_event_count',
      'neck' => 'neck_event_count',
      'wrist' => 'wrist_event_count',
      'too_close' => 'too_close_event_count',
      'low_light' => 'low_light_event_count',
      _ => null,
    };

    if (secondsField != null) {
      data[secondsField] =
          ((data[secondsField] as num?)?.toDouble() ?? 0.0) + seconds;
    }

    if (countEvent && countField != null) {
      data[countField] =
          ((data[countField] as num?)?.toInt() ?? 0) + 1;
    }

    data['version'] = ((data['version'] as num?)?.toInt() ?? 0) + 1;

    await _storage.put(key, data);
  }

  Future<List<Map<String, dynamic>>> getDirtyHourlyMetrics({
    String? userId,
    int limit = 48,
  }) {
    return _serialized(() async {
      final metrics = <Map<String, dynamic>>[];

      for (final key in _storage.keys) {
        if (!key.toString().startsWith('hour:')) {
          continue;
        }

        final value = _storage.get(key);
        if (value is! Map) {
          continue;
        }

        final row = Map<String, dynamic>.from(value);
        if (userId != null && row['user_id'] != userId) {
          continue;
        }

        final version = (row['version'] as num?)?.toInt() ?? 0;
        final syncedVersion =
            (row['synced_version'] as num?)?.toInt() ?? -1;

        if (version <= syncedVersion) {
          continue;
        }

        metrics.add(row);

        if (metrics.length >= limit) {
          break;
        }
      }

      metrics.sort(
            (a, b) => (a['hour_start']?.toString() ?? '')
            .compareTo(b['hour_start']?.toString() ?? ''),
      );

      return metrics;
    });
  }

  Future<void> markHourlyMetricsSynced({
    required Map<String, int> uploadedVersions,
  }) {
    return _serialized(() async {
      for (final entry in uploadedVersions.entries) {
        final key = 'hour:${entry.key}';
        final value = _storage.get(key);
        if (value is! Map) {
          continue;
        }

        final row = Map<String, dynamic>.from(value);
        final currentVersion =
            (row['version'] as num?)?.toInt() ?? 0;

        // Do not mark a newer local version as synced.
        if (currentVersion == entry.value) {
          row['synced_version'] = entry.value;
          await _storage.put(key, row);
        }
      }
    });
  }

  Future<void> close() async {
    final box = _box;
    _box = null;
    if (box != null && box.isOpen) {
      await box.close();
    }
  }
}
