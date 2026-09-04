from pathlib import Path
import re


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if new in text:
        return text
    if old not in text:
        raise RuntimeError(f'{label}: marker not found')
    return text.replace(old, new, 1)


# ---------------------------------------------------------------------------
# background_service.dart
# ---------------------------------------------------------------------------
p = Path('lib/services/background_service.dart')
s = p.read_text(encoding='utf-8')

s = replace_once(
    s,
    'const double _lowLightThresholdLux = 100.0;',
    '''const double _lowLightThresholdLux = 100.0;

const _overlayShowDelay = Duration(milliseconds: 500);
const _overlayHideDelay = Duration(milliseconds: 300);
const _postureDetectionTimeout = Duration(milliseconds: 1500);''',
    'overlay timing constants',
)

s = replace_once(
    s,
    """  bool stopped = false;
  bool nsfwOverlayActive = false;

  String monitoringMode = 'passive';""",
    """  bool stopped = false;
  bool nsfwOverlayActive = false;

  bool userNotDetected = false;
  DateTime? lastNeckSignalAt;
  DateTime? lastHunchSignalAt;
  Timer? postureDetectionWatchdog;

  String monitoringMode = 'passive';""",
    'user-not-detected state',
)

if 'final pendingOverlayTimers' not in s:
    marker = "  final overlayState =\n  <String, dynamic>{"
    helpers = '''  final pendingOverlayTimers = <String, Timer?>{};

  void _cancelPendingOverlayTimer(String key) {
    pendingOverlayTimers[key]?.cancel();
    pendingOverlayTimers[key] = null;
  }

  bool _readUserDetected(Map<dynamic, dynamic> data) {
    for (final key in const [
      'userNotDetected',
      'user_not_detected',
      'notDetected',
      'not_detected',
      'noUser',
      'no_user',
    ]) {
      final value = data[key];
      if (value is bool) return !value;
    }

    for (final key in const [
      'userDetected',
      'user_detected',
      'detected',
      'personDetected',
      'person_detected',
      'poseDetected',
      'pose_detected',
      'hasUser',
      'has_user',
    ]) {
      final value = data[key];
      if (value is bool) return value;
    }

    final status = data['status']?.toString().trim().toLowerCase();
    if (status != null && const {
      'not_detected',
      'not detected',
      'undetected',
      'no_user',
      'no user',
      'no_person',
      'no person',
      'no_pose',
      'no pose',
      'lost',
      'missing',
    }.contains(status)) {
      return false;
    }

    return true;
  }

  void _clearCameraWarningsForLostUser() {
    for (final type in const ['neck', 'hunch', 'tooClose']) {
      updateWarningState(type, false);
      _cancelPendingOverlayTimer(type);
      overlayState[type] = false;
    }

    unawaited(metrics.stop('neck'));
    unawaited(metrics.stop('hunch'));
    unawaited(metrics.stop('tooClose'));
  }

  void _setUserNotDetected(bool value) {
    if (userNotDetected == value) return;

    userNotDetected = value;
    overlayState['userNotDetected'] = value;

    if (value) {
      _clearCameraWarningsForLostUser();
    }

    queueOverlayUpdate();
  }

  void _startPostureDetectionWatchdog() {
    postureDetectionWatchdog?.cancel();

    postureDetectionWatchdog = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) {
        if (stopped) return;

        final now = DateTime.now();
        final neckStale = lastNeckSignalAt == null ||
            now.difference(lastNeckSignalAt!) > _postureDetectionTimeout;
        final hunchStale = lastHunchSignalAt == null ||
            now.difference(lastHunchSignalAt!) > _postureDetectionTimeout;

        if (neckStale && hunchStale) {
          _setUserNotDetected(true);
        }
      },
    );
  }

  void _setOverlayWarningDebounced(String key, bool value) {
    final current = overlayState[key] == true;

    if (current == value) {
      _cancelPendingOverlayTimer(key);
      return;
    }

    _cancelPendingOverlayTimer(key);

    pendingOverlayTimers[key] = Timer(
      value ? _overlayShowDelay : _overlayHideDelay,
      () {
        pendingOverlayTimers[key] = null;
        if (stopped) return;
        overlayState[key] = value;
        queueOverlayUpdate();
      },
    );
  }

  final overlayState =
  <String, dynamic>{'''
    if marker not in s:
        raise RuntimeError('overlay state declaration not found')
    s = s.replace(marker, helpers, 1)

if "'userNotDetected': false," not in s:
    s = replace_once(
        s,
        "    'lowLight': false,\n    'wristTilt': 0.0,",
        "    'lowLight': false,\n    'userNotDetected': false,\n    'wristTilt': 0.0,",
        'overlay user state field',
    )

start = s.index('  void setOverlayFlag(')
end = s.index('\n  // ==========================================================================\n  // SHUTDOWN', start)
new_set_overlay = '''  void setOverlayFlag(
      String key,
      bool value, {
        double? wristTilt,
        double? hunchRatio,
        double? lightLux,
      }) {
    if (wristTilt != null) overlayState['wristTilt'] = wristTilt;
    if (hunchRatio != null) overlayState['hunchRatio'] = hunchRatio;
    if (lightLux != null) overlayState['lightLux'] = lightLux;

    if (key == 'userNotDetected') {
      _cancelPendingOverlayTimer(key);
      overlayState[key] = value;
      queueOverlayUpdate();
      return;
    }

    const warningKeys = <String>{
      'tooClose',
      'neck',
      'wrist',
      'hunch',
      'lowLight',
    };

    if (warningKeys.contains(key)) {
      _setOverlayWarningDebounced(key, value);
      return;
    }

    queueOverlayUpdate();
  }
'''
s = s[:start] + new_set_overlay + s[end:]

if 'postureDetectionWatchdog?.cancel();' not in s:
    s = replace_once(
        s,
        "    pushTimer?.cancel();\n    emailTimer?.cancel();",
        """    pushTimer?.cancel();
    emailTimer?.cancel();
    postureDetectionWatchdog?.cancel();

    for (final timer in pendingOverlayTimers.values) {
      timer?.cancel();
    }
    pendingOverlayTimers.clear();""",
        'shutdown timers',
    )

if '_startPostureDetectionWatchdog();' not in s:
    match = re.search(r'(?m)^(\s*)syncService\.start\(\);', s)
    if not match:
        raise RuntimeError('syncService.start not found')
    indent = match.group(1)
    s = s[:match.start()] + indent + '_startPostureDetectionWatchdog();\n\n' + s[match.start():]

if 'lastNeckSignalAt = DateTime.now();' not in s:
    neck_old = """          final data =
          Map<dynamic, dynamic>.from(
            raw,
          );

          final status ="""
    neck_new = """          final data =
          Map<dynamic, dynamic>.from(
            raw,
          );

          lastNeckSignalAt = DateTime.now();
          final detected = _readUserDetected(data);
          if (!detected) {
            _setUserNotDetected(true);
            return;
          }
          if (userNotDetected) _setUserNotDetected(false);

          final status ="""
    s = replace_once(s, neck_old, neck_new, 'neck detection heartbeat')

if 'lastHunchSignalAt = DateTime.now();' not in s:
    hunch_old = """          final data =
          Map<dynamic, dynamic>.from(
            raw,
          );

          final isHunching ="""
    hunch_new = """          final data =
          Map<dynamic, dynamic>.from(
            raw,
          );

          lastHunchSignalAt = DateTime.now();
          final detected = _readUserDetected(data);
          if (!detected) {
            _setUserNotDetected(true);
            return;
          }
          if (userNotDetected) _setUserNotDetected(false);

          final isHunching ="""
    s = replace_once(s, hunch_old, hunch_new, 'hunch detection heartbeat')

p.write_text(s, encoding='utf-8')


# ---------------------------------------------------------------------------
# dashboard.dart -- PDS on by default unless explicitly disabled
# ---------------------------------------------------------------------------
p = Path('lib/UI/dashboard.dart')
s = p.read_text(encoding='utf-8')

if "import 'package:flutter/services.dart';" not in s:
    s = replace_once(
        s,
        "import 'package:flutter/material.dart';\n",
        "import 'package:flutter/material.dart';\nimport 'package:flutter/services.dart';\n",
        'dashboard services import',
    )

if "import '../services/app_permission_manager.dart';" not in s:
    s = replace_once(
        s,
        "import '../services/background_service.dart';\n",
        "import '../services/app_permission_manager.dart';\nimport '../services/background_service.dart';\n",
        'dashboard permission import',
    )

if "static const _cameraChannel = 'com.s_health/camera_control';" not in s:
    s = replace_once(
        s,
        "  static const Color subtext = Color(0xFF7D8D89);\n",
        "  static const Color subtext = Color(0xFF7D8D89);\n  static const _cameraChannel = 'com.s_health/camera_control';\n",
        'dashboard camera channel',
    )

if '_ensureDefaultMonitoring();' not in s:
    s = replace_once(
        s,
        "    _refreshMonitoringState();\n",
        "    _refreshMonitoringState();\n    _ensureDefaultMonitoring();\n",
        'dashboard default monitoring call',
    )

if 'Future<void> _ensureDefaultMonitoring() async' not in s:
    marker = '  void _goTo(int index) {'
    helper = '''  Future<void> _ensureDefaultMonitoring() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();

      final configured = prefs.getBool('monitoring_enabled');
      if (configured == false) return;

      final divisor = prefs.getDouble('hunch_divisor');
      if (divisor == null || !divisor.isFinite || divisor <= 0) return;
      if (await BackgroundMonitorService.isRunning) return;

      final granted =
          await AppPermissionManager.ensureMonitoringPermissions();
      if (!granted) return;

      const channel = MethodChannel(_cameraChannel);

      await channel.invokeMethod(
        'saveHunchDivisor',
        {'hunch_divisor': divisor},
      );

      await channel.invokeMethod(
        'startCamera',
        {'hunch_divisor': divisor},
      );

      await BackgroundMonitorService.initialize();
      BackgroundMonitorService.start();
      await prefs.setBool('monitoring_enabled', true);

      if (mounted) {
        setState(() => serviceAlive = true);
      }
    } catch (e, stackTrace) {
      debugPrint('[Dashboard] Default PDS startup failed: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

'''
    if marker not in s:
        raise RuntimeError('dashboard helper insertion point not found')
    s = s.replace(marker, helper + marker, 1)

p.write_text(s, encoding='utf-8')


# ---------------------------------------------------------------------------
# settings_page.dart -- default switch reflects PDS default
# ---------------------------------------------------------------------------
p = Path('lib/UI/settings_page.dart')
s = p.read_text(encoding='utf-8')
s = s.replace(
    "prefs.getBool('monitoring_enabled') ?? false",
    "prefs.getBool('monitoring_enabled') ?? true",
    1,
)
p.write_text(s, encoding='utf-8')


# ---------------------------------------------------------------------------
# main.dart -- dedicated 'user not detected' indicator
# ---------------------------------------------------------------------------
p = Path('lib/main.dart')
s = p.read_text(encoding='utf-8')

if 'bool _showUserNotDetected = false;' not in s:
    s = replace_once(
        s,
        "  bool _showLowLight = false;\n",
        "  bool _showLowLight = false;\n  bool _showUserNotDetected = false;\n",
        'overlay lost-user state',
    )

if "_showUserNotDetected = readBool('userNotDetected');" not in s:
    s = replace_once(
        s,
        "          _showLowLight = readBool('lowLight') || readBool('lowLightPoor');\n",
        "          _showLowLight = readBool('lowLight') || readBool('lowLightPoor');\n          _showUserNotDetected = readBool('userNotDetected');\n",
        'overlay lost-user listener',
    )

if 'Icons.person_off_outlined' not in s:
    s = replace_once(
        s,
        """                    if (_showWrist)
                      _indicatorCircle(Icons.pan_tool, Colors.purple),
""",
        """                    if (_showWrist)
                      _indicatorCircle(Icons.pan_tool, Colors.purple),
                    if (_showUserNotDetected)
                      _indicatorCircle(
                        Icons.person_off_outlined,
                        Colors.blueGrey,
                      ),
""",
        'overlay lost-user icon',
    )

p.write_text(s, encoding='utf-8')

print('PDS stability changes applied successfully.')
