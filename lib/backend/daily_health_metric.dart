class DailyHealthMetric {
  final DateTime date;

  final double neck;
  final double hunch;
  final double wrist;
  final double tooClose;
  final double badLight;

  final double screenTime;

  final int neckEvents;
  final int hunchEvents;
  final int wristEvents;
  final int tooCloseEvents;

  final int? healthScore;

  DailyHealthMetric({
    required this.date,
    required this.neck,
    required this.hunch,
    required this.wrist,
    required this.tooClose,
    required this.badLight,
    required this.screenTime,
    required this.neckEvents,
    required this.hunchEvents,
    required this.wristEvents,
    required this.tooCloseEvents,
    required this.healthScore,
  });

  factory DailyHealthMetric.fromMap(
      Map<String, dynamic> map,
      ) {
    double number(dynamic value) {
      if (value == null) return 0;

      if (value is num) {
        return value.toDouble();
      }

      return double.tryParse(value.toString()) ?? 0;
    }

    int integer(dynamic value) {
      if (value == null) return 0;

      if (value is num) {
        return value.toInt();
      }

      return int.tryParse(value.toString()) ?? 0;
    }

    return DailyHealthMetric(
      date: DateTime.parse(map['date'].toString()),
      neck: number(map['neck_bad_minutes']),
      hunch: number(map['hunch_bad_minutes']),
      wrist: number(map['wrist_bad_minutes']),
      tooClose: number(map['too_close_minutes']),
      badLight: number(map['bad_light_minutes']),
      screenTime: number(map['screen_time_minutes']),
      neckEvents: integer(map['neck_event_count']),
      hunchEvents: integer(map['hunch_event_count']),
      wristEvents: integer(map['wrist_event_count']),
      tooCloseEvents: integer(map['too_close_event_count']),
      healthScore: map['health_score'] == null
          ? null
          : integer(map['health_score']),
    );
  }
}