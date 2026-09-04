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
        return;
      }

      for (final contact in contacts) {
        final email = contact['email']?.toString().trim();
        final name = contact['name']?.toString().trim() ?? '';

        if (email == null || email.isEmpty) {
          continue;
        }

        try {
          await EmailReporter.sendWomensHealthDailyCopy(
            recipientEmail: email,
            recipientName: name,
            date: date,
            pain: pain,
            mood: mood,
          );
        } catch (e) {
          // One invalid/unavailable recipient must not prevent the other
          // selected recipients from receiving the report.
          print(
            '❌ Failed to send women\'s health copy to $email: $e',
          );
        }
      }
    } catch (e) {
      // Email sharing is supplementary. A mail failure must never make a
      // successfully saved health log look like it failed.
      print('❌ Womens health sharing lookup failed: $e');
    }
  }
}
