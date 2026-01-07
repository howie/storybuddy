import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'settings_provider.g.dart';

/// Settings keys for SharedPreferences.
class SettingsKeys {
  static const String themeMode = 'theme_mode';
  static const String language = 'language';
  static const String autoPlayNext = 'auto_play_next';
  static const String qaPromptEnabled = 'qa_prompt_enabled';
}

/// App settings state.
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.language = 'zh-TW',
    this.autoPlayNext = true,
    this.qaPromptEnabled = true,
  });

  final ThemeMode themeMode;
  final String language;
  final bool autoPlayNext;
  final bool qaPromptEnabled;

  AppSettings copyWith({
    ThemeMode? themeMode,
    String? language,
    bool? autoPlayNext,
    bool? qaPromptEnabled,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      language: language ?? this.language,
      autoPlayNext: autoPlayNext ?? this.autoPlayNext,
      qaPromptEnabled: qaPromptEnabled ?? this.qaPromptEnabled,
    );
  }
}

/// Provider for SharedPreferences.
@riverpod
Future<SharedPreferences> sharedPreferences(SharedPreferencesRef ref) async {
  return SharedPreferences.getInstance();
}

/// Provider for app settings.
@riverpod
class SettingsNotifier extends _$SettingsNotifier {
  @override
  Future<AppSettings> build() async {
    return _loadSettings();
  }

  Future<AppSettings> _loadSettings() async {
    final prefs = await ref.read(sharedPreferencesProvider.future);

    final themeModeIndex = prefs.getInt(SettingsKeys.themeMode) ?? 0;
    final language = prefs.getString(SettingsKeys.language) ?? 'zh-TW';
    final autoPlayNext = prefs.getBool(SettingsKeys.autoPlayNext) ?? true;
    final qaPromptEnabled = prefs.getBool(SettingsKeys.qaPromptEnabled) ?? true;

    return AppSettings(
      themeMode: ThemeMode.values[themeModeIndex],
      language: language,
      autoPlayNext: autoPlayNext,
      qaPromptEnabled: qaPromptEnabled,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setInt(SettingsKeys.themeMode, mode.index);

    final current = state.valueOrNull ?? const AppSettings();
    state = AsyncData(current.copyWith(themeMode: mode));
  }

  Future<void> setLanguage(String language) async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setString(SettingsKeys.language, language);

    final current = state.valueOrNull ?? const AppSettings();
    state = AsyncData(current.copyWith(language: language));
  }

  Future<void> setAutoPlayNext(bool enabled) async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setBool(SettingsKeys.autoPlayNext, enabled);

    final current = state.valueOrNull ?? const AppSettings();
    state = AsyncData(current.copyWith(autoPlayNext: enabled));
  }

  Future<void> setQAPromptEnabled(bool enabled) async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setBool(SettingsKeys.qaPromptEnabled, enabled);

    final current = state.valueOrNull ?? const AppSettings();
    state = AsyncData(current.copyWith(qaPromptEnabled: enabled));
  }
}

/// Provider for current theme mode.
@riverpod
ThemeMode currentThemeMode(CurrentThemeModeRef ref) {
  final settings = ref.watch(settingsNotifierProvider);
  return settings.valueOrNull?.themeMode ?? ThemeMode.system;
}
