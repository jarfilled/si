import 'dart:async';

import '../backend/health_data_repository.dart';
import 'local_monitoring_store.dart';

class MonitoringSyncService {
  MonitoringSyncService({
    required this.store,
    required this.repository,
  });

  final LocalMonitoringStore store;
  final HealthDataRepository repository;

  static const int eventBatchSize = 100;
  static const int hourlyBatchSize = 48;
  static const int immediateEventFlushThreshold = 25;

  Timer? _timer;
  bool _running = false;
  bool _flushInProgress = false;

  void start() {
    _timer?.cancel();

    _timer = Timer.periodic(
      const Duration(minutes: 15),
          (_) => unawaited(flush()),
    );
  }

  Future<void> flushIfNeeded() async {
    if (_running || _flushInProgress) {
      return;
    }

    final userId = repository.userId;
    if (userId == null) {
      return;
    }

    final count = await store.pendingEventCount(userId: userId);
    if (count >= immediateEventFlushThreshold) {
      await flush();
    }
  }

  Future<void> flush() async {
    if (_flushInProgress) {
      return;
    }

    _flushInProgress = true;

    try {
      final userId = repository.userId;

      if (userId == null) {
        return;
      }

      _running = true;

      bool dataChanged = false;

      // ------------------------------------------------------------
      // Upload pending health events
      // ------------------------------------------------------------

      while (true) {
        final events = await store.getPendingEvents(
          userId: userId,
          limit: eventBatchSize,
        );

        if (events.isEmpty) {
          break;
        }

        final uploadedIds =
        await repository.insertHealthEventsBatch(events);

        if (uploadedIds.isEmpty) {
          // Upload failed.
          // Keep the events in Hive for the next retry.
          break;
        }

        await store.deleteEvents(uploadedIds);

        dataChanged = true;

        if (uploadedIds.length < events.length) {
          break;
        }
      }

      // ------------------------------------------------------------
      // Upload dirty hourly metrics
      // ------------------------------------------------------------

      final hourly = await store.getDirtyHourlyMetrics(
        userId: userId,
        limit: hourlyBatchSize,
      );

      if (hourly.isNotEmpty) {
        final uploadedVersions =
        await repository.upsertHourlyMetricsBatch(hourly);

        if (uploadedVersions.isNotEmpty) {
          await store.markHourlyMetricsSynced(
            uploadedVersions: uploadedVersions,
          );

          dataChanged = true;
        }
      }

      // ------------------------------------------------------------
      // Recalculate daily metrics after successful uploads
      // ------------------------------------------------------------

      if (dataChanged) {
        final now = DateTime.now();

        await repository.updateDailyMetrics(
          date: DateTime(
            now.year,
            now.month,
            now.day,
          ),
          timezone: 'Asia/Tehran',
        );

        print(
          '[MonitoringSyncService] Daily metrics recalculated after sync.',
        );
      }
    } catch (e, stackTrace) {
      print('[MonitoringSyncService] Sync failed: $e');
      print(stackTrace);
    } finally {
      _running = false;
      _flushInProgress = false;
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
