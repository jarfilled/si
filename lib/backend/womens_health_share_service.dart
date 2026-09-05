import 'package:mailer/mailer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'email_reporter.dart';

class WomensHealthShareService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  static Future<void> sendTodayIfEnabled({
    required String userId,
    required DateTime date,
    required int pain,
    required int mood,
  }) async {
    try {
      final dateString = _dateString(date);

      final contactsResponse = await _supabase
          .from('womens_health_email_contacts')
          .select('name, email, enabled')
          .eq('user_id', userId)
          .eq('enabled', true);

      final contacts = List<Map<String, dynamic>>.from(contactsResponse);

      if (contacts.isEmpty) {
        print('[WomensHealthSharing] No enabled contacts found.');
        return;
      }

      // Pull the complete daily entry so the email contains more than
      // the two values passed from the page.
      final dailyLog = await _supabase
          .from('womens_health_daily_logs')
          .select(
            'pain, mood, energy, heat_used, hydration_ok, movement_done, note',
          )
          .eq('user_id', userId)
          .eq('log_date', dateString)
          .maybeSingle();

      final profile = await _supabase
          .from('womens_health_profiles')
          .select('cycle_start_date, cycle_length_days')
          .eq('user_id', userId)
          .maybeSingle();

      final reportPain = _safeInt(dailyLog?['pain'], pain).clamp(0, 10);
      final reportMood = _safeInt(dailyLog?['mood'], mood).clamp(1, 5);
      final energy = _safeInt(dailyLog?['energy'], 3).clamp(1, 5);
      final heatUsed = dailyLog?['heat_used'] == true;
      final hydrationOk = dailyLog?['hydration_ok'] == true;
      final movementDone = dailyLog?['movement_done'] == true;
      final note = dailyLog?['note']?.toString() ?? '';
      final cycleStartDate = _parseDate(profile?['cycle_start_date']);
      final cycleLength =
          _safeInt(profile?['cycle_length_days'], 28).clamp(15, 60);

      for (final contact in contacts) {
        final email = contact['email']?.toString().trim();
        final name = contact['name']?.toString().trim() ?? '';

        if (email == null || email.isEmpty) continue;

        final existing = await _supabase
            .from('womens_health_email_deliveries')
            .select('id')
            .eq('user_id', userId)
            .eq('contact_email', email)
            .eq('log_date', dateString)
            .limit(1);

        if (existing.isNotEmpty) {
          print(
            '[WomensHealthSharing] Already sent to $email for $dateString.',
          );
          continue;
        }

        final message = Message()
          ..from = EmailReporter.senderAddress
          ..recipients.add(
            Address(
              email,
              name.isEmpty ? null : name,
            ),
          )
          ..subject = 'گزارش روزانه سلامت زنان | ${_persianDate(date)}'
          ..text = _buildPlainText(
            recipientName: name,
            date: date,
            pain: reportPain,
            mood: reportMood,
            energy: energy,
            heatUsed: heatUsed,
            hydrationOk: hydrationOk,
            movementDone: movementDone,
            note: note,
            cycleStartDate: cycleStartDate,
            cycleLength: cycleLength,
          )
          ..html = _buildHtml(
            recipientName: name,
            date: date,
            pain: reportPain,
            mood: reportMood,
            energy: energy,
            heatUsed: heatUsed,
            hydrationOk: hydrationOk,
            movementDone: movementDone,
            note: note,
            cycleStartDate: cycleStartDate,
            cycleLength: cycleLength,
          );

        try {
          await send(message, EmailReporter.smtpServer);

          await _supabase.from('womens_health_email_deliveries').insert({
            'user_id': userId,
            'contact_email': email,
            'log_date': dateString,
          });

          print('[WomensHealthSharing] ✅ Report sent to $email');
        } catch (e) {
          print('[WomensHealthSharing] ❌ Failed to send to $email: $e');
        }
      }
    } catch (e) {
      print('[WomensHealthSharing] ❌ Sharing failed: $e');
    }
  }

  static String _buildPlainText({
    required String recipientName,
    required DateTime date,
    required int pain,
    required int mood,
    required int energy,
    required bool heatUsed,
    required bool hydrationOk,
    required bool movementDone,
    required String note,
    DateTime? cycleStartDate,
    required int cycleLength,
  }) {
    final buffer = StringBuffer();
    final greeting = recipientName.isEmpty
        ? 'سلام'
        : 'سلام ${recipientName.trim()}';

    buffer.writeln(greeting);
    buffer.writeln();
    buffer.writeln('گزارش روزانه سلامت زنان');
    buffer.writeln('تاریخ: ${_persianDate(date)}');
    buffer.writeln();
    buffer.writeln('خلاصه امروز');
    buffer.writeln('درد: $pain از ۱۰');
    buffer.writeln('خلق‌وخو: $mood از ۵ (${_moodLabel(mood)})');
    buffer.writeln('انرژی: $energy از ۵ (${_energyLabel(energy)})');
    buffer.writeln();
    buffer.writeln('مراقبت امروز');
    buffer.writeln('گرما: ${_doneLabel(heatUsed)}');
    buffer.writeln('آبرسانی: ${_doneLabel(hydrationOk)}');
    buffer.writeln('حرکت: ${_doneLabel(movementDone)}');

    if (cycleStartDate != null) {
      buffer.writeln();
      buffer.writeln('چرخه');
      buffer.writeln('روز چرخه: ${_cycleDay(date, cycleStartDate)}');
      buffer.writeln('طول چرخه ثبت‌شده: $cycleLength روز');
      buffer.writeln('شروع آخرین قاعدگی: ${_persianDate(cycleStartDate)}');
    }

    if (note.trim().isNotEmpty) {
      buffer.writeln();
      buffer.writeln('یادداشت امروز');
      buffer.writeln(note.trim());
    }

    buffer.writeln();
    buffer.writeln('این گزارش با اجازه کاربر از اپ سی ثبت و ارسال شده است.');
    return buffer.toString();
  }

  static String _buildHtml({
    required String recipientName,
    required DateTime date,
    required int pain,
    required int mood,
    required int energy,
    required bool heatUsed,
    required bool hydrationOk,
    required bool movementDone,
    required String note,
    DateTime? cycleStartDate,
    required int cycleLength,
  }) {
    final greeting = recipientName.isEmpty
        ? 'سلام 👋'
        : 'سلام ${_escapeHtml(recipientName.trim())} 👋';

    final cycleSection = cycleStartDate == null
        ? ''
        : '''
          <div style="margin-top:24px;background:#F8FAFA;border:1px solid #E5ECEA;border-radius:16px;padding:20px;">
            <div style="font-size:13px;color:#71807F;font-weight:700;">چرخه</div>
            <div style="margin-top:8px;font-size:24px;font-weight:800;color:#145954;">روز ${_cycleDay(date, cycleStartDate)}</div>
            <div style="margin-top:6px;color:#71807F;font-size:13px;line-height:1.9;">
              شروع آخرین قاعدگی: ${_persianDate(cycleStartDate)}<br>
              طول چرخه ثبت‌شده: $cycleLength روز
            </div>
          </div>
        ''';

    final noteSection = note.trim().isEmpty
        ? ''
        : '''
          <div style="margin-top:24px;background:#FFF7FA;border-radius:16px;padding:20px;border:1px solid #F4DCE2;">
            <div style="font-size:13px;color:#9A6873;font-weight:700;">یادداشت امروز</div>
            <div style="margin-top:8px;color:#4D5B5A;font-size:14px;line-height:2;">${_escapeHtml(note.trim()).replaceAll('\n', '<br>')}</div>
          </div>
        ''';

    return '''
<!doctype html>
<html lang="fa" dir="rtl">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="margin:0;padding:0;background:#F3F6F5;font-family:Tahoma,Arial,sans-serif;color:#263432;">
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0">
    <tr>
      <td align="center" style="padding:28px 12px;">
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="max-width:620px;background:#FFFFFF;border-radius:24px;overflow:hidden;">
          <tr>
            <td style="background:#145954;padding:28px;color:#FFFFFF;">
              <div style="font-size:13px;opacity:.78;">سی • گزارش اشتراک‌گذاری سلامت</div>
              <div style="font-size:30px;font-weight:800;margin-top:10px;line-height:1.45;">گزارش روزانه سلامت</div>
              <div style="font-size:14px;opacity:.82;margin-top:6px;">${_persianDate(date)}</div>
            </td>
          </tr>
          <tr>
            <td style="padding:28px;">
              <div style="font-size:20px;font-weight:800;color:#145954;">$greeting</div>
              <div style="margin-top:7px;color:#71807F;font-size:14px;line-height:1.9;">وضعیت ثبت‌شده امروز در یک نگاه</div>

              <div style="margin-top:22px;border:1px solid #E5ECEA;border-radius:18px;overflow:hidden;">
                <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0">
                  <tr>
                    ${_metricCell('درد', '$pain/10', _painColor(pain))}
                    ${_metricCell('خلق‌وخو', '$mood/5', '#45C4D0')}
                    ${_metricCell('انرژی', '$energy/5', '#42D2A7')}
                  </tr>
                </table>
              </div>

              <div style="margin-top:26px;font-size:17px;font-weight:800;color:#145954;">مراقبت امروز</div>
              <div style="margin-top:12px;border:1px solid #E5ECEA;border-radius:16px;overflow:hidden;">
                ${_checkRow('گرما', heatUsed, 'ثبت استفاده از گرما')}
                ${_checkRow('آبرسانی', hydrationOk, 'ثبت نوشیدن آب کافی')}
                ${_checkRow('حرکت', movementDone, 'ثبت فعالیت یا حرکت سبک')}
              </div>

              $cycleSection
              $noteSection

              <div style="margin-top:28px;padding-top:18px;border-top:1px solid #E8EFEC;color:#8A9694;font-size:11px;line-height:1.9;text-align:center;">
                این گزارش با اجازه کاربر از اپ سی ثبت و ارسال شده است.<br>
                لطفاً محتوای این گزارش را محرمانه نگه دارید.
              </div>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
''';
  }

  static String _metricCell(String label, String value, String accent) {
    return '''
      <td width="33%" style="padding:18px 10px;text-align:center;border-left:1px solid #E8EFEC;">
        <div style="font-size:12px;color:#71807F;font-weight:700;">$label</div>
        <div style="margin-top:7px;font-size:25px;font-weight:800;color:$accent;">$value</div>
      </td>
    ''';
  }

  static String _checkRow(String title, bool done, String subtitle) {
    final icon = done ? '✓' : '—';
    final status = done ? 'انجام شد' : 'ثبت نشده';
    final statusColor = done ? '#2A9B7C' : '#9AA5A3';

    return '''
      <div style="padding:14px 16px;border-bottom:1px solid #E8EFEC;">
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0">
          <tr>
            <td width="40" style="font-size:22px;font-weight:800;color:$statusColor;">$icon</td>
            <td>
              <div style="font-size:14px;font-weight:800;color:#263432;">$title</div>
              <div style="font-size:11px;color:#8A9694;margin-top:3px;">$subtitle</div>
            </td>
            <td align="left" style="font-size:12px;font-weight:700;color:$statusColor;">$status</td>
          </tr>
        </table>
      </div>
    ''';
  }

  static int _safeInt(dynamic value, int fallback) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  static String _doneLabel(bool value) => value ? 'انجام شد' : 'ثبت نشده';

  static String _painColor(int pain) {
    if (pain <= 2) return '#42D2A7';
    if (pain <= 5) return '#E3A63A';
    return '#DD6677';
  }

  static String _moodLabel(int mood) {
    switch (mood) {
      case 1:
        return 'خیلی بد';
      case 2:
        return 'بد';
      case 3:
        return 'متوسط';
      case 4:
        return 'خوب';
      case 5:
        return 'خیلی خوب';
      default:
        return 'ثبت شده';
    }
  }

  static String _energyLabel(int energy) {
    switch (energy) {
      case 1:
        return 'خیلی کم';
      case 2:
        return 'کم';
      case 3:
        return 'متوسط';
      case 4:
        return 'خوب';
      case 5:
        return 'خیلی خوب';
      default:
        return 'ثبت شده';
    }
  }

  static int _cycleDay(DateTime date, DateTime start) {
    final current = DateTime(date.year, date.month, date.day);
    final initial = DateTime(start.year, start.month, start.day);
    final difference = current.difference(initial).inDays;
    return difference < 0 ? 1 : difference + 1;
  }

  static String _dateString(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  static String _persianDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  static String _escapeHtml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }
}
