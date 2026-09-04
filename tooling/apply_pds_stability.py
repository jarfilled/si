from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if new in text:
        return text
    if old not in text:
        raise RuntimeError(f'{label}: marker not found')
    return text.replace(old, new, 1)


# background_service.dart
p = Path('lib/services/background_service.dart')
s = p.read_text(encoding='utf-8')

# The original patch placed these local helpers before the declarations they
# reference. Move only that helper block to the overlay-helper section.
start = s.find('  final pendingOverlayTimers = <String, Timer?>{};')
overlay_decl = s.find('  final overlayState =\n  <String, dynamic>{')
if start >= 0 and overlay_decl > start:
    helper_block = s[start:overlay_decl]
    s = s[:start] + s[overlay_decl:]
    marker = '  // ==========================================================================\n  // OVERLAY FLAG\n  // ==========================================================================\n'
    if marker not in s:
        raise RuntimeError('overlay flag marker not found')
    s = s.replace(marker, helper_block + '\n' + marker, 1)

# Ensure user-not-detected can drive the overlay HUD by itself.
s = replace_once(
    s,
    """    return overlayState['tooClose'] == true;
""",
    """    return overlayState['tooClose'] == true;
""",
    'noop safety marker',
) if "overlayState['tooClose'] == true;\n" in s else s

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
if old in s:
    s = s.replace(old, new, 1)

# Ensure shutdown cannot leave debounce/watchdog timers running.
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
if old in s:
    s = s.replace(old, new, 1)

p.write_text(s, encoding='utf-8')

# main.dart: clear the user-not-detected icon on a raw "none" event.
p = Path('lib/main.dart')
s = p.read_text(encoding='utf-8')
old = """            _showHunch = false;
            _showLowLight = false;
          });"""
new = """            _showHunch = false;
            _showLowLight = false;
            _showUserNotDetected = false;
          });"""
if old in s:
    s = s.replace(old, new, 1)
p.write_text(s, encoding='utf-8')

# Settings should display monitoring as enabled until the user explicitly turns
# it off; preserve an existing explicit false preference.
p = Path('lib/UI/settings_page.dart')
s = p.read_text(encoding='utf-8')
s = s.replace(
    "prefs.getBool('monitoring_enabled') ?? false",
    "prefs.getBool('monitoring_enabled') ?? true",
    1,
)
p.write_text(s, encoding='utf-8')
