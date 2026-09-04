import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../backend/womens_health_share_service.dart';
import 'womens_health_sharing_card.dart';

class WomensHealthPage extends StatefulWidget {
  const WomensHealthPage({super.key});

  @override
  State<WomensHealthPage> createState() => _WomensHealthPageState();
}

class _WomensHealthPageState extends State<WomensHealthPage> {
  static const green = Color(0xFF42D2A7);
  static const teal = Color(0xFF45C4D0);
  static const darkTeal = Color(0xFF145954);
  static const bg = Color(0xFFF7F9F9);
  static const pink = Color(0xFFFFA5B7);
  static const lightPink = Color(0xFFFFEEF2);
  static const muted = Color(0xFF71807F);
  static const line = Color(0xFFE8EFEC);

  static const List<String> _jalaliMonthNames = [
    'فروردین',
    'اردیبهشت',
    'خرداد',
    'تیر',
    'مرداد',
    'شهریور',
    'مهر',
    'آبان',
    'آذر',
    'دی',
    'بهمن',
    'اسفند',
  ];

  // Jalali weekDay in shamsi_date:
  // 1 = Saturday, ..., 7 = Friday.
  static const List<String> _weekDayNames = [
    'ش',
    'ی',
    'د',
    'س',
    'چ',
    'پ',
    'ج',
  ];

  final SupabaseClient _supabase = Supabase.instance.client;

  final TextEditingController noteController = TextEditingController();

  int pain = 0;
  int mood = 3;
  int energy = 3;

  bool heat = false;
  bool hydration = false;
  bool movement = false;
  bool socialReminder = false;

  DateTime? latestPeriodStart;
  int cycleLength = 28;

  List<Map<String, dynamic>> periodHistory = [];
  List<Map<String, dynamic>> dailyLogs = [];

  bool loading = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    _loadHealthData();
  }

  @override
  void dispose() {
    noteController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // DATE HELPERS
  // ===========================================================================

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  String _formatDate(DateTime date) {
    final d = _dateOnly(date);

    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;

    final parsed = DateTime.tryParse(value.toString());

    if (parsed == null) return null;

    return _dateOnly(parsed);
  }

  Jalali _toJalali(DateTime date) {
    return Jalali.fromDateTime(date);
  }

  DateTime _fromJalali(Jalali date) {
    return _dateOnly(date.toDateTime());
  }

  String _persianDigits(String value) {
    const western = '0123456789';
    const persian = '۰۱۲۳۴۵۶۷۸۹';

    return value.split('').map((character) {
      final index = western.indexOf(character);

      if (index == -1) {
        return character;
      }

      return persian[index];
    }).join();
  }

  String _number(int number) {
    return _persianDigits(number.toString());
  }

  String _jalaliDateString(DateTime date) {
    final j = _toJalali(date);

    return '${_number(j.year)}/${_number(j.month)}/${_number(j.day)}';
  }

  String _jalaliLongDate(DateTime date) {
    final j = _toJalali(date);

    return '${_number(j.day)} ${_jalaliMonthNames[j.month - 1]} '
        '${_number(j.year)}';
  }

  bool _sameDate(DateTime a, DateTime b) {
    return a.year == b.year &&
        a.month == b.month &&
        a.day == b.day;
  }

  // ===========================================================================
  // SUPABASE
  // ===========================================================================

  String? get _userId => _supabase.auth.currentUser?.id;

  Future<void> _loadHealthData() async {
    final userId = _userId;

    if (userId == null) {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
      return;
    }

    try {
      final profileResponse = await _supabase
          .from('womens_health_profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      final periodsResponse = await _supabase
          .from('womens_health_periods')
          .select()
          .eq('user_id', userId)
          .order('start_date', ascending: false);

      final logsResponse = await _supabase
          .from('womens_health_daily_logs')
          .select()
          .eq('user_id', userId)
          .order('log_date', ascending: false)
          .limit(30);

      final periods = List<Map<String, dynamic>>.from(
        periodsResponse,
      );

      final logs = List<Map<String, dynamic>>.from(
        logsResponse,
      );

      DateTime? startDate;

      // Prefer the actual period-history table.
      if (periods.isNotEmpty) {
        startDate = _parseDate(periods.first['start_date']);
      }

      // Fall back to the profile table.
      if (startDate == null && profileResponse != null) {
        startDate = _parseDate(
          profileResponse['cycle_start_date'],
        );
      }

      int calculatedCycleLength = 28;

      if (profileResponse != null) {
        final rawLength = profileResponse['cycle_length_days'];

        if (rawLength is num) {
          calculatedCycleLength = rawLength.toInt();
        }
      }

      // If several period starts exist, calculate an average.
      if (periods.length >= 2) {
        final lengths = <int>[];

        for (int i = 0; i < periods.length - 1; i++) {
          final current = _parseDate(
            periods[i]['start_date'],
          );

          final previous = _parseDate(
            periods[i + 1]['start_date'],
          );

          if (current == null || previous == null) {
            continue;
          }

          final difference = current.difference(previous).inDays;

          if (difference >= 15 && difference <= 60) {
            lengths.add(difference);
          }
        }

        if (lengths.isNotEmpty) {
          calculatedCycleLength =
              (lengths.reduce((a, b) => a + b) / lengths.length).round();
        }
      }

      final today = _dateOnly(DateTime.now());

      Map<String, dynamic>? todayLog;

      for (final log in logs) {
        final logDate = _parseDate(log['log_date']);

        if (logDate != null && _sameDate(logDate, today)) {
          todayLog = log;
          break;
        }
      }

      if (!mounted) return;

      setState(() {
        periodHistory = periods;
        dailyLogs = logs;

        latestPeriodStart = startDate;

        cycleLength = calculatedCycleLength.clamp(15, 60);

        if (profileResponse != null) {
          socialReminder =
              profileResponse['social_reminder_enabled'] == true;
        }

        if (todayLog != null) {
          pain = _safeInt(todayLog['pain'], 0).clamp(0, 10);
          mood = _safeInt(todayLog['mood'], 3).clamp(1, 5);
          energy = _safeInt(todayLog['energy'], 3).clamp(1, 5);

          heat = todayLog['heat_used'] == true;
          hydration = todayLog['hydration_ok'] == true;
          movement = todayLog['movement_done'] == true;

          noteController.text =
              todayLog['note']?.toString() ?? '';
        }

        loading = false;
      });

      // Only show setup if there genuinely is no known cycle start.
      if (startDate == null && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showPeriodSetupDialog();
          }
        });
      }
    } catch (e) {
      debugPrint('Womens health load error: $e');

      if (!mounted) return;

      setState(() {
        loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('بارگذاری اطلاعات سلامت زنان انجام نشد.'),
        ),
      );
    }
  }

  int _safeInt(dynamic value, int fallback) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  // ===========================================================================
  // PERIOD SAVING
  // ===========================================================================

  Future<void> _savePeriodStart(DateTime date) async {
    final userId = _userId;

    debugPrint('========== SAVE PERIOD START ==========');
    debugPrint('User ID: $userId');
    debugPrint('Selected DateTime: $date');
    debugPrint('Cycle Length: $cycleLength');
    debugPrint('Social Reminder: $socialReminder');

    if (userId == null) {
      debugPrint('PERIOD SAVE FAILED: userId is null');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ابتدا وارد حساب کاربری خود شوید.'),
          ),
        );
      }

      return;
    }

    final cleanDate = _dateOnly(date);
    final dateString = _formatDate(cleanDate);

    debugPrint('Clean Date: $cleanDate');
    debugPrint('Date String sent to Supabase: $dateString');

    try {
      // ------------------------------------------------------------
      // STEP 1: Check whether this period already exists
      // ------------------------------------------------------------

      debugPrint('STEP 1: Checking for existing period...');

      final existing = await _supabase
          .from('womens_health_periods')
          .select('id')
          .eq('user_id', userId)
          .eq('start_date', dateString)
          .limit(1);

      debugPrint('STEP 1 SUCCESS');
      debugPrint('Existing period rows: ${existing.length}');

      // ------------------------------------------------------------
      // STEP 2: Insert period if it doesn't already exist
      // ------------------------------------------------------------

      if (existing.isEmpty) {
        debugPrint('STEP 2: Inserting period...');
        debugPrint(
          'Insert data: '
              '{user_id: $userId, start_date: $dateString}',
        );

        final inserted = await _supabase
            .from('womens_health_periods')
            .insert({
          'user_id': userId,
          'start_date': dateString,
        })
            .select();

        debugPrint('STEP 2 SUCCESS');
        debugPrint('Inserted row: $inserted');
      } else {
        debugPrint('STEP 2 SKIPPED: Period already exists');
      }

      // ------------------------------------------------------------
      // STEP 3: Update women's health profile
      // ------------------------------------------------------------

      debugPrint('STEP 3: Updating womens_health_profiles...');

      final profileData = {
        'user_id': userId,
        'cycle_start_date': dateString,
        'cycle_length_days': cycleLength,
        'social_reminder_enabled': socialReminder,
      };

      debugPrint('Profile data: $profileData');

      final profileResult = await _supabase
          .from('womens_health_profiles')
          .upsert(
        profileData,
        onConflict: 'user_id',
      )
          .select();

      debugPrint('STEP 3 SUCCESS');
      debugPrint('Profile result: $profileResult');

      // ------------------------------------------------------------
      // STEP 4: Update local state
      // ------------------------------------------------------------

      if (!mounted) {
        debugPrint('Widget no longer mounted after save.');
        return;
      }

      setState(() {
        latestPeriodStart = cleanDate;
      });

      debugPrint('STEP 4 SUCCESS: Local state updated.');

      // ------------------------------------------------------------
      // STEP 5: Reload health data
      // ------------------------------------------------------------

      debugPrint('STEP 5: Reloading health data...');

      await _loadHealthData();

      debugPrint('STEP 5 SUCCESS');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تاریخ شروع قاعدگی ثبت شد.'),
        ),
      );

      debugPrint('========== SAVE PERIOD SUCCESS ==========');
    } on PostgrestException catch (e, stackTrace) {
      debugPrint('========== SUPABASE ERROR ==========');
      debugPrint('Message: ${e.message}');
      debugPrint('Code: ${e.code}');
      debugPrint('Details: ${e.details}');
      debugPrint('Hint: ${e.hint}');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('====================================');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'خطای Supabase: ${e.message}',
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('========== PERIOD SAVE ERROR ==========');
      debugPrint('Error type: ${e.runtimeType}');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('======================================');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'خطا: $e',
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  // ===========================================================================
  // DAILY LOG
  // ===========================================================================

  Future<void> _saveToday() async {
    final userId = _userId;

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ابتدا وارد حساب کاربری خود شوید.'),
        ),
      );
      return;
    }

    setState(() {
      saving = true;
    });

    try {
      final today = _dateOnly(DateTime.now());
      final dateString = _formatDate(today);

      final payload = {
        'user_id': userId,
        'log_date': dateString,
        'pain': pain,
        'mood': mood,
        'energy': energy,
        'heat_used': heat,
        'hydration_ok': hydration,
        'movement_done': movement,
        'social_reminder_enabled': socialReminder,
        'note': noteController.text.trim().isEmpty
            ? null
            : noteController.text.trim(),
      };

      // Your schema does NOT declare a UNIQUE(user_id, log_date)
      // constraint. Therefore do not use an upsert with
      // onConflict: 'user_id,log_date'.
      final existing = await _supabase
          .from('womens_health_daily_logs')
          .select('id')
          .eq('user_id', userId)
          .eq('log_date', dateString)
          .limit(1);

      if (existing.isNotEmpty) {
        final id = existing.first['id'];

        await _supabase
            .from('womens_health_daily_logs')
            .update(payload)
            .eq('id', id);
      } else {
        await _supabase
            .from('womens_health_daily_logs')
            .insert(payload);
      }

      await _supabase.from('womens_health_profiles').upsert(
        {
          'user_id': userId,
          'cycle_start_date': latestPeriodStart == null
              ? null
              : _formatDate(latestPeriodStart!),
          'cycle_length_days': cycleLength,
          'social_reminder_enabled': socialReminder,
        },
        onConflict: 'user_id',
      );

      // Send the optional daily mood/pain copy only after the health log
      // has been successfully written. Email failures are isolated inside
      // WomensHealthShareService and cannot turn a successful save into a
      // failed registration.
      await WomensHealthShareService.sendTodayIfEnabled(
        userId: userId,
        date: today,
        pain: pain,
        mood: mood,
      );

      await _loadHealthData();

      if (!mounted) return;

      FocusScope.of(context).unfocus();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('اطلاعات امروز با موفقیت ثبت شد.'),
        ),
      );
    } catch (e) {
      debugPrint('Womens health save error: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ثبت اطلاعات انجام نشد: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  Future<void> _updateSocialReminder(bool value) async {
    setState(() {
      socialReminder = value;
    });

    final userId = _userId;

    if (userId == null) return;

    try {
      await _supabase.from('womens_health_profiles').upsert(
        {
          'user_id': userId,
          'cycle_start_date': latestPeriodStart == null
              ? null
              : _formatDate(latestPeriodStart!),
          'cycle_length_days': cycleLength,
          'social_reminder_enabled': value,
        },
        onConflict: 'user_id',
      );
    } catch (e) {
      debugPrint('Social reminder save error: $e');
    }
  }

  // ===========================================================================
  // JALALI CALENDAR
  // ===========================================================================

  Future<DateTime?> _pickJalaliDate({
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
    String title = 'انتخاب تاریخ',
  }) async {
    final initial = _toJalali(initialDate);
    final minimum = _toJalali(firstDate);
    final maximum = _toJalali(lastDate);

    Jalali selected = initial;

    // Make sure the initial date is inside the allowed range.
    if (selected < minimum) {
      selected = minimum;
    }

    if (selected > maximum) {
      selected = maximum;
    }

    Jalali visibleMonth = selected.copy(day: 1);

    return showDialog<DateTime>(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              final days = visibleMonth.monthLength;

              // Saturday = 1 in shamsi_date.
              // We convert it to zero-based index.
              final firstWeekday = visibleMonth.weekDay - 1;

              return AlertDialog(
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 24,
                ),
                titlePadding: const EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  8,
                ),
                contentPadding: const EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  8,
                ),
                actionsPadding: const EdgeInsets.fromLTRB(
                  16,
                  4,
                  16,
                  12,
                ),
                title: Row(
                  children: [
                    const Icon(
                      Icons.calendar_month_rounded,
                      color: pink,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: darkTeal,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                content: SizedBox(
                  width: 340,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            tooltip: 'ماه بعد',
                            onPressed: _canMoveToNextMonth(
                              visibleMonth,
                              maximum,
                            )
                                ? () {
                              setDialogState(() {
                                visibleMonth =
                                    _nextMonth(visibleMonth);
                              });
                            }
                                : null,
                            icon: const Icon(
                              Icons.chevron_right_rounded,
                              color: darkTeal,
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                '${_jalaliMonthNames[visibleMonth.month - 1]} '
                                    '${_number(visibleMonth.year)}',
                                style: const TextStyle(
                                  color: darkTeal,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'ماه قبل',
                            onPressed: _canMoveToPreviousMonth(
                              visibleMonth,
                              minimum,
                            )
                                ? () {
                              setDialogState(() {
                                visibleMonth =
                                    _previousMonth(visibleMonth);
                              });
                            }
                                : null,
                            icon: const Icon(
                              Icons.chevron_left_rounded,
                              color: darkTeal,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: lightPink,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: _weekDayNames.map((day) {
                            return Expanded(
                              child: Center(
                                child: Text(
                                  day,
                                  style: const TextStyle(
                                    color: pink,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 6),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: firstWeekday + days,
                        gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          mainAxisSpacing: 4,
                          crossAxisSpacing: 4,
                        ),
                        itemBuilder: (context, index) {
                          if (index < firstWeekday) {
                            return const SizedBox.shrink();
                          }

                          final day = index - firstWeekday + 1;

                          final date = visibleMonth.copy(
                            day: day,
                          );

                          final isSelected = date == selected;
                          final isToday = date == Jalali.now();

                          final isBeforeMinimum =
                              date < minimum;

                          final isAfterMaximum =
                              date > maximum;

                          final disabled =
                              isBeforeMinimum || isAfterMaximum;

                          return InkWell(
                            borderRadius: BorderRadius.circular(11),
                            onTap: disabled
                                ? null
                                : () {
                              setDialogState(() {
                                selected = date;
                              });
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? pink
                                    : isToday
                                    ? lightPink
                                    : Colors.transparent,
                                borderRadius:
                                BorderRadius.circular(11),
                                border: isToday && !isSelected
                                    ? Border.all(
                                  color: pink,
                                  width: 1,
                                )
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  _number(day),
                                  style: TextStyle(
                                    color: disabled
                                        ? Colors.grey.shade300
                                        : isSelected
                                        ? Colors.white
                                        : darkTeal,
                                    fontSize: 12,
                                    fontWeight: isSelected ||
                                        isToday
                                        ? FontWeight.w900
                                        : FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.event_rounded,
                              color: pink,
                              size: 18,
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                _jalaliLongDate(
                                  _fromJalali(selected),
                                ),
                                style: const TextStyle(
                                  color: darkTeal,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                    },
                    child: const Text('انصراف'),
                  ),
                  FilledButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop(
                        _fromJalali(selected),
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: green,
                      foregroundColor: darkTeal,
                    ),
                    child: const Text(
                      'انتخاب',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Jalali _nextMonth(Jalali date) {
    if (date.month == 12) {
      return Jalali(date.year + 1, 1, 1);
    }

    return Jalali(date.year, date.month + 1, 1);
  }

  Jalali _previousMonth(Jalali date) {
    if (date.month == 1) {
      return Jalali(date.year - 1, 12, 1);
    }

    return Jalali(date.year, date.month - 1, 1);
  }

  bool _canMoveToNextMonth(
      Jalali visibleMonth,
      Jalali maximum,
      ) {
    final next = _nextMonth(visibleMonth);

    return next <= maximum.copy(day: 1);
  }

  bool _canMoveToPreviousMonth(
      Jalali visibleMonth,
      Jalali minimum,
      ) {
    final previous = _previousMonth(visibleMonth);

    return previous >= minimum.copy(day: 1);
  }

  // ===========================================================================
  // PERIOD DIALOGS
  // ===========================================================================

  Future<void> _showPeriodSetupDialog() async {
    DateTime selectedDate = latestPeriodStart ?? DateTime.now();

    final picked = await _pickJalaliDate(
      initialDate: selectedDate,
      firstDate: DateTime.now().subtract(
        const Duration(days: 365 * 3),
      ),
      lastDate: DateTime.now(),
      title: 'شروع آخرین قاعدگی',
    );

    if (picked != null && mounted) {
      await _savePeriodStart(picked);
    }
  }

  Future<void> _showPeriodHistoryDialog() async {
    DateTime selectedDate = DateTime.now();

    final picked = await _pickJalaliDate(
      initialDate: selectedDate,
      firstDate: DateTime.now().subtract(
        const Duration(days: 365 * 3),
      ),
      lastDate: DateTime.now(),
      title: 'ثبت شروع قاعدگی',
    );

    if (picked != null && mounted) {
      await _savePeriodStart(picked);
    }
  }

  // ===========================================================================
  // CYCLE CALCULATIONS
  // ===========================================================================

  int get currentCycleDay {
    if (latestPeriodStart == null) {
      return 0;
    }

    final today = _dateOnly(DateTime.now());
    final start = _dateOnly(latestPeriodStart!);

    final difference = today.difference(start).inDays;

    if (difference < 0) {
      return 0;
    }

    return difference + 1;
  }

  DateTime? get estimatedNextPeriod {
    if (latestPeriodStart == null) {
      return null;
    }

    return _dateOnly(
      latestPeriodStart!.add(
        Duration(days: cycleLength),
      ),
    );
  }

  double get cycleProgress {
    if (currentCycleDay <= 0) {
      return 0;
    }

    return (currentCycleDay / cycleLength).clamp(0.0, 1.0);
  }

  String get cyclePhase {
    final day = currentCycleDay;

    if (day <= 0) {
      return 'ثبت نشده';
    }

    // Broad informational categories, not medical predictions.
    if (day <= 5) {
      return 'قاعدگی';
    }

    if (day <= cycleLength ~/ 2) {
      return 'فاز فولیکولی';
    }

    if (day <= (cycleLength * 0.6).round()) {
      return 'حوالی تخمک‌گذاری';
    }

    return 'فاز لوتئال';
  }

  // ===========================================================================
  // CHART DATA
  // ===========================================================================

  List<double> get painHistory {
    return _sevenDayValues('pain', 0);
  }

  List<double> get moodHistory {
    return _sevenDayValues('mood', 3);
  }

  List<double> get energyHistory {
    return _sevenDayValues('energy', 3);
  }

  List<double> _sevenDayValues(
      String field,
      int defaultValue,
      ) {
    final today = _dateOnly(DateTime.now());

    final values = <double>[];

    for (int i = 6; i >= 0; i--) {
      final date = today.subtract(
        Duration(days: i),
      );

      Map<String, dynamic>? matchingLog;

      for (final log in dailyLogs) {
        final logDate = _parseDate(
          log['log_date'],
        );

        if (logDate != null && _sameDate(logDate, date)) {
          matchingLog = log;
          break;
        }
      }

      if (matchingLog == null) {
        values.add(defaultValue.toDouble());
      } else {
        values.add(
          (matchingLog[field] as num?)?.toDouble() ??
              defaultValue.toDouble(),
        );
      }
    }

    return values;
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: const Text(
            'سلامت و قاعدگی',
            style: TextStyle(
              color: darkTeal,
              fontWeight: FontWeight.w900,
            ),
          ),
          iconTheme: const IconThemeData(
            color: darkTeal,
          ),
          actions: [
            IconButton(
              tooltip: 'ثبت قاعدگی',
              onPressed: _showPeriodHistoryDialog,
              icon: const Icon(
                Icons.event_available_rounded,
              ),
            ),
          ],
        ),
        body: loading
            ? const Center(
          child: CircularProgressIndicator(
            color: green,
          ),
        )
            : LayoutBuilder(
          builder: (context, constraints) {
            final horizontal =
                constraints.maxWidth >= 700;

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                horizontal ? 28 : 16,
                4,
                horizontal ? 28 : 16,
                32,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints:
                  const BoxConstraints(
                    maxWidth: 980,
                  ),
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                    children: [
                      _cycleOverview(),
                      const SizedBox(height: 14),
                      _statusCard(),
                      const SizedBox(height: 20),
                      _section('وضعیت امروز'),
                      const SizedBox(height: 10),
                      if (horizontal)
                        Row(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _painCard(),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child:
                              _moodEnergyCard(),
                            ),
                          ],
                        )
                      else ...[
                        _painCard(),
                        const SizedBox(height: 12),
                        _moodEnergyCard(),
                      ],
                      const SizedBox(height: 20),
                      _section('روند علائم'),
                      const SizedBox(height: 10),
                      if (horizontal)
                        Row(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _chartCard(
                                'روند درد',
                                '۷ روز گذشته',
                                painHistory,
                                10,
                                pink,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _chartCard(
                                'خلق‌وخو و انرژی',
                                'مقایسه هفت روز گذشته',
                                moodHistory,
                                5,
                                green,
                                secondary:
                                energyHistory,
                              ),
                            ),
                          ],
                        )
                      else ...[
                        _chartCard(
                          'روند درد',
                          '۷ روز گذشته',
                          painHistory,
                          10,
                          pink,
                        ),
                        const SizedBox(height: 12),
                        _chartCard(
                          'خلق‌وخو و انرژی',
                          'مقایسه هفت روز گذشته',
                          moodHistory,
                          5,
                          green,
                          secondary:
                          energyHistory,
                        ),
                      ],
                      const SizedBox(height: 20),
                      _section('مراقبت امروز'),
                      const SizedBox(height: 10),
                      _careCard(),
                      const SizedBox(height: 12),
                      _socialCard(),
                      const SizedBox(height: 20),
                      _section('اشتراک‌گذاری'),
                      const SizedBox(height: 10),
                      const WomensHealthSharingCard(),
                      const SizedBox(height: 20),
                      _dailyLog(),
                      const SizedBox(height: 12),
                      _safetyCard(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ===========================================================================
  // CYCLE CARD
  // ===========================================================================

  Widget _cycleOverview() {
    final day = currentCycleDay;

    final hasCycle = latestPeriodStart != null && day > 0;

    return _card(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            children: [
              _iconBox(
                Icons.calendar_month_rounded,
                pink,
                lightPink,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'چرخه فعلی',
                      style: TextStyle(
                        color: muted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      hasCycle
                          ? 'روز ${_number(day)} از حدود ${_number(cycleLength)} روز'
                          : 'تاریخ شروع چرخه ثبت نشده',
                      style: const TextStyle(
                        color: darkTeal,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: lightPink,
                    borderRadius:
                    BorderRadius.circular(11),
                  ),
                  child: Text(
                    cyclePhase,
                    style: const TextStyle(
                      color: pink,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius:
            BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: cycleProgress,
              minHeight: 9,
              backgroundColor: bg,
              valueColor:
              const AlwaysStoppedAnimation(
                pink,
              ),
            ),
          ),
          const SizedBox(height: 9),
          Row(
            mainAxisAlignment:
            MainAxisAlignment.spaceBetween,
            children: [
              Text(
                latestPeriodStart == null
                    ? 'شروع چرخه'
                    : _jalaliDateString(
                  latestPeriodStart!,
                ),
                style: const TextStyle(
                  color: muted,
                  fontSize: 9,
                ),
              ),
              Text(
                hasCycle
                    ? 'روز ${_number(day)}'
                    : 'ثبت تاریخ',
                style: const TextStyle(
                  color: pink,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                estimatedNextPeriod == null
                    ? 'چرخه بعدی'
                    : _jalaliDateString(
                  estimatedNextPeriod!,
                ),
                style: const TextStyle(
                  color: muted,
                  fontSize: 9,
                ),
              ),
            ],
          ),
          if (latestPeriodStart != null) ...[
            const SizedBox(height: 10),
            InkWell(
              onTap: _showPeriodHistoryDialog,
              borderRadius: BorderRadius.circular(11),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius:
                  BorderRadius.circular(11),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.edit_calendar_rounded,
                      size: 16,
                      color: pink,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'ثبت شروع یک چرخه دیگر',
                      style: const TextStyle(
                        color: darkTeal,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // STATUS
  // ===========================================================================

  Widget _statusCard() {
    final significant =
        pain >= 7 || mood <= 2;

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            pink.withValues(alpha: .18),
            green.withValues(alpha: .08),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius:
        BorderRadius.circular(20),
        border: Border.all(
          color: pink.withValues(alpha: .22),
        ),
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white
                  .withValues(alpha: .85),
              shape: BoxShape.circle,
            ),
            child: Icon(
              significant
                  ? Icons.favorite_border_rounded
                  : Icons.spa_rounded,
              color: pink,
              size: 25,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  significant
                      ? 'امروز کمی بیشتر مراقب خودت باش'
                      : 'وضعیت امروزت ثبت شد',
                  style: const TextStyle(
                    color: darkTeal,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  significant
                      ? 'علائم ثبت‌شده نشان می‌دهند بهتر است امروز فشار کمتری به خودت وارد کنی.'
                      : 'ثبت روزانه به سی کمک می‌کند الگوی علائم را در طول زمان بهتر نشان دهد.',
                  style: const TextStyle(
                    color: muted,
                    fontSize: 11,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // PAIN
  // ===========================================================================

  Widget _painCard() {
    return _card(
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          _metricHeader(
            Icons.monitor_heart_outlined,
            pink,
            lightPink,
            'میزان درد امروز',
            'شدت درد را از ۰ تا ۱۰ مشخص کن',
            '$pain/10',
          ),
          const SizedBox(height: 13),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor:
              _painColor(pain),
              inactiveTrackColor: bg,
              thumbColor: _painColor(pain),
              overlayColor:
              _painColor(pain)
                  .withValues(alpha: .12),
              trackHeight: 7,
            ),
            child: Slider(
              min: 0,
              max: 10,
              divisions: 10,
              value: pain.toDouble(),
              onChanged: (value) {
                setState(() {
                  pain = value.round();
                });
              },
            ),
          ),
          const Row(
            mainAxisAlignment:
            MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'بدون درد',
                style: TextStyle(
                  color: muted,
                  fontSize: 9,
                ),
              ),
              Text(
                'متوسط',
                style: TextStyle(
                  color: muted,
                  fontSize: 9,
                ),
              ),
              Text(
                'شدید',
                style: TextStyle(
                  color: muted,
                  fontSize: 9,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: _painColor(pain)
                  .withValues(alpha: .08),
              borderRadius:
              BorderRadius.circular(13),
            ),
            child: Row(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Icon(
                  pain >= 8
                      ? Icons.warning_amber_rounded
                      : Icons.favorite_border_rounded,
                  color: _painColor(pain),
                  size: 21,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _painMessage(),
                    style: const TextStyle(
                      color: muted,
                      fontSize: 10,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _painMessage() {
    if (pain <= 2) {
      return 'درد خفیف است؛ مراقبت معمول و استراحت کوتاه می‌تواند کافی باشد.';
    }

    if (pain <= 5) {
      return 'اگر لازم است، شدت فعالیت را کمتر کن و از مراقبت‌های ساده استفاده کن.';
    }

    if (pain <= 7) {
      return 'اگر درد فعالیت روزانه را مختل می‌کند، امروز فشار کمتری به خودت وارد کن.';
    }

    return 'اگر این درد غیرمعمول، ادامه‌دار یا مختل‌کننده فعالیت روزانه است، با متخصص سلامت مشورت کن.';
  }

  Color _painColor(int value) {
    if (value <= 2) return green;
    if (value <= 5) return Colors.orangeAccent;
    if (value <= 7) return Colors.deepOrangeAccent;

    return Colors.redAccent;
  }

  // ===========================================================================
  // MOOD / ENERGY
  // ===========================================================================

  Widget _moodEnergyCard() {
    return _card(
      child: Column(
        children: [
          _slider(
            'خلق‌وخو',
            'امروز از نظر روحی چطوری؟',
            Icons.mood_rounded,
            Colors.orangeAccent,
            mood,
                (value) {
              mood = value;
            },
          ),
          const SizedBox(height: 14),
          _slider(
            'انرژی',
            'چقدر انرژی برای فعالیت داری؟',
            Icons.bolt_rounded,
            green,
            energy,
                (value) {
              energy = value;
            },
          ),
        ],
      ),
    );
  }

  Widget _slider(
      String title,
      String subtitle,
      IconData icon,
      Color color,
      int value,
      ValueChanged<int> change,
      ) {
    return Column(
      children: [
        _metricHeader(
          icon,
          color,
          color.withValues(alpha: .10),
          title,
          subtitle,
          '$value/5',
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: color,
            inactiveTrackColor: bg,
            thumbColor: color,
            trackHeight: 6,
          ),
          child: Slider(
            min: 1,
            max: 5,
            divisions: 4,
            value: value.toDouble(),
            onChanged: (v) {
              setState(() {
                change(v.round());
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _metricHeader(
      IconData icon,
      Color color,
      Color iconBg,
      String title,
      String subtitle,
      String value,
      ) {
    return Row(
      children: [
        _iconBox(
          icon,
          color,
          iconBg,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: darkTeal,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: muted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // CHARTS
  // ===========================================================================

  Widget _chartCard(
      String title,
      String subtitle,
      List<double> data,
      double max,
      Color color, {
        List<double>? secondary,
      }) {
    return _card(
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBox(
                Icons.insights_rounded,
                color,
                color.withValues(alpha: .10),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: darkTeal,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: muted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 130,
            width: double.infinity,
            child: CustomPaint(
              painter: _LineChartPainter(
                data,
                secondary,
                max,
                color,
                secondary == null
                    ? null
                    : pink,
                bg,
              ),
            ),
          ),
          const SizedBox(height: 5),
          const Row(
            mainAxisAlignment:
            MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '۷ روز پیش',
                style: TextStyle(
                  color: muted,
                  fontSize: 9,
                ),
              ),
              Text(
                'امروز',
                style: TextStyle(
                  color: muted,
                  fontSize: 9,
                ),
              ),
            ],
          ),
          if (secondary != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                _legend(
                  green,
                  'خلق‌وخو',
                ),
                const SizedBox(width: 14),
                _legend(
                  pink,
                  'انرژی',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static Widget _legend(
      Color color,
      String label,
      ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: muted,
            fontSize: 9,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // CARE
  // ===========================================================================

  Widget _careCard() {
    return _card(
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          const Text(
            'چند گزینه ساده برای امتحان کردن',
            style: TextStyle(
              color: darkTeal,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'مواردی را که امتحان کرده‌ای علامت بزن تا ثبت روزانه‌ات معنادارتر شود.',
            style: TextStyle(
              color: muted,
              fontSize: 10,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 11),
          _careTile(
            Icons.local_fire_department_outlined,
            'گرمای ملایم',
            'برای گرفتگی‌ها می‌تواند آرام‌کننده باشد.',
            pink,
            heat,
                () {
              setState(() {
                heat = !heat;
              });
            },
          ),
          _careTile(
            Icons.water_drop_outlined,
            'آب کافی',
            'مایعات کافی و وعده‌های منظم را فراموش نکن.',
            teal,
            hydration,
                () {
              setState(() {
                hydration = !hydration;
              });
            },
          ),
          _careTile(
            Icons.directions_walk_rounded,
            'حرکت سبک',
            'اگر بدنت اجازه می‌دهد، پیاده‌روی یا کشش سبک.',
            Colors.orangeAccent,
            movement,
                () {
              setState(() {
                movement = !movement;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _careTile(
      IconData icon,
      String title,
      String description,
      Color color,
      bool selected,
      VoidCallback onTap,
      ) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 7,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius:
        BorderRadius.circular(13),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: .08)
                : bg,
            borderRadius:
            BorderRadius.circular(13),
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: .28)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              _iconBox(
                icon,
                color,
                color.withValues(alpha: .10),
                size: 38,
                iconSize: 19,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: darkTeal,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: const TextStyle(
                        color: muted,
                        fontSize: 9,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.circle_outlined,
                color:
                selected ? color : Colors.grey,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // SOCIAL
  // ===========================================================================

  Widget _socialCard() {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: darkTeal,
        borderRadius:
        BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white
                      .withValues(alpha: .10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.groups_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'یک ارتباط کوچک هم مراقبت از خود است',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'اگر چند روز است بیشتر تنها مانده‌ای، امروز می‌تواند فرصت خوبی برای یک تماس، دیدن یک دوست یا چند دقیقه بیرون رفتن باشد.',
            style: TextStyle(
              color: Colors.white
                  .withValues(alpha: .78),
              fontSize: 10,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _socialChip(
                'با یک دوست تماس بگیر',
                Icons.phone_rounded,
              ),
              _socialChip(
                'یک نفر را ببین',
                Icons.person_add_alt_rounded,
              ),
              InkWell(
                onTap: () {
                  _updateSocialReminder(
                    !socialReminder,
                  );
                },
                borderRadius:
                BorderRadius.circular(11),
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white
                        .withValues(alpha: .10),
                    borderRadius:
                    BorderRadius.circular(11),
                  ),
                  child: Row(
                    mainAxisSize:
                    MainAxisSize.min,
                    children: [
                      Icon(
                        socialReminder
                            ? Icons.notifications_active_rounded
                            : Icons.notifications_none_rounded,
                        color: green,
                        size: 15,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        socialReminder
                            ? 'یادآوری روشن است'
                            : 'برای امروز یادم بنداز',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _socialChip(
      String text,
      IconData icon,
      ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white
            .withValues(alpha: .10),
        borderRadius:
        BorderRadius.circular(11),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: green,
            size: 15,
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // DAILY LOG
  // ===========================================================================

  Widget _dailyLog() {
    return _card(
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          const Text(
            'یادداشت امروز',
            style: TextStyle(
              color: darkTeal,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'هر چیزی که در علائم امروز مهم بوده ثبت کن.',
            style: TextStyle(
              color: muted,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: noteController,
            maxLines: 3,
            textDirection: TextDirection.rtl,
            decoration: InputDecoration(
              hintText:
              'مثلاً امروز گرفتگی بیشتری داشتم...',
              hintStyle: const TextStyle(
                color: Colors.grey,
                fontSize: 10,
              ),
              filled: true,
              fillColor: bg,
              border: OutlineInputBorder(
                borderRadius:
                BorderRadius.circular(13),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 9),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: saving
                  ? null
                  : _saveToday,
              icon: saving
                  ? const SizedBox(
                width: 17,
                height: 17,
                child:
                CircularProgressIndicator(
                  strokeWidth: 2,
                  color: darkTeal,
                ),
              )
                  : const Icon(
                Icons.check_rounded,
                size: 17,
              ),
              label: Text(
                saving
                    ? 'در حال ثبت...'
                    : 'ثبت اطلاعات امروز',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: green,
                foregroundColor: darkTeal,
                padding:
                const EdgeInsets.symmetric(
                  vertical: 12,
                ),
                shape:
                RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(13),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SAFETY
  // ===========================================================================

  Widget _safetyCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orangeAccent
            .withValues(alpha: .08),
        borderRadius:
        BorderRadius.circular(16),
        border: Border.all(
          color: Colors.orangeAccent
              .withValues(alpha: .18),
        ),
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Colors.orangeAccent,
            size: 20,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'اگر درد بسیار شدید یا غیرمعمول است، ناگهان بدتر شده یا فعالیت‌های روزانه را مختل می‌کند، بهتر است با پزشک یا متخصص سلامت مشورت شود.',
              style: TextStyle(
                color: muted,
                fontSize: 9,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SHARED UI
  // ===========================================================================

  Widget _section(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: darkTeal,
        fontSize: 18,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  Widget _card({
    required Widget child,
    EdgeInsets padding =
    const EdgeInsets.all(16),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(20),
        border: Border.all(
          color: line,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 16,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _iconBox(
      IconData icon,
      Color color,
      Color background, {
        double size = 42,
        double iconSize = 21,
      }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius:
        BorderRadius.circular(12),
      ),
      child: Icon(
        icon,
        color: color,
        size: iconSize,
      ),
    );
  }
}

// ==============================================================================
// LINE CHART
// ==============================================================================

class _LineChartPainter extends CustomPainter {
  final List<double> primary;
  final List<double>? secondary;
  final double maxValue;
  final Color primaryColor;
  final Color? secondaryColor;
  final Color gridColor;

  const _LineChartPainter(
      this.primary,
      this.secondary,
      this.maxValue,
      this.primaryColor,
      this.secondaryColor,
      this.gridColor,
      );

  @override
  void paint(
      Canvas canvas,
      Size size,
      ) {
    if (primary.length < 2) {
      return;
    }

    final left = 8.0;
    final right = size.width - 8;
    final top = 8.0;
    final bottom = size.height - 8;

    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    for (var i = 0; i <= 4; i++) {
      final y = top +
          (bottom - top) * i / 4;

      canvas.drawLine(
        Offset(left, y),
        Offset(right, y),
        grid,
      );
    }

    _draw(
      canvas,
      primary,
      primaryColor,
      left,
      right,
      top,
      bottom,
    );

    if (secondary != null &&
        secondaryColor != null &&
        secondary!.length > 1) {
      _draw(
        canvas,
        secondary!,
        secondaryColor!,
        left,
        right,
        top,
        bottom,
      );
    }
  }

  void _draw(
      Canvas canvas,
      List<double> data,
      Color color,
      double left,
      double right,
      double top,
      double bottom,
      ) {
    if (data.length < 2) {
      return;
    }

    final line = Paint()
      ..color = color
      ..strokeWidth = 2.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final point = Paint()
      ..color = color;

    final path = Path();

    for (var i = 0; i < data.length; i++) {
      final x = left +
          (right - left) *
              i /
              (data.length - 1);

      final normalized =
      (data[i] / maxValue)
          .clamp(0.0, 1.0);

      final y = bottom -
          (bottom - top) *
              normalized;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }

      canvas.drawCircle(
        Offset(x, y),
        3.3,
        point,
      );
    }

    canvas.drawPath(
      path,
      line,
    );
  }

  @override
  bool shouldRepaint(
      covariant _LineChartPainter oldDelegate,
      ) {
    return oldDelegate.primary != primary ||
        oldDelegate.secondary != secondary ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.primaryColor !=
            primaryColor ||
        oldDelegate.secondaryColor !=
            secondaryColor ||
        oldDelegate.gridColor != gridColor;
  }
}
