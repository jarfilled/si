from pathlib import Path
import re


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if new in text:
        return text
    if old not in text:
        raise RuntimeError(f'{label}: expected marker not found')
    return text.replace(old, new, 1)


# ---------------------------------------------------------------------------
# background_service.dart
# ---------------------------------------------------------------------------
p = Path('lib/services/background_service.dart')
s = p.read_text(encoding='utf-8')

# Move the helper block after overlayState/updateWarningState/queueOverlayUpdate.
# Match the declaration structurally so indentation/line wrapping cannot break it.
start_match = re.search(
    r'(?m)^\s*final pendingOverlayTimers\s*=\s*<String, Timer\?>\{\};\s*\n',
    s,
)
overlay_match = re.search(
    r'(?m)^\s*final overlayState\s*=\s*\n?\s*<String, dynamic>\{',
    s,
)
flag_match = re.search(
    r'(?m)^\s*// OVERLAY FLAG\s*$',
    s,
)

if start_match and overlay_match and start_match.start() < overlay_match.start():
    helper_block = s[start_match.start():overlay_match.start()]
    if 'void _setOverlayWarningDebounced' not in helper_block:
        raise RuntimeError('PDS helper block is incomplete')
    s = s[:start_match.start()] + s[overlay_match.start():]
    if not flag_match:
        raise RuntimeError('overlay flag marker not found')
    # Re-find after the extraction.
    flag_match = re.search(r'(?m)^\s*// OVERLAY FLAG\s*$', s)
    s = s[:flag_match.start()] + helper_block + '\n' + s[flag_match.start():]
elif 'void _setOverlayWarningDebounced' not in s:
    raise RuntimeError('PDS debounce helper is missing')

# User-not-detected must keep the HUD open so its icon can be shown.
if "overlayState['userNotDetected'] == true" not in s:
    pattern = re.compile(
        r"(?m)^(\s*)return overlayState\['tooClose'\] == true \|\|\n"
        r"\1    overlayState\['neck'\] == true \|\|\n"
        r"\1    overlayState\['wrist'\] == true \|\|\n"
        r"\1    overlayState\['hunch'\] == true \|\|\n"
        r"\1    overlayState\['lowLight'\] == true;"
    )
    match = pattern.search(s)
    if not match:
        raise RuntimeError('hasActiveWarning expression not found')
    indent = match.group(1)
    replacement = (
        f"{indent}return overlayState['tooClose'] == true ||\n"
        f"{indent}    overlayState['neck'] == true ||\n"
        f"{indent}    overlayState['wrist'] == true ||\n"
        f"{indent}    overlayState['hunch'] == true ||\n"
        f"{indent}    overlayState['lowLight'] == true ||\n"
        f"{indent}    overlayState['userNotDetected'] == true;"
    )
    s = s[:match.start()] + replacement + s[match.end():]

# Shut down the watchdog and all pending debounce timers.
if 'postureDetectionWatchdog = null;' not in s:
    pattern = re.compile(
        r"(?m)^(\s*)pushTimer\?\.cancel\(\);\n"
        r"\1emailTimer\?\.cancel\(\);\n\n"
        r"\1syncService\.dispose\(\);"
    )
    match = pattern.search(s)
    if not match:
        raise RuntimeError('shutdown timer block not found')
    indent = match.group(1)
    replacement = (
        f"{indent}pushTimer?.cancel();\n"
        f"{indent}emailTimer?.cancel();\n"
        f"{indent}postureDetectionWatchdog?.cancel();\n"
        f"{indent}postureDetectionWatchdog = null;\n"
        f"{indent}for (final timer in pendingOverlayTimers.values) {{\n"
        f"{indent}  timer?.cancel();\n"
        f"{indent}}}\n"
        f"{indent}pendingOverlayTimers.clear();\n\n"
        f"{indent}syncService.dispose();"
    )
    s = s[:match.start()] + replacement + s[match.end():]

p.write_text(s, encoding='utf-8')

# ---------------------------------------------------------------------------
# main.dart
# ---------------------------------------------------------------------------
p = Path('lib/main.dart')
s = p.read_text(encoding='utf-8')
if "_showUserNotDetected = false;" not in s:
    pattern = re.compile(
        r"(?m)^(\s*)_showHunch = false;\n"
        r"\1_showLowLight = false;\n"
        r"\1\}\);"
    )
    match = pattern.search(s)
    if not match:
        raise RuntimeError("OverlayHud 'none' reset block not found")
    indent = match.group(1)
    replacement = (
        f"{indent}_showHunch = false;\n"
        f"{indent}_showLowLight = false;\n"
        f"{indent}_showUserNotDetected = false;\n"
        f"{indent}}});"
    )
    s = s[:match.start()] + replacement + s[match.end():]
p.write_text(s, encoding='utf-8')

# ---------------------------------------------------------------------------
# settings_page.dart
# ---------------------------------------------------------------------------
p = Path('lib/UI/settings_page.dart')
s = p.read_text(encoding='utf-8')
s = s.replace("prefs.getBool('monitoring_enabled') ?? false", "prefs.getBool('monitoring_enabled') ?? true", 1)
p.write_text(s, encoding='utf-8')

# Hard assertions: the script must never silently succeed with a broken PDS.
bg = Path('lib/services/background_service.dart').read_text(encoding='utf-8')
main = Path('lib/main.dart').read_text(encoding='utf-8')
settings = Path('lib/UI/settings_page.dart').read_text(encoding='utf-8')
for needle in (
    'const _overlayShowDelay = Duration(milliseconds: 500);',
    'const _overlayHideDelay = Duration(milliseconds: 300);',
    'const _postureDetectionTimeout = Duration(milliseconds: 1500);',
    'bool userNotDetected = false;',
    "overlayState['userNotDetected'] == true;",
    'postureDetectionWatchdog = null;',
):
    if needle not in bg:
        raise RuntimeError(f'Final PDS assertion failed: {needle}')
if '_showUserNotDetected = false;' not in main:
    raise RuntimeError("Final PDS assertion failed: missing HUD none reset")
if "prefs.getBool('monitoring_enabled') ?? true" not in settings:
    raise RuntimeError('Final PDS assertion failed: monitoring default is not true')
