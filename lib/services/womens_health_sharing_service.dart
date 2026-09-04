import 'package:supabase_flutter/supabase_flutter.dart';

class WomensHealthShareContact {
  final String id;
  final String name;
  final String email;
  final bool enabled;

  const WomensHealthShareContact({
    required this.id,
    required this.name,
    required this.email,
    required this.enabled,
  });

  factory WomensHealthShareContact.fromMap(
    Map<String, dynamic> map,
  ) {
    return WomensHealthShareContact(
      id: map['id'].toString(),
      name: map['name'].toString(),
      email: map['email'].toString(),
      enabled: map['enabled'] == true,
    );
  }
}

class WomensHealthSharingService {
  WomensHealthSharingService._();

  static final WomensHealthSharingService instance =
      WomensHealthSharingService._();

  final SupabaseClient _supabase = Supabase.instance.client;

  String? get _userId => _supabase.auth.currentUser?.id;

  Future<bool> loadEnabled() async {
    final userId = _userId;
    if (userId == null) return false;

    final profile = await _supabase
        .from('womens_health_profiles')
        .select('share_daily_mood_pain_enabled')
        .eq('user_id', userId)
        .maybeSingle();

    return profile?['share_daily_mood_pain_enabled'] == true;
  }

  Future<void> setEnabled(bool enabled) async {
    final userId = _userId;
    if (userId == null) {
      throw StateError('No authenticated user.');
    }

    await _supabase.from('womens_health_profiles').upsert(
      {
        'user_id': userId,
        'share_daily_mood_pain_enabled': enabled,
      },
      onConflict: 'user_id',
    );
  }

  Future<List<WomensHealthShareContact>> loadContacts() async {
    final userId = _userId;
    if (userId == null) return const [];

    final response = await _supabase
        .from('womens_health_share_contacts')
        .select('id,name,email,enabled')
        .eq('user_id', userId)
        .order('created_at', ascending: true);

    return List<Map<String, dynamic>>.from(response)
        .map(WomensHealthShareContact.fromMap)
        .toList(growable: false);
  }

  Future<void> addContact({
    required String name,
    required String email,
  }) async {
    final userId = _userId;
    if (userId == null) {
      throw StateError('No authenticated user.');
    }

    final cleanName = name.trim();
    final cleanEmail = email.trim().toLowerCase();

    final validEmail = RegExp(
      r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
    ).hasMatch(cleanEmail);

    if (cleanName.isEmpty) {
      throw const FormatException('نام مخاطب را وارد کنید.');
    }

    if (!validEmail) {
      throw const FormatException('ایمیل واردشده معتبر نیست.');
    }

    await _supabase.from('womens_health_share_contacts').insert({
      'user_id': userId,
      'name': cleanName,
      'email': cleanEmail,
      'enabled': true,
    });
  }

  Future<void> removeContact(String id) async {
    final userId = _userId;
    if (userId == null) return;

    await _supabase
        .from('womens_health_share_contacts')
        .delete()
        .eq('id', id)
        .eq('user_id', userId);
  }

  Future<int> sendDailyReport({
    required String date,
    required int mood,
    required int pain,
  }) async {
    final response = await _supabase.functions.invoke(
      'send-womens-health-report',
      body: {
        'date': date,
        'mood': mood,
        'pain': pain,
      },
    );

    final data = response.data;
    if (data is Map && data['sent'] is num) {
      return (data['sent'] as num).toInt();
    }

    return 0;
  }
}
