import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server/gmail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WomensHealthShareService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // Keep the sender credentials out of source control. Build the app with:
  // --dart-define=WOMENS_HEALTH_SMTP_USER=...
  // --dart-define=WOMENS_HEALTH_SMTP_PASSWORD=...
  static const _smtpUser =
      String.fromEnvironment('WOMENS_HEALTH_SMTP_USER');
  static const _smtpPassword =
      String.fromEnvironment('WOMENS_HEALTH_SMTP_PASSWORD');

  static Future<void> sendTodayIfEnabled({
    required String userId,
    required DateTime date,
    required int pain,
    required int mood,
  }) async {
    if (_smtpUser.isEmpty || _smtpPassword.isEmpty) {
      print(
        '⚠️ Womens health sharing is not configured: SMTP credentials are missing.',
      );
      return;
    }

    try {
      final response = await _supabase
          .from('womens_health_email_contacts')
          .select('name, email, enabled')
          .eq('user_id', userId)
          .eq('enabled', true);

      final contacts = List<Map<String, dynamic>>.from(response);

      if (contacts.isEmpty) {
        return;
      }

      final smtpServer = gmail(_smtpUser, _smtpPassword);

      for (final contact in contacts) {
        final email = contact['email']?.toString().trim();
        final name = contact['name']?.toString().trim() ?? '';

        if (email == null || email.isEmpty) {
          continue;
        }

        final message = Message()
          ..from = Address(_smtpUser, 'C')
          ..recipients.add(
            Address(
              email,
              name.isEmpty ? null : name,
            ),
          )
          ..subject = 'گزارش روزانه سلامت زنان'
          ..text = _buildMessage(
            recipientName: name,
            date: date,
            pain: pain,
            mood: mood,
          );

        try {
          await send(message, smtpServer);
          print("✅ Women's health report sent to $email");
        } catch (e) {
          print("❌ Failed to send women's health report to $email: $e");
        }
      }
    } catch (e) {
      // Sharing is supplementary. A lookup/mail failure must never make an
      // otherwise successful daily health registration fail.
      print('❌ Womens health sharing failed: $e');
    }
  }

  static String _buildMessage({
    required String recipientName,
    required DateTime date,
    required int pain,
    required int mood,
  }) {
    final greeting = recipientName.isEmpty
        ? 'سلام'
        : 'سلام ${recipientName.trim()}';

    return StringBuffer()
      ..writeln(greeting)
      ..writeln()
      ..writeln('گزارش روزانه سلامت زنان')
      ..writeln(
        'تاریخ: ${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}',
      )
      ..writeln()
      ..writeln('میزان درد: $pain از ۱۰')
      ..writeln('خلق‌وخو: $mood از ۵ (${_moodLabel(mood)})')
      ..writeln()
      ..writeln(
        'این گزارش با اجازه کاربر و از داخل اپ سی ثبت و ارسال شده است.',
      )
      .toString();
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
}
