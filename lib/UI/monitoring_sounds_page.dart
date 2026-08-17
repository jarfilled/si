import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../backend/monitoring_audio_manager.dart';

class MonitoringSoundsPage extends StatefulWidget {
  const MonitoringSoundsPage({super.key});

  @override
  State<MonitoringSoundsPage> createState() => _MonitoringSoundsPageState();
}

class _MonitoringSoundsPageState extends State<MonitoringSoundsPage> {
  static const bg = Color(0xFFF4F9F7);
  static const text = Color(0xFF263B37);
  static const sub = Color(0xFF7D8D89);
  static const green = Color(0xFF42D2A7);
  static const mint = Color(0xFFE8F8F1);
  static const line = Color(0xFFE8EFEC);

  static const labels = {
    'tooClose': 'فاصله زیاد نزدیک',
    'neck': 'وضعیت گردن',
    'wrist': 'وضعیت مچ',
    'hunch': 'قوز کردن',
    'lowLight': 'نور کم',
  };

  final audio = MonitoringAudioManager.instance;
  final configs = <String, MonitoringSoundConfig>{};
  String? recordingAlert;
  String? playingAlert;
  Timer? recordingTimer;
  Duration recordingDuration = Duration.zero;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    recordingTimer?.cancel();
    audio.stop();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      await audio.initialize();
      final all = await audio.getAllConfigs();
      if (!mounted) return;
      setState(() => configs.addAll(all));
    } catch (_) {
      _toast('بارگذاری صداهای هشدار انجام نشد.');
    }
  }

  Future<void> _refresh(String alert) async {
    final config = await audio.getConfig(alert);
    if (mounted) setState(() => configs[alert] = config);
  }

  Future<void> _preview(String alert) async {
    try {
      setState(() => playingAlert = alert);
      await audio.preview(alert);
    } catch (_) {
      _toast('پخش صدا انجام نشد.');
    } finally {
      if (mounted) setState(() => playingAlert = null);
    }
  }

  Future<void> _pickFile(String alert) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
        withData: false,
      );
      if (result == null || result.isEmpty) return;
      final path = result.single.path;
      if (path == null || path.isEmpty) {
        _toast('دسترسی به فایل انتخاب‌شده ممکن نیست.');
        return;
      }
      setState(() => busy = true);
      await audio.importCustomSound(path, alert);
      await _refresh(alert);
      _toast('فایل صوتی ذخیره و فعال شد.');
    } catch (_) {
      _toast('انتخاب یا ذخیره فایل صوتی انجام نشد.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _startRecording(String alert) async {
    if (recordingAlert != null) return;
    try {
      if (!await audio.hasRecordingPermission()) {
        _toast('برای ضبط صدا، اجازه استفاده از میکروفون را فعال کنید.');
        return;
      }
      await audio.startRecording(alert);
      if (!mounted) return;
      setState(() {
        recordingAlert = alert;
        recordingDuration = Duration.zero;
      });
      recordingTimer?.cancel();
      recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || recordingAlert == null) return;
        setState(() => recordingDuration += const Duration(seconds: 1));
      });
    } catch (_) {
      _toast('شروع ضبط صدا انجام نشد.');
    }
  }

  Future<void> _stopRecording(String alert) async {
    try {
      recordingTimer?.cancel();
      recordingTimer = null;
      final path = await audio.stopRecording(alert);
      if (mounted) setState(() => recordingAlert = null);
      if (path == null) {
        _toast('ضبط صدا ذخیره نشد.');
        return;
      }
      await _refresh(alert);
      _toast('صدای ضبط‌شده ذخیره و فعال شد.');
    } catch (_) {
      if (mounted) setState(() => recordingAlert = null);
      _toast('ذخیره ضبط انجام نشد.');
    }
  }

  Future<void> _cancelRecording() async {
    recordingTimer?.cancel();
    recordingTimer = null;
    await audio.cancelRecording();
    if (mounted) setState(() => recordingAlert = null);
  }

  Future<void> _default(String alert) async {
    try {
      setState(() => busy = true);
      await audio.deleteCustomSound(alert);
      await _refresh(alert);
    } catch (_) {
      _toast('بازگشت به صدای پیش‌فرض انجام نشد.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _disable(String alert) async {
    try {
      setState(() => busy = true);
      await audio.disableAlertSound(alert);
      await _refresh(alert);
    } catch (_) {
      _toast('خاموش کردن صدای این هشدار انجام نشد.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String _name(MonitoringSoundConfig? c) {
    switch (c?.type) {
      case MonitoringSoundType.custom:
        return 'فایل صوتی شخصی';
      case MonitoringSoundType.recorded:
        return 'ضبط شخصی شما';
      case MonitoringSoundType.none:
        return 'بدون صدا';
      case MonitoringSoundType.defaultSound:
      case null:
        return 'صدای پیش‌فرض سی';
    }
  }

  IconData _icon(MonitoringSoundConfig? c) {
    switch (c?.type) {
      case MonitoringSoundType.custom:
        return Icons.audio_file_outlined;
      case MonitoringSoundType.recorded:
        return Icons.mic_none_rounded;
      case MonitoringSoundType.none:
        return Icons.volume_off_outlined;
      case MonitoringSoundType.defaultSound:
      case null:
        return Icons.volume_up_outlined;
    }
  }

  String _duration(Duration d) => '${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
  }

  Future<void> _options(String alert) async {
    final current = configs[alert];
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheet) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
          decoration: const BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 42, height: 4, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: line, borderRadius: BorderRadius.circular(4))),
              Text(labels[alert]!, style: const TextStyle(color: text, fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 5),
              const Text('صدایی را انتخاب کنید که هنگام هشدار پخش شود.', style: TextStyle(color: sub, fontSize: 10)),
              const SizedBox(height: 18),
              _option(sheet, Icons.volume_up_outlined, 'صدای پیش‌فرض سی', 'صدای آماده و کوتاه برای این هشدار', current?.type == MonitoringSoundType.defaultSound, () async { Navigator.pop(sheet); await _default(alert); }),
              _option(sheet, Icons.mic_none_rounded, 'ضبط صدای خودم', 'یک پیام کوتاه با صدای خودتان ضبط کنید', current?.type == MonitoringSoundType.recorded, () { Navigator.pop(sheet); _startRecording(alert); }),
              _option(sheet, Icons.audio_file_outlined, 'انتخاب از دستگاه', 'فایل صوتی موجود روی گوشی', current?.type == MonitoringSoundType.custom, () { Navigator.pop(sheet); _pickFile(alert); }),
              _option(sheet, Icons.volume_off_outlined, 'بدون صدا', 'فقط هشدار تصویری نمایش داده شود', current?.type == MonitoringSoundType.none, () async { Navigator.pop(sheet); await _disable(alert); }),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _option(BuildContext sheet, IconData icon, String title, String subtitle, bool selected, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(color: selected ? mint : Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: selected ? green : line)),
          child: Row(children: [
            _circle(icon, selected ? green : sub),
            const SizedBox(width: 11),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(color: text, fontSize: 12, fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(subtitle, style: const TextStyle(color: sub, fontSize: 9)),
            ])),
            Icon(selected ? Icons.check_circle_rounded : Icons.chevron_left_rounded, color: selected ? green : sub, size: 20),
          ]),
        ),
      ),
    ),
  );

  Widget _circle(IconData icon, Color color) => Container(
    width: 42,
    height: 42,
    decoration: const BoxDecoration(color: mint, shape: BoxShape.circle),
    child: Icon(icon, color: color, size: 20),
  );

  Widget _card(String alert) {
    final c = configs[alert];
    final recording = recordingAlert == alert;
    final playing = playingAlert == alert;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: line)),
      child: Column(children: [
        Row(children: [
          _circle(_icon(c), c?.type == MonitoringSoundType.none ? sub : green),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(labels[alert]!, style: const TextStyle(color: text, fontSize: 12, fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text(_name(c), style: const TextStyle(color: sub, fontSize: 9)),
          ])),
          IconButton(onPressed: c == null || c.isDisabled || playing ? null : () => _preview(alert), icon: Icon(playing ? Icons.graphic_eq_rounded : Icons.play_circle_outline_rounded, color: c?.isDisabled == true ? line : green)),
          IconButton(onPressed: busy || recording ? null : () => _options(alert), icon: const Icon(Icons.tune_rounded, color: text)),
        ]),
        if (recording)
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: mint, borderRadius: BorderRadius.circular(15)),
            child: Row(children: [
              const Icon(Icons.fiber_manual_record_rounded, color: Colors.redAccent, size: 12),
              const SizedBox(width: 7),
              Text('در حال ضبط  ${_duration(recordingDuration)}', style: const TextStyle(color: text, fontSize: 10, fontWeight: FontWeight.w800)),
              const Spacer(),
              TextButton(onPressed: _cancelRecording, child: const Text('لغو')),
              FilledButton.icon(onPressed: () => _stopRecording(alert), style: FilledButton.styleFrom(backgroundColor: green, foregroundColor: text), icon: const Icon(Icons.stop_rounded, size: 16), label: const Text('ذخیره')),
            ]),
          )
        else if (c?.isCustom == true)
          Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: busy ? null : () => _default(alert), icon: const Icon(Icons.restore_rounded, size: 16), label: const Text('بازگشت به صدای پیش‌فرض'))),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_forward_rounded, color: text)),
        title: const Text('صداهای پایش', style: TextStyle(color: text, fontSize: 20, fontWeight: FontWeight.w900)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: mint, borderRadius: BorderRadius.circular(20)),
            child: const Row(children: [
              Icon(Icons.record_voice_over_outlined, color: green, size: 22),
              SizedBox(width: 10),
              Expanded(child: Text('برای هر هشدار می‌توانید صدای پیش‌فرض سی، صدای خودتان یا یک فایل صوتی از دستگاه را انتخاب کنید.', style: TextStyle(color: text, fontSize: 10, height: 1.5))),
            ]),
          ),
          for (final alert in MonitoringAudioManager.alertTypes) _card(alert),
        ],
      ),
    ),
  );
}
