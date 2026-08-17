import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../backend/nsfw_detection.dart';
import '../services/background_service.dart';

enum MonitoringMode {
  passive,
  overlay,
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with WidgetsBindingObserver {
  // ==========================================================================
  // COLORS
  // ==========================================================================

  static const bg = Color(0xFFF4F9F7);
  static const text = Color(0xFF263B37);
  static const sub = Color(0xFF7D8D89);
  static const green = Color(0xFF42D2A7);
  static const teal = Color(0xFF45C4D0);
  static const mint = Color(0xFFE8F8F1);
  static const line = Color(0xFFE8EFEC);

  // ==========================================================================
  // STATE
  // ==========================================================================

  bool monitoring = false;
  bool nsfw = false;
  bool soundEnabled = true;

  bool loading = true;
  bool busyMonitoring = false;
  bool busyNsfw = false;
  bool busySound = false;
  bool permissionPending = false;

  MonitoringMode mode = MonitoringMode.passive;

  // ==========================================================================
  // LIFECYCLE
  // ==========================================================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && permissionPending) {
      permissionPending = false;
      _retryNsfw();
    }
  }

  // ==========================================================================
  // LOAD SETTINGS
  // ==========================================================================

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final running = await BackgroundMonitorService.isRunning;

      if (!mounted) return;

      setState(() {
        monitoring =
            running ||
                (prefs.getBool('monitoring_enabled') ?? false);

        nsfw =
            prefs.getBool('nsfw_monitoring_enabled') ?? false;

        soundEnabled =
            prefs.getBool('monitoring_sound_enabled') ?? true;

        mode =
        prefs.getString('monitoring_mode') == 'overlay'
            ? MonitoringMode.overlay
            : MonitoringMode.passive;

        loading = false;
      });

      debugPrint(
        '[SettingsPage] Loaded settings: '
            'monitoring=$monitoring, '
            'sound=$soundEnabled, '
            'mode=$mode, '
            'nsfw=$nsfw',
      );
    } catch (e, stackTrace) {
      debugPrint(
        '[SettingsPage] Failed to load settings: $e',
      );
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        loading = false;
      });

      _toast('بارگذاری تنظیمات انجام نشد.');
    }
  }

  // ==========================================================================
  // MONITORING MASTER SWITCH
  // ==========================================================================

  Future<void> _toggleMonitoring(bool value) async {
    if (busyMonitoring) return;

    setState(() {
      busyMonitoring = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool(
        'monitoring_enabled',
        value,
      );

      if (value) {
        await BackgroundMonitorService.initialize();

        BackgroundMonitorService.start();

        // The background service reads the saved sound preference when it
        // starts, so we deliberately do NOT change soundEnabled here.
      } else {
        BackgroundMonitorService.stop();

        try {
          if (await FlutterOverlayWindow.isActive()) {
            await FlutterOverlayWindow.closeOverlay();
          }
        } catch (e) {
          debugPrint(
            '[SettingsPage] Failed to close overlay: $e',
          );
        }
      }

      if (!mounted) return;

      setState(() {
        monitoring = value;
      });
    } catch (e, stackTrace) {
      debugPrint(
        '[SettingsPage] Monitoring toggle failed: $e',
      );
      debugPrintStack(stackTrace: stackTrace);

      _toast('تغییر وضعیت پایش انجام نشد.');
    } finally {
      if (mounted) {
        setState(() {
          busyMonitoring = false;
        });
      }
    }
  }

  // ==========================================================================
  // MONITORING MODE
  // ==========================================================================

  Future<void> _setMode(MonitoringMode value) async {
    if (!monitoring) return;

    try {
      final modeString =
      value == MonitoringMode.overlay
          ? 'overlay'
          : 'passive';

      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(
        'monitoring_mode',
        modeString,
      );

      await BackgroundMonitorService.setMonitoringMode(
        modeString,
      );

      if (!mounted) return;

      setState(() {
        mode = value;
      });
    } catch (e, stackTrace) {
      debugPrint(
        '[SettingsPage] Failed to change monitoring mode: $e',
      );
      debugPrintStack(stackTrace: stackTrace);

      _toast('تغییر نحوه دریافت هشدار انجام نشد.');
    }
  }

  // ==========================================================================
  // SOUND TOGGLE
  // ==========================================================================

  Future<void> _toggleSound(bool value) async {
    if (busySound) return;

    final previous = soundEnabled;

    setState(() {
      soundEnabled = value;
      busySound = true;
    });

    try {
      // This writes SharedPreferences AND sends the change to the
      // already-running background isolate.
      await BackgroundMonitorService.setMonitoringSoundEnabled(
        value,
      );

      debugPrint(
        '[SettingsPage] Monitoring sound changed: $value',
      );
    } catch (e, stackTrace) {
      debugPrint(
        '[SettingsPage] Failed to change sound setting: $e',
      );
      debugPrintStack(stackTrace: stackTrace);

      if (mounted) {
        setState(() {
          soundEnabled = previous;
        });
      }

      _toast('تغییر تنظیم صدای هشدار انجام نشد.');
    } finally {
      if (mounted) {
        setState(() {
          busySound = false;
        });
      }
    }
  }

  // ==========================================================================
  // NSFW TOGGLE
  // ==========================================================================

  Future<void> _toggleNsfw(bool value) async {
    if (busyNsfw) return;

    setState(() {
      busyNsfw = true;
    });

    try {
      if (value) {
        final started =
        await NSFWDetectionController().enable();

        if (!started) {
          permissionPending = true;

          _toast(
            'اجازه نمایش روی سایر برنامه‌ها را فعال کنید و به سی برگردید.',
          );

          return;
        }
      } else {
        await NSFWDetectionController().disable();
      }

      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool(
        'nsfw_monitoring_enabled',
        value,
      );

      if (!mounted) return;

      setState(() {
        nsfw = value;
      });
    } catch (e, stackTrace) {
      debugPrint(
        '[SettingsPage] NSFW toggle failed: $e',
      );
      debugPrintStack(stackTrace: stackTrace);

      _toast(
        'تغییر محافظت از محتوا انجام نشد.',
      );
    } finally {
      if (mounted) {
        setState(() {
          busyNsfw = false;
        });
      }
    }
  }

  // ==========================================================================
  // RETRY NSFW PERMISSION
  // ==========================================================================

  Future<void> _retryNsfw() async {
    try {
      final granted =
      await FlutterOverlayWindow.isPermissionGranted();

      if (granted && !nsfw) {
        await _toggleNsfw(true);
      }
    } catch (e, stackTrace) {
      debugPrint(
        '[SettingsPage] NSFW permission retry failed: $e',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  // ==========================================================================
  // TOAST
  // ==========================================================================

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

  // ==========================================================================
  // CARD
  // ==========================================================================

  Widget _card(Widget child) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: line,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .03),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  // ==========================================================================
  // ICON
  // ==========================================================================

  Widget _icon(
      IconData icon,
      Color color,
      ) {
    return Container(
      width: 43,
      height: 43,
      decoration: const BoxDecoration(
        color: mint,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: color,
        size: 20,
      ),
    );
  }

  // ==========================================================================
  // SECTION HEADER
  // ==========================================================================

  Widget _section(
      String title,
      String subtitle,
      ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        2,
        19,
        2,
        9,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: text,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(
              color: sub,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: loading
              ? const Center(
            child: CircularProgressIndicator(
              color: green,
            ),
          )
              : ListView(
            padding: const EdgeInsets.fromLTRB(
              18,
              10,
              18,
              30,
            ),
            children: [
              // ==========================================================
              // HEADER
              // ==========================================================

              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(
                      Icons.arrow_forward_rounded,
                      color: text,
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'تنظیمات',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: text,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 48,
                  ),
                ],
              ),

              // ==========================================================
              // HEALTH MONITORING
              // ==========================================================

              _section(
                'پایش سلامت',
                'همه کنترل‌های مربوط به پایش پس‌زمینه در یک نقطه.',
              ),

              _card(
                Column(
                  children: [
                    Row(
                      children: [
                        _icon(
                          Icons.monitor_heart_outlined,
                          green,
                        ),
                        const SizedBox(width: 11),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text(
                                'پایش وضعیت بدن',
                                style: TextStyle(
                                  color: text,
                                  fontSize: 13,
                                  fontWeight:
                                  FontWeight.w900,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'گردن، قوز، مچ، فاصله و نور محیط',
                                style: TextStyle(
                                  color: sub,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: monitoring,
                          onChanged: busyMonitoring
                              ? null
                              : _toggleMonitoring,
                          activeColor: green,
                        ),
                      ],
                    ),

                    if (monitoring) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: 15,
                        ),
                        child: Divider(
                          color: line,
                          height: 1,
                        ),
                      ),

                      const Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'نحوه دریافت هشدار',
                          style: TextStyle(
                            color: text,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),

                      const SizedBox(height: 9),

                      Row(
                        children: [
                          _modeButton(
                            MonitoringMode.passive,
                            Icons.visibility_off_outlined,
                            'پس‌زمینه',
                            'بدون شناور',
                          ),
                          const SizedBox(width: 8),
                          _modeButton(
                            MonitoringMode.overlay,
                            Icons.picture_in_picture_alt_outlined,
                            'شناور',
                            'روی صفحه',
                          ),
                        ],
                      ),

                      const Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: 15,
                        ),
                        child: Divider(
                          color: line,
                          height: 1,
                        ),
                      ),

                      Row(
                        children: [
                          _icon(
                            soundEnabled
                                ? Icons.volume_up_outlined
                                : Icons.volume_off_outlined,
                            soundEnabled ? green : sub,
                          ),
                          const SizedBox(width: 11),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'صدای هشدار',
                                  style: TextStyle(
                                    color: text,
                                    fontSize: 13,
                                    fontWeight:
                                    FontWeight.w900,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'برای هشدارهای گردن، قوز، مچ، فاصله و نور صدا پخش شود.',
                                  style: TextStyle(
                                    color: sub,
                                    fontSize: 10,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value: soundEnabled,
                            onChanged: busySound
                                ? null
                                : _toggleSound,
                            activeColor: green,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // ==========================================================
              // DIGITAL PROTECTION
              // ==========================================================

              _section(
                'محافظت دیجیتال',
                'محافظت از تجربه استفاده از صفحه را مستقل از پایش بدن کنترل کن.',
              ),

              _card(
                Row(
                  children: [
                    _icon(
                      Icons.shield_outlined,
                      teal,
                    ),
                    const SizedBox(width: 11),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Text(
                            'پایش محتوای نامناسب',
                            style: TextStyle(
                              color: text,
                              fontSize: 13,
                              fontWeight:
                              FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'در صورت تشخیص، هشدار محافظتی روی صفحه نمایش داده می‌شود.',
                            style: TextStyle(
                              color: sub,
                              fontSize: 10,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: nsfw,
                      onChanged: busyNsfw
                          ? null
                          : _toggleNsfw,
                      activeColor: teal,
                    ),
                  ],
                ),
              ),

              // ==========================================================
              // PERMISSIONS & SERVICE
              // ==========================================================

              _section(
                'مجوزها و سرویس',
                'وقتی یکی از قابلیت‌ها کار نمی‌کند، از اینجا وضعیت را دوباره بررسی کن.',
              ),

              _card(
                Column(
                  children: [
                    _action(
                      Icons.layers_outlined,
                      'مجوز نمایش روی سایر برنامه‌ها',
                      'برای هشدارهای شناور',
                          () async {
                        try {
                          await FlutterOverlayWindow
                              .requestPermission();
                        } catch (e) {
                          debugPrint(
                            '[SettingsPage] Overlay permission error: $e',
                          );
                        }
                      },
                    ),
                    const Divider(
                      height: 24,
                      color: line,
                    ),
                    _action(
                      Icons.refresh_rounded,
                      'بازخوانی وضعیت سرویس',
                      'بررسی دوباره پایش پس‌زمینه',
                      _load,
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height: 18,
              ),

              // ==========================================================
              // INFORMATION BOX
              // ==========================================================

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: mint,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: green,
                      size: 19,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'اطلاعات حساب، ویرایش مشخصات و خروج از حساب در پروفایل قرار دارند تا تنظیمات فنی با حساب کاربری قاطی نشود.',
                        style: TextStyle(
                          color: text,
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
        ),
      ),
    );
  }

  // ==========================================================================
  // MONITORING MODE BUTTON
  // ==========================================================================

  Widget _modeButton(
      MonitoringMode value,
      IconData icon,
      String title,
      String subtitle,
      ) {
    final selected = mode == value;

    return Expanded(
      child: InkWell(
        onTap: monitoring
            ? () => _setMode(value)
            : null,
        borderRadius: BorderRadius.circular(15),
        child: AnimatedContainer(
          duration: const Duration(
            milliseconds: 180,
          ),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: selected ? mint : bg,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: selected ? green : line,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected ? green : sub,
                size: 18,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: text,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: sub,
                        fontSize: 8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // ACTION ROW
  // ==========================================================================

  Widget _action(
      IconData icon,
      String title,
      String subtitle,
      VoidCallback onTap,
      ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Row(
        children: [
          _icon(
            icon,
            green,
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
                    color: text,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: sub,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_left_rounded,
            color: sub,
          ),
        ],
      ),
    );
  }
}