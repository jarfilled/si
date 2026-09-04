import 'package:flutter/material.dart';

import '../services/womens_health_sharing_service.dart';

class WomensHealthSharingCard extends StatefulWidget {
  const WomensHealthSharingCard({super.key});

  @override
  State<WomensHealthSharingCard> createState() =>
      _WomensHealthSharingCardState();
}

class _WomensHealthSharingCardState extends State<WomensHealthSharingCard> {
  static const green = Color(0xFF42D2A7);
  static const teal = Color(0xFF45C4D0);
  static const darkTeal = Color(0xFF145954);
  static const bg = Color(0xFFF7F9F9);
  static const pink = Color(0xFFFFA5B7);
  static const lightPink = Color(0xFFFFEEF2);
  static const muted = Color(0xFF71807F);
  static const line = Color(0xFFE8EFEC);

  final service = WomensHealthSharingService.instance;

  bool enabled = false;
  bool loading = true;
  bool busy = false;
  List<WomensHealthShareContact> contacts = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<dynamic>([
        service.loadEnabled(),
        service.loadContacts(),
      ]);

      if (!mounted) return;

      setState(() {
        enabled = results[0] as bool;
        contacts = results[1] as List<WomensHealthShareContact>;
        loading = false;
      });
    } catch (e) {
      debugPrint('[WomensHealthSharingCard] load error: $e');
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  Future<void> _setEnabled(bool value) async {
    if (busy) return;

    setState(() {
      enabled = value;
      busy = true;
    });

    try {
      await service.setEnabled(value);
    } catch (e) {
      if (!mounted) return;
      setState(() => enabled = !value);
      _message('تغییر وضعیت اشتراک‌گذاری ذخیره نشد.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _addContact() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();

    final shouldSave = await showDialog<bool>(
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
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'نام',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'ایمیل',
                    prefixIcon: Icon(Icons.email_outlined),
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

    if (shouldSave != true) {
      nameController.dispose();
      emailController.dispose();
      return;
    }

    setState(() => busy = true);

    try {
      await service.addContact(
        name: nameController.text,
        email: emailController.text,
      );
      final updated = await service.loadContacts();

      if (!mounted) return;
      setState(() => contacts = updated);
      _message('مخاطب با موفقیت اضافه شد.');
    } catch (e) {
      if (!mounted) return;
      _message(e is FormatException ? e.message : 'افزودن مخاطب انجام نشد.');
    } finally {
      nameController.dispose();
      emailController.dispose();
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _removeContact(WomensHealthShareContact contact) async {
    if (busy) return;

    setState(() => busy = true);

    try {
      await service.removeContact(contact.id);
      final updated = await service.loadContacts();

      if (!mounted) return;
      setState(() => contacts = updated);
    } catch (e) {
      if (mounted) _message('حذف مخاطب انجام نشد.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return _card(
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _iconBox(
                Icons.health_and_safety_outlined,
                pink,
                lightPink,
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
                      'در صورت فعال‌سازی، پس از ثبت اطلاعات روزانه، فقط تاریخ، خلق‌وخو و میزان درد برای مخاطبان انتخابی ارسال می‌شود.',
                      style: TextStyle(
                        color: muted,
                        fontSize: 10,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: enabled,
                onChanged: busy ? null : _setEnabled,
                activeColor: green,
              ),
            ],
          ),
          if (enabled) ...[
            const SizedBox(height: 13),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: line),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'مخاطبان دریافت‌کننده',
                      style: TextStyle(
                        color: darkTeal,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: busy ? null : _addContact,
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text(
                      'افزودن',
                      style: TextStyle(fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (contacts.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                child: const Text(
                  'هنوز مخاطبی اضافه نشده است.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: muted,
                    fontSize: 10,
                  ),
                ),
              )
            else
              ...contacts.map(
                (contact) => Container(
                  margin: const EdgeInsets.only(bottom: 7),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: line),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 17,
                        backgroundColor: lightPink,
                        child: Text(
                          contact.name.characters.first.toUpperCase(),
                          style: const TextStyle(
                            color: pink,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              contact.name,
                              style: const TextStyle(
                                color: darkTeal,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              contact.email,
                              textDirection: TextDirection.ltr,
                              style: const TextStyle(
                                color: muted,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'حذف',
                        onPressed: busy ? null : () => _removeContact(contact),
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 19,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (contacts.isNotEmpty) ...[
              const SizedBox(height: 4),
              const Text(
                'این ارسال فقط پس از ثبت موفق اطلاعات همان روز انجام می‌شود.',
                style: TextStyle(
                  color: muted,
                  fontSize: 9,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
      child: child,
    );
  }

  Widget _iconBox(IconData icon, Color color, Color background) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 21),
    );
  }
}
