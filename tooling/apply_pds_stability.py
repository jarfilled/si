from pathlib import Path


def require_replace(text: str, old: str, new: str, label: str) -> str:
    if new in text:
        return text
    if old not in text:
        raise RuntimeError(f'{label}: expected source marker was not found')
    return text.replace(old, new, 1)


# ---------------------------------------------------------------------------
# background_service.dart
# ---------------------------------------------------------------------------
p = Path('lib/services/background_service.dart')
s = p.read_text(encoding='utf-8')

# 1) The helper block must come after overlayState/updateWarningState/
# queueOverlayUpdate so its local references are in scope.
start = s.find('  final pendingOverlayTimers = <String, Timer?>{};')
end = s.find('  final overlayState =', start if start >= 0 else 0)
marker = '  // ==========================================================================\n  // OVERLAY FLAG\n  // ==========================================================================\n'

if start >= 0 and end > start:
    helper_block = s[start:end]
    if 'void _setOverlayWarningDebounced' not in helper_block:
        raise RuntimeError('PDS helper block is incomplete')
    s = s[:start] + s[end:]
    if marker not in s:
        raise RuntimeError('overlay flag marker not found after helper extraction')
    s = s.replace(marker, helper_block + '\n' + marker, 1)
else:
    if 'void _setOverlayWarningDebounced' not in s:
        raise RuntimeError('PDS debounce helpers are missing')

# 2) User-not-detected must keep the HUD alive so person-off icon can be shown.
old = """    return overlayState['tooClose'] == true ||
        overlayState['neck'] == true ||
        overlayState['wrist'] == true ||
        overlayState['hunch'] == true ||
        overlayState['lowLight'] == true;"""
new = """    return overlayState['tooClose'] == true ||
        overlayState['neck'] == true ||
        overlayState['wrist'] == true ||
        overlayState['hunch'] == true ||
        overlayState['lowLight'] == true ||
        overlayState['userNotDetected'] == true;"""
s = require_replace(s, old, new, 'hasActiveWarning')

# 3) No watchdog/debounce timers may survive shutdown.
old = """    pushTimer?.cancel();
    emailTimer?.cancel();

    syncService.dispose();"""
new = """    pushTimer?.cancel();
    emailTimer?.cancel();
    postureDetectionWatchdog?.cancel();
    postureDetectionWatchdog = null;
    for (final timer in pendingOverlayTimers.values) {
      timer?.cancel();
    }
    pendingOverlayTimers.clear();

    syncService.dispose();"""
s = require_replace(s, old, new, 'shutdown timers')

p.write_text(s, encoding='utf-8')

# ---------------------------------------------------------------------------
# main.dart
# ---------------------------------------------------------------------------
p = Path('lib/main.dart')
s = p.read_text(encoding='utf-8')
old = """            _showHunch = false;
            _showLowLight = false;
          });"""
new = """            _showHunch = false;
            _showLowLight = false;
            _showUserNotDetected = false;
          });"""
s = require_replace(s, old, new, "OverlayHud raw 'none' reset")
p.write_text(s, encoding='utf-8')

# ---------------------------------------------------------------------------
# settings_page.dart
# ---------------------------------------------------------------------------
p = Path('lib/UI/settings_page.dart')
s = p.read_text(encoding='utf-8')
old = "prefs.getBool('monitoring_enabled') ?? false"
new = "prefs.getBool('monitoring_enabled') ?? true"
s = s.replace(old, new, 1)
p.write_text(s, encoding='utf-8')

# Final assertions: never report success unless all four fixes are actually in
# the working tree.
bg = Path('lib/services/background_service.dart').read_text(encoding='utf-8')
main = Path('lib/main.dart').read_text(encoding='utf-8')
settings = Path('lib/UI/settings_page.dart').read_text(encoding='utf-8')

required_bg = [
    'const _overlayShowDelay = Duration(milliseconds: 500);',
    'const _overlayHideDelay = Duration(milliseconds: 300);',
    'const _postureDetectionTimeout = Duration(milliseconds: 1500);',
    "overlayState['userNotDetected'] == true;",
    'postureDetectionWatchdog?.cancel();',
]
for needle in required_bg:
    if needle not in bg:
        raise RuntimeError(f'Final PDS assertion failed: {needle}')

if '_showUserNotDetected = false;' not in main:
    raise RuntimeError("Final PDS assertion failed: missing HUD 'none' reset")
if "prefs.getBool('monitoring_enabled') ?? true" not in settings:
    raise RuntimeError('Final PDS assertion failed: monitoring default is not true')
