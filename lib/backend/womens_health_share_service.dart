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
      final response = await _supabase
          .from('womens_health_email_contacts')
          .select('name, email, enabled')
          .eq('user_id', userId)
          .eq('enabled', true);

      final contacts = List<Map<String, dynamic>>.from(response);

      if (contacts.isEmpty) {
        print("[WomensHealthSharing] No enabled contacts found.");
        return;
      }

      final dateString =
          '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';

      for (final contact in contacts) {
        final email = contact['email']?.toString().trim();
        final name = contact['name']?.toString().trim() ?? '';

        if (email == null || email.isEmpty) {
          continue;
        }

        final existing = await _supabase
            .from('womens_health_email_deliveries')
            .select('id')
            .eq('user_id', userId)
            .eq('contact_email', email)
            .eq('log_date', dateString)
            .limit(1);

        if (existing.isNotEmpty) {
          print(
            "[WomensHealthSharing] Already sent to $email for $dateString.",
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
          ..subject = 'گزارش روزانه سلامت زنان'
          ..text = _buildMessage(
            recipientName: name,
            date: date,
            pain: pain,
            mood: mood,
          );

        try {
          await send(
            message,
            EmailReporter.smtpServer,
          );

          await _supabase
              .from('womens_health_email_deliveries')
              .insert({
            'user_id': userId,
            'contact_email': email,
            'log_date': dateString,
          });

          print(
            "[WomensHealthSharing] ✅ Report sent to $email",
          );
        } catch (e) {
          print(
            "[WomensHealthSharing] ❌ Failed to send to $email: $e",
          );
        }
      }
    } catch (e) {
      print(
        "[WomensHealthSharing] ❌ Sharing failed: $e",
      );
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

    final buffer = StringBuffer();

    buffer.writeln(greeting);
    buffer.writeln();
    buffer.writeln('گزارش روزانه سلامت زنان');
    buffer.writeln(
      'تاریخ: '
          '${date.year}/'
          '${date.month.toString().padLeft(2, '0')}/'
          '${date.day.toString().padLeft(2, '0')}',
    );
    buffer.writeln();
    buffer.writeln('میزان درد: $pain از ۱۰');
    buffer.writeln(
      'خلق‌وخو: $mood از ۵ (${_moodLabel(mood)})',
    );
    buffer.writeln();
    buffer.writeln(
      'این گزارش با اجازه کاربر و از داخل اپ سی ثبت و ارسال شده است.',
    );

    return buffer.toString();
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