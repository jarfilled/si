import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';

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

  static const _labels = <String, String>{
    'tooClose': 'فاصله زیاد نزدیک',
    'neck': 'وضعیت گردن',
    'wrist': 'وضعیت مچ',
    'hunch': 'قوز کردن',
    'lowLight': 'نور کم',
  };

  static const _descriptions = <String, String>{
    'tooClose': 'وقتی فاصله صورت از صفحه بیش از حد کم باشد.',
    'neck': 'وقتی وضعیت گردن برای مدت مشخص نامناسب باشد.',
    'wrist': 'وقتی وضعیت مچ دست نیاز به اصلاح داشته باشد.',
    'hunch': 'وقتی حالت قوز یا خم شدن تشخیص داده شود.',
    'lowLight': 'وقتی نور محیط برای استفاده راحت کم باشد.',
  };

  final _audio = MonitoringAudioManager.instance;
  final Map<String, MonitoringSoundConfig> _configs = {};

  bool _loading = true;
  bool _busy = false;
  String? _recordingAlert;
  Timer? _recordingTimer;
  Duration _recordingDuration = Duration.zero;
  String? _playingAlert;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _audio.stop();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      await _audio.initialize();
      final configs = await _audio.getAllConfigs();
      if (!mounted) return;
      setState(() {
        _configs
          ..clear()
          ..addAll(configs);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _toast('بارگذاری صداهای هشدار انجام نشد.');
    }
  }

  Future<void> _refreshAlert(String alert) async {
    final config = await _audio.getConfig(alert);
    if (mounted) setState(() => _configs[alert] = config);
  }

  Future<void> _preview(String alert) async {
    try {
      setState(() => _playingAlert = alert);
      await _audio.preview(alert);
    } catch (_) {
      _toast('پخش صدا انجام نشد.');
    } finally {
      if (mounted) setState(() => _playingAlert = null);
    }
  }

  Future<void> _chooseFile(String alert) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
        withData: false,
      );
      if (result == null || result.files.isEmpty) return;

      final path = result.files.single.path;
      if (path == null || path.isEmpty) {
        _toast('دسترسی به فایل انتخاب‌شده ممکن نیست.');
        return;
      }

      setState(() => _busy = true);
      await _audio.importCustomSound(path, alert);
      await _refreshAlert(alert);
      _toast('صدای انتخاب‌شده ذخیره شد.');
    } catch (e) {
      _toast('انتخاب یا ذخیره فایل صوتی انجام نشد.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startRecording(String alert) async {
    if (_recordingAlert != null) return;

    try {
      final permission = await _audio.hasRecordingPermission();
      if (!permission) {
        _toast('برای ضبط صدا، اجازه استفاده از میکروفون را فعال کنید.');
        return;
      }

      await _audio.startRecording(alert);
      if (!mounted) return;

      setState(() {
        _recordingAlert = alert;
        _recordingDuration = Duration.zero;
      });

      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || _recordingAlert == null) return;
        setState(() {
          _recordingDuration += const Duration(seconds: 1);
        });
      });
    } catch (e) {
      _toast('شروع ضبط صدا انجام نشد.');
    }
  }

  Future<void> _stopRecording(String alert) async {
    try {
      _recordingTimer?.cancel();
      _recordingTimer = null;
      final path = await _audio.stopRecording(alert);

      if (!mounted) return;
      setState(() => _recordingAlert = null);

      if (path == null) {
        _toast('ضبط صدا ذخیره نشد.');
        return;
      }

      await _refreshAlert(alert);
      _toast('صدای ضبط‌شده ذخیره و فعال شد.');
    } catch (e) {
      if (mounted) setState(() => _recordingAlert = null);
      _toast('ذخیره ضبط انجام نشد.');
    }
  }

  Future<void> _cancelRecording() async {
    try {
      _recordingTimer?.cancel();
      _recordingTimer = null;
      await _audio.cancelRecording();
    } finally {
      if (mounted) setState(() => _recordingAlert = null);
    }
  }

  Future<void> _setDefault(String alert) async {
    try {
      setState(() => _busy = true);
      await _audio.deleteCustomSound(alert);
      await _refreshAlert(alert);
    } catch (_) {
      _toast('بازگشت به صدای پیش‌فرض انجام نشد.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disable(String alert) async {
    try {
      setState(() => _busy = true);
      await _audio.disableAlertSound(alert);
      await _refreshAlert(alert);
    } catch (_) {
      _toast('خاموش کردن صدای این هشدار انجام نشد.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _soundName(MonitoringSoundConfig? config) {
    if (config == null) return 'در حال بارگذاری…';
    switch (config.type) {
      case MonitoringSoundType.defaultSound:
        return 'صدای پیش‌فرض سی';
      case MonitoringSoundType.custom:
        return 'فایل صوتی شخصی';
      case MonitoringSoundType.recorded:
        return 'ضبط شخصی شما';
      case MonitoringSoundType.none:
        return 'بدون صدا';
    }
  }

  IconData _soundIcon(MonitoringSoundConfig? config) {
    switch (config?.type) {
      case MonitoringSoundType.recorded:
        return Icons.mic_none_rounded;
      case MonitoringSoundType.custom:
        return Icons.audio_file_outlined;
      case MonitoringSoundType.none:
        return Icons.volume_off_outlined;
      case MonitoringSoundType.defaultSound:
      case null:
        return Icons.volume_up_outlined;
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _openOptions(String alert) async {
    final config = _configs[alert];

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
            decoration: const BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: line,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Text(
                    _labels[alert]!,
                    style: const TextStyle(
                      color: text,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'صدایی را انتخاب کنید که هنگام هشدار پخش شود.',
                    style: TextStyle(color: sub, fontSize: 10),
                  ),
                  const SizedBox(height: 18),
                  _optionTile(
                    Icons.volume_up_outlined,
                    'صدای پیش‌فرض سی',
                    'صدای آماده و کوتاه برای این هشدار',
                    config?.type == MonitoringSoundType.defaultSound,
                    () async {
                      Navigator.pop(sheetContext);
                      await _setDefault(alert);
                    },
                  ),
                  _optionTile(
                    Icons.mic_none_rounded,
                    'ضبط صدای خودم',
                    'یک پیام کوتاه با صدای خودتان ضبط کنید',
                    config?.type == MonitoringSoundType.recorded,
                    () {
                      Navigator.pop(sheetContext);
                      _startRecording(alert);
                    },
                  ),
                  _optionTile(
                    Icons.audio_file_outlined,
                    'انتخاب از دستگاه',
                    'فایل MP3، WAV، M4A و فرمت‌های صوتی رایج',
                    config?.type == MonitoringSoundType.custom,
                    () {
                      Navigator.pop(sheetContext);
                      _chooseFile(alert);
                    },
                  ),
                  _optionTile(
                    Icons.volume_off_outlined,
                    'بدون صدا',
                    'فقط هشدار تصویری نمایش داده شود',
                    config?.type == MonitoringSoundType.none,
                    () async {
                      Navigator.pop(sheetContext);
                      await _disable(alert);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _optionTile(
    IconData icon,
    String title,
    String subtitle,
    bool selected,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: selected ? green : line),
              color: selected ? mint : Colors.white,
            ),
            child: Row(
              children: [
                _circleIcon(icon, selected ? green : sub),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(color: text, fontSize: 12, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 3),
                      Text(subtitle, style: const TextStyle(color: sub, fontSize: 9)),
                    ],
                  ),
                ),
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.chevron_left_rounded,
                  color: selected ? green : sub,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _circleIcon(IconData icon, Color color) {
    return Container(
      width: 42,
      height: 42,
      decoration: const BoxDecoration(color: mint, shape: BoxShape.circle),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _alertCard(String alert) {
    final config = _configs[alert];
    final recording = _recordingAlert == alert;
    final playing = _playingAlert == alert;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .025),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _circleIcon(_soundIcon(config), config?.type == MonitoringSoundType.none ? sub : green),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_labels[alert]!, style: const TextStyle(color: text, fontSize: 12, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text(_soundName(config), style: const TextStyle(color: sub, fontSize: 9)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'پخش',
                onPressed: config == null || config.isDisabled || playing ? null : () => _preview(alert),
                icon: Icon(
                  playing ? Icons.graphic_eq_rounded : Icons.play_circle_outline_rounded,
                  color: config?.isDisabled == true ? line : green,
                ),
              ),
              IconButton(
                tooltip: 'تغییر',
                onPressed: _busy || recording ? null : () => _openOptions(alert),
                icon: const Icon(Icons.tune_rounded, color: text),
              ),
            ],
          ),
          if (recording) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: mint, borderRadius: BorderRadius.circular(15)),
              child: Row(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  const Text('در حال ضبط', style: TextStyle(color: text, fontSize: 10, fontWeight: FontWeight.w900)),
                  const SizedBox(width: 7),
                  Text(_formatDuration(_recordingDuration), style: const TextStyle(color: sub, fontSize: 10)),
                  const Spacer(),
                  TextButton(
                    onPressed: _cancelRecording,
                    child: const Text('لغو'),
                  ),
                  FilledButton.icon(
                    onPressed: () => _stopRecording(alert),
                    style: FilledButton.styleFrom(backgroundColor: green, foregroundColor: text),
                    icon: const Icon(Icons.stop_rounded, size: 17),
                    label: const Text('ذخیره'),
                  ),
                ],
              ),
            ),
          ] else if (config?.isCustom == true) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _busy ? null : () => _setDefault(alert),
                icon: const Icon(Icons.restore_rounded, size: 16),
                label: const Text('بازگشت به صدای پیش‌فرض'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_forward_rounded, color: text),
          ),
          title: const Text(
            'صداهای پایش',
            style: TextStyle(color: text, fontSize: 20, fontWeight: FontWeight.w900),
          ),
          centerTitle: true,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: green))
            : ListView(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 30),
                children: [
                  Container(
                    padding: const EdgeInsets.all(15),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: mint, borderRadius: BorderRadius.circular(20)),
                    child: const Row(
                      children: [
                        Icon(Icons.record_voice_over_outlined, color: green, size: 22),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'برای هر نوع هشدار می‌توانید از صدای پیش‌فرض سی استفاده کنید، صدای خودتان را ضبط کنید یا یک فایل صوتی از دستگاه انتخاب کنید.',
                            style: TextStyle(color: text, fontSize: 10, height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  for (final alert in MonitoringAudioManager.alertTypes) _alertCard(alert),
                ],
              ),
      ),
    );
  }
}
