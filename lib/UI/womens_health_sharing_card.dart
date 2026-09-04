import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WomensHealthSharingCard extends StatefulWidget {
  const WomensHealthSharingCard({super.key});

  @override
  State<WomensHealthSharingCard> createState() =>
      _WomensHealthSharingCardState();
}

class _WomensHealthSharingCardState extends State<WomensHealthSharingCard> {
  static const green = Color(0xFF42D2A7);
  static const darkTeal = Color(0xFF145954);
  static const bg = Color(0xFFF7F9F9);
  static const pink = Color(0xFFFFA5B7);
  static const lightPink = Color(0xFFFFEEF2);
  static const muted = Color(0xFF71807F);
  static const line = Color(0xFFE8EFEC);

  final SupabaseClient _supabase = Supabase.instance.client;
  final List<Map<String, dynamic>> _contacts = [];

  bool _loading = true;
  bool _adding = false;

  String? get _userId => _supabase.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final userId = _userId;

    if (userId == null) {
      if (mounted) {
        setState(() => _loading = false);
      }
      return;
    }

    try {
      final response = await _supabase
          .from('womens_health_email_contacts')
          .select('id, name, email, enabled')
          .eq('user_id', userId)
          .order('created_at', ascending: true);

      if (!mounted) return;

      setState(() {
        _contacts
          ..clear()
          ..addAll(List<Map<String, dynamic>>.from(response));
        _loading = false;
      });
    } catch (e) {
      debugPrint('[WomensHealthSharing] Load error: $e');

      if (!mounted) return;

      setState(() => _loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('بارگذاری مخاطبین اشتراک‌گذاری انجام نشد.'),
        ),
      );
    }
  }

  Future<void> _addContact() async {
    if (_adding) return;

    final userId = _userId;
    if (userId == null) return;

    final nameController = TextEditingController();
    final emailController = TextEditingController();

    try {
      final shouldAdd = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: const Text(
                'افزودن مخاطب',
                style: TextStyle(
                  color: darkTeal,
                  fontWeight: FontWeight.w900,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    textDirection: TextDirection.rtl,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'نام',
                      hintText: 'مثلاً مادر',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                      labelText: 'ایمیل',
                      hintText: 'name@example.com',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('انصراف'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: green,
                    foregroundColor: darkTeal,
                  ),
                  child: const Text(
                    'افزودن',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          );
        },
      );

      if (shouldAdd != true) return;

      final name = nameController.text.trim();
      final email = emailController.text.trim().toLowerCase();

      if (name.isEmpty || email.isEmpty || !_looksLikeEmail(email)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('نام و یک آدرس ایمیل معتبر وارد کن.'),
          ),
        );
        return;
      }

      setState(() => _adding = true);

      final inserted = await _supabase
          .from('womens_health_email_contacts')
          .insert({
            'user_id': userId,
            'name': name,
            'email': email,
            'enabled': true,
          })
          .select('id, name, email, enabled')
          .single();

      if (!mounted) return;

      setState(() {
        _contacts.add(Map<String, dynamic>.from(inserted));
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('مخاطب اضافه شد.'),
        ),
      );
    } on PostgrestException catch (e) {
      debugPrint('[WomensHealthSharing] Add error: ${e.message}');

      if (!mounted) return;

      final message = e.code == '23505'
          ? 'این ایمیل قبلاً اضافه شده است.'
          : 'افزودن مخاطب انجام نشد.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      debugPrint('[WomensHealthSharing] Add error: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('افزودن مخاطب انجام نشد.'),
        ),
      );
    } finally {
      nameController.dispose();
      emailController.dispose();

      if (mounted) {
        setState(() => _adding = false);
      }
    }
  }

  bool _looksLikeEmail(String value) {
    final regex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return regex.hasMatch(value);
  }

  Future<void> _setEnabled(
    Map<String, dynamic> contact,
    bool value,
  ) async {
    final id = contact['id'];
    if (id == null) return;

    final previous = contact['enabled'] == true;

    setState(() {
      contact['enabled'] = value;
    });

    try {
      await _supabase
          .from('womens_health_email_contacts')
          .update({'enabled': value})
          .eq('id', id);
    } catch (e) {
      debugPrint('[WomensHealthSharing] Toggle error: $e');

      if (!mounted) return;

      setState(() {
        contact['enabled'] = previous;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تغییر وضعیت مخاطب ذخیره نشد.'),
        ),
      );
    }
  }

  Future<void> _deleteContact(Map<String, dynamic> contact) async {
    final id = contact['id'];
    if (id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('حذف مخاطب'),
            content: Text(
              'مطمئنی می‌خواهی «${contact['name'] ?? ''}» از فهرست حذف شود؟',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('انصراف'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
                child: const Text('حذف'),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _supabase
          .from('womens_health_email_contacts')
          .delete()
          .eq('id', id);

      if (!mounted) return;

      setState(() {
        _contacts.remove(contact);
      });
    } catch (e) {
      debugPrint('[WomensHealthSharing] Delete error: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('حذف مخاطب انجام نشد.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabledCount =
        _contacts.where((contact) => contact['enabled'] == true).length;

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 16,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: lightPink,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.mail_outline_rounded,
                  color: pink,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'اشتراک‌گذاری حال روزانه',
                      style: TextStyle(
                        color: darkTeal,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'بعد از ثبت اطلاعات امروز، فقط میزان درد و خلق‌وخو برای مخاطبین انتخاب‌شده ایمیل می‌شود.',
                      style: TextStyle(
                        color: muted,
                        fontSize: 10,
                        height: 1.55,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.lock_outline_rounded,
                  color: darkTeal,
                  size: 18,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'این قابلیت کاملاً اختیاری است. فقط مخاطبینی که روشنشان می‌کنی گزارش دریافت می‌کنند.',
                    style: TextStyle(
                      color: muted,
                      fontSize: 9,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              Text(
                enabledCount == 0
                    ? 'هیچ مخاطب فعالی نیست'
                    : '${enabledCount.toString()} مخاطب فعال',
                style: const TextStyle(
                  color: muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _adding ? null : _addContact,
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                label: const Text('افزودن مخاطب'),
                style: FilledButton.styleFrom(
                  backgroundColor: green,
                  foregroundColor: darkTeal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: CircularProgressIndicator(
                  color: green,
                  strokeWidth: 2,
                ),
              ),
            )
          else if (_contacts.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Text(
                'هنوز مخاطبی اضافه نکرده‌ای. می‌توانی یک یا چند نفر را مشخص کنی و برای هرکدام جداگانه ارسال روزانه را روشن یا خاموش کنی.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: muted,
                  fontSize: 10,
                  height: 1.55,
                ),
              ),
            )
          else
            Column(
              children: _contacts.map(_contactTile).toList(),
            ),
        ],
      ),
    );
  }

  Widget _contactTile(Map<String, dynamic> contact) {
    final enabled = contact['enabled'] == true;
    final name = contact['name']?.toString() ?? '';
    final email = contact['email']?.toString() ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 11,
          vertical: 9,
        ),
        decoration: BoxDecoration(
          color: enabled ? lightPink.withValues(alpha: .45) : bg,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: enabled ? pink.withValues(alpha: .18) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: enabled
                    ? pink.withValues(alpha: .12)
                    : Colors.grey.withValues(alpha: .10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                enabled
                    ? Icons.mark_email_read_outlined
                    : Icons.mark_email_unread_outlined,
                color: enabled ? pink : muted,
                size: 18,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: darkTeal,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    email,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      color: muted,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: enabled,
              activeTrackColor: green,
              onChanged: (value) => _setEnabled(contact, value),
            ),
            IconButton(
              tooltip: 'حذف',
              onPressed: () => _deleteContact(contact),
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.redAccent,
                size: 19,
              ),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}
