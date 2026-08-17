import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum MonitoringSoundType {
  defaultSound,
  custom,
  recorded,
  none,
}

class MonitoringSoundConfig {
  final MonitoringSoundType type;
  final String? path;

  const MonitoringSoundConfig({
    required this.type,
    this.path,
  });

  bool get isDisabled => type == MonitoringSoundType.none;

  bool get isCustom =>
      type == MonitoringSoundType.custom ||
          type == MonitoringSoundType.recorded;
}

class MonitoringAudioManager {
  MonitoringAudioManager._();

  static final MonitoringAudioManager instance =
  MonitoringAudioManager._();

  // ---------------------------------------------------------------------------
  // ALERT NAMES
  // ---------------------------------------------------------------------------

  static const List<String> alertTypes = [
    'tooClose',
    'neck',
    'wrist',
    'hunch',
    'lowLight',
  ];

  // ---------------------------------------------------------------------------
  // PREFERENCE KEYS
  // ---------------------------------------------------------------------------

  static const String _globalEnabledKey =
      'monitoring_audio_enabled';

  static String _typeKey(String alert) =>
      'monitoring_audio_type_$alert';

  static String _pathKey(String alert) =>
      'monitoring_audio_path_$alert';

  // ---------------------------------------------------------------------------
  // DEFAULT ASSETS
  //
  // These must match the filenames you already placed in:
  //
  // assets/sounds/
  // ---------------------------------------------------------------------------

  static const Map<String, String> _defaultAssets = {
    'tooClose': 'sounds/too_close.wav',
    'neck': 'sounds/neck.wav',
    'hunch': 'sounds/hunch.wav',
    'wrist': 'sounds/wrist.wav',
    'lowLight': 'sounds/low_light.wav',
  };

  // ---------------------------------------------------------------------------
  // AUDIO
  // ---------------------------------------------------------------------------

  final AudioPlayer _player = AudioPlayer();

  // Recorder used by the settings page.
  final AudioRecorder _recorder = AudioRecorder();

  SharedPreferences? _prefs;

  bool _initialized = false;

  bool _globalEnabled = true;

  // ---------------------------------------------------------------------------
  // ACTIVE ALERTS
  //
  // Prevents an alert from being played continuously while the condition
  // remains true.
  // ---------------------------------------------------------------------------

  final Set<String> _activeAlerts = <String>{};

  // Last time each alert actually produced a sound.
  final Map<String, DateTime> _lastPlayed = <String, DateTime>{};

  // Cooldown between repeated sounds for the same alert.
  //
  // The visual overlay remains immediate. This only affects audio.
  static const Duration _soundCooldown =
  Duration(seconds: 3);

  // ---------------------------------------------------------------------------
  // INITIALIZATION
  // ---------------------------------------------------------------------------

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _prefs = await SharedPreferences.getInstance();

    _globalEnabled =
        _prefs?.getBool(_globalEnabledKey) ?? true;

    _initialized = true;

    debugPrint(
      '[MonitoringAudio] Initialized. '
          'globalEnabled=$_globalEnabled',
    );
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }

  // ---------------------------------------------------------------------------
  // GLOBAL SOUND ENABLE/DISABLE
  // ---------------------------------------------------------------------------

  bool get isEnabled => _globalEnabled;

  Future<void> setEnabled(bool enabled) async {
    await _ensureInitialized();

    _globalEnabled = enabled;

    await _prefs?.setBool(
      _globalEnabledKey,
      enabled,
    );

    if (!enabled) {
      await stop();

      debugPrint(
        '[MonitoringAudio] Global audio disabled.',
      );
    } else {
      debugPrint(
        '[MonitoringAudio] Global audio enabled.',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // GET CONFIGURATION
  // ---------------------------------------------------------------------------

  Future<MonitoringSoundConfig> getConfig(
      String alertType,
      ) async {
    await _ensureInitialized();

    _validateAlertType(alertType);

    final typeString =
    _prefs?.getString(_typeKey(alertType));

    final path =
    _prefs?.getString(_pathKey(alertType));

    final type = _parseType(typeString);

    return MonitoringSoundConfig(
      type: type,
      path: path,
    );
  }

  Future<Map<String, MonitoringSoundConfig>>
  getAllConfigs() async {
    await _ensureInitialized();

    final result =
    <String, MonitoringSoundConfig>{};

    for (final alert in alertTypes) {
      result[alert] = await getConfig(alert);
    }

    return result;
  }

  // ---------------------------------------------------------------------------
  // SET SOUND TYPE
  // ---------------------------------------------------------------------------

  Future<void> setAlertSound(
      String alertType,
      MonitoringSoundType type, {
        String? path,
      }) async {
    await _ensureInitialized();

    _validateAlertType(alertType);

    await _prefs?.setString(
      _typeKey(alertType),
      type.name,
    );

    if (path != null && path.isNotEmpty) {
      await _prefs?.setString(
        _pathKey(alertType),
        path,
      );
    } else {
      await _prefs?.remove(
        _pathKey(alertType),
      );
    }

    // If the user disables the alert sound while that alert is currently
    // active, stop any sound immediately.
    if (type == MonitoringSoundType.none) {
      _lastPlayed.remove(alertType);
    }

    debugPrint(
      '[MonitoringAudio] '
          'Set $alertType -> ${type.name}'
          '${path != null ? ' ($path)' : ''}',
    );
  }

  // ---------------------------------------------------------------------------
  // USE DEFAULT SOUND
  // ---------------------------------------------------------------------------

  Future<void> useDefaultSound(
      String alertType,
      ) async {
    await setAlertSound(
      alertType,
      MonitoringSoundType.defaultSound,
    );
  }

  // ---------------------------------------------------------------------------
  // DISABLE INDIVIDUAL SOUND
  // ---------------------------------------------------------------------------

  Future<void> disableAlertSound(
      String alertType,
      ) async {
    await setAlertSound(
      alertType,
      MonitoringSoundType.none,
    );
  }

  // ---------------------------------------------------------------------------
  // IMPORT CUSTOM SOUND
  //
  // The settings page supplies the path returned by file_picker.
  // We copy it into our own application directory.
  // ---------------------------------------------------------------------------

  Future<String> importCustomSound(
      String sourcePath,
      String alertType,
      ) async {
    await _ensureInitialized();

    _validateAlertType(alertType);

    final source = File(sourcePath);

    if (!await source.exists()) {
      throw Exception(
        'Selected audio file no longer exists.',
      );
    }

    final directory =
    await _getSoundsDirectory();

    final extension =
    _extensionOf(sourcePath);

    final destination = File(
      '${directory.path}/'
          '${alertType}_custom$extension',
    );

    if (await destination.exists()) {
      await destination.delete();
    }

    await source.copy(destination.path);

    await setAlertSound(
      alertType,
      MonitoringSoundType.custom,
      path: destination.path,
    );

    debugPrint(
      '[MonitoringAudio] Imported custom sound: '
          '${destination.path}',
    );

    return destination.path;
  }

  // ---------------------------------------------------------------------------
  // RECORDING
  // ---------------------------------------------------------------------------

  Future<bool> hasRecordingPermission() async {
    return _recorder.hasPermission();
  }

  Future<void> startRecording(
      String alertType,
      ) async {
    await _ensureInitialized();

    _validateAlertType(alertType);

    if (await _recorder.isRecording()) {
      throw StateError(
        'A recording is already in progress.',
      );
    }

    final hasPermission =
    await _recorder.hasPermission();

    if (!hasPermission) {
      throw PermissionException(
        'Microphone permission was not granted.',
      );
    }

    final directory =
    await _getSoundsDirectory();

    final path =
        '${directory.path}/${alertType}_recorded.m4a';

    final existing = File(path);

    if (await existing.exists()) {
      await existing.delete();
    }

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: path,
    );

    debugPrint(
      '[MonitoringAudio] '
          'Recording started for $alertType',
    );
  }

  Future<String?> stopRecording(
      String alertType,
      ) async {
    await _ensureInitialized();

    _validateAlertType(alertType);

    final path = await _recorder.stop();

    if (path == null || path.isEmpty) {
      return null;
    }

    final file = File(path);

    if (!await file.exists()) {
      return null;
    }

    await setAlertSound(
      alertType,
      MonitoringSoundType.recorded,
      path: path,
    );

    debugPrint(
      '[MonitoringAudio] '
          'Recording saved: $path',
    );

    return path;
  }

  Future<void> cancelRecording() async {
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
  }

  Future<bool> isRecording() {
    return _recorder.isRecording();
  }

  // ---------------------------------------------------------------------------
  // DELETE CUSTOM / RECORDED SOUND
  // ---------------------------------------------------------------------------

  Future<void> deleteCustomSound(
      String alertType,
      ) async {
    await _ensureInitialized();

    _validateAlertType(alertType);

    final config =
    await getConfig(alertType);

    if (config.path != null &&
        config.path!.isNotEmpty) {
      try {
        final file =
        File(config.path!);

        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint(
          '[MonitoringAudio] '
              'Failed to delete custom sound: $e',
        );
      }
    }

    await useDefaultSound(alertType);
  }

  // ---------------------------------------------------------------------------
  // PLAY ALERT
  //
  // This is the method called by background_service.dart.
  // ---------------------------------------------------------------------------

  Future<void> trigger(
      String alertType,
      ) async {
    await _ensureInitialized();

    _validateAlertType(alertType);

    if (!_globalEnabled) {
      return;
    }

    // Mark the alert as active.
    final wasAlreadyActive =
    _activeAlerts.contains(alertType);

    _activeAlerts.add(alertType);

    // If this exact warning is already active, don't immediately replay it.
    if (wasAlreadyActive) {
      return;
    }

    final now = DateTime.now();

    final last =
    _lastPlayed[alertType];

    if (last != null &&
        now.difference(last) <
            _soundCooldown) {
      return;
    }

    final config =
    await getConfig(alertType);

    if (config.isDisabled) {
      debugPrint(
        '[MonitoringAudio] '
            'Sound disabled for $alertType.',
      );
      return;
    }

    _lastPlayed[alertType] = now;

    await _playConfig(
      alertType,
      config,
    );
  }

  // ---------------------------------------------------------------------------
  // CLEAR ACTIVE ALERT
  // ---------------------------------------------------------------------------

  void clear(String alertType) {
    if (!_activeAlerts.remove(alertType)) {
      return;
    }

    debugPrint(
      '[MonitoringAudio] '
          'Cleared alert: $alertType',
    );
  }

  // ---------------------------------------------------------------------------
  // PLAY CONFIGURATION
  // ---------------------------------------------------------------------------

  Future<void> _playConfig(
      String alertType,
      MonitoringSoundConfig config,
      ) async {
    try {
      if (config.type ==
          MonitoringSoundType.defaultSound) {
        final asset =
        _defaultAssets[alertType];

        if (asset == null) {
          debugPrint(
            '[MonitoringAudio] '
                'No default asset for $alertType',
          );
          return;
        }

        await _player.stop();

        await _player.setAsset(asset);

        await _player.play();

        return;
      }

      if (config.isCustom) {
        final path = config.path;

        if (path == null ||
            path.isEmpty) {
          debugPrint(
            '[MonitoringAudio] '
                'Custom sound has no path. '
                'Falling back to default.',
          );

          await _playDefault(alertType);
          return;
        }

        final file = File(path);

        if (!await file.exists()) {
          debugPrint(
            '[MonitoringAudio] '
                'Custom sound missing: $path. '
                'Falling back to default.',
          );

          // Automatically repair the setting.
          await useDefaultSound(alertType);

          await _playDefault(alertType);
          return;
        }

        await _player.stop();

        await _player.setFilePath(
          file.path,
        );

        await _player.play();

        return;
      }
    } catch (error, stackTrace) {
      debugPrint(
        '[MonitoringAudio] '
            'Failed to play $alertType: $error',
      );

      debugPrint('$stackTrace');
    }
  }

  Future<void> _playDefault(
      String alertType,
      ) async {
    final asset =
    _defaultAssets[alertType];

    if (asset == null) {
      return;
    }

    try {
      await _player.stop();
      await _player.setAsset(asset);
      await _player.play();
    } catch (e) {
      debugPrint(
        '[MonitoringAudio] '
            'Default playback failed: $e',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // PREVIEW
  //
  // Used by the settings UI.
  //
  // Unlike trigger(), preview ignores the cooldown and does not mark the
  // warning as active.
  // ---------------------------------------------------------------------------

  Future<void> preview(
      String alertType,
      ) async {
    await _ensureInitialized();

    _validateAlertType(alertType);

    final config =
    await getConfig(alertType);

    if (config.isDisabled) {
      return;
    }

    await _playConfig(
      alertType,
      config,
    );
  }

  // ---------------------------------------------------------------------------
  // STOP PLAYBACK
  // ---------------------------------------------------------------------------

  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (e) {
      debugPrint(
        '[MonitoringAudio] '
            'Failed to stop playback: $e',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // CLEANUP
  // ---------------------------------------------------------------------------

  Future<void> dispose() async {
    try {
      await _recorder.dispose();
    } catch (_) {}

    try {
      await _player.dispose();
    } catch (_) {}

    _activeAlerts.clear();
    _lastPlayed.clear();

    _initialized = false;
  }

  // ---------------------------------------------------------------------------
  // STORAGE
  // ---------------------------------------------------------------------------

  Future<Directory> _getSoundsDirectory() async {
    final appDirectory =
    await getApplicationDocumentsDirectory();

    final directory = Directory(
      '${appDirectory.path}/monitoring_sounds',
    );

    if (!await directory.exists()) {
      await directory.create(
        recursive: true,
      );
    }

    return directory;
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  MonitoringSoundType _parseType(
      String? value,
      ) {
    switch (value) {
      case 'custom':
        return MonitoringSoundType.custom;

      case 'recorded':
        return MonitoringSoundType.recorded;

      case 'none':
        return MonitoringSoundType.none;

      case 'defaultSound':
      default:
        return MonitoringSoundType.defaultSound;
    }
  }

  String _extensionOf(String path) {
    final dot = path.lastIndexOf('.');

    if (dot == -1) {
      return '.m4a';
    }

    final extension =
    path.substring(dot).toLowerCase();

    // Keep only sane audio extensions.
    const allowed = {
      '.mp3',
      '.wav',
      '.m4a',
      '.aac',
      '.ogg',
      '.flac',
    };

    if (!allowed.contains(extension)) {
      return '.m4a';
    }

    return extension;
  }

  void _validateAlertType(
      String alertType,
      ) {
    if (!alertTypes.contains(alertType)) {
      throw ArgumentError(
        'Unknown monitoring alert type: $alertType',
      );
    }
  }
}