import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storybuddy/features/settings/presentation/providers/settings_provider.dart';

void main() {
  group('AppSettings', () {
    test('should have correct default values', () {
      const settings = AppSettings();

      expect(settings.themeMode, ThemeMode.system);
      expect(settings.language, 'zh-TW');
      expect(settings.autoPlayNext, true);
      expect(settings.qaPromptEnabled, true);
    });

    test('should create with custom values', () {
      const settings = AppSettings(
        themeMode: ThemeMode.dark,
        language: 'en-US',
        autoPlayNext: false,
        qaPromptEnabled: false,
      );

      expect(settings.themeMode, ThemeMode.dark);
      expect(settings.language, 'en-US');
      expect(settings.autoPlayNext, false);
      expect(settings.qaPromptEnabled, false);
    });

    group('copyWith', () {
      test('should return new instance with updated themeMode', () {
        const original = AppSettings(themeMode: ThemeMode.light);
        final updated = original.copyWith(themeMode: ThemeMode.dark);

        expect(updated.themeMode, ThemeMode.dark);
        expect(original.themeMode, ThemeMode.light);
        expect(updated.language, original.language);
        expect(updated.autoPlayNext, original.autoPlayNext);
        expect(updated.qaPromptEnabled, original.qaPromptEnabled);
      });

      test('should return new instance with updated language', () {
        const original = AppSettings(language: 'zh-TW');
        final updated = original.copyWith(language: 'en-US');

        expect(updated.language, 'en-US');
        expect(original.language, 'zh-TW');
      });

      test('should return new instance with updated autoPlayNext', () {
        const original = AppSettings(autoPlayNext: true);
        final updated = original.copyWith(autoPlayNext: false);

        expect(updated.autoPlayNext, false);
        expect(original.autoPlayNext, true);
      });

      test('should return new instance with updated qaPromptEnabled', () {
        const original = AppSettings(qaPromptEnabled: true);
        final updated = original.copyWith(qaPromptEnabled: false);

        expect(updated.qaPromptEnabled, false);
        expect(original.qaPromptEnabled, true);
      });

      test('should keep original values when no parameters provided', () {
        const original = AppSettings(
          themeMode: ThemeMode.dark,
          language: 'en-US',
          autoPlayNext: false,
          qaPromptEnabled: false,
        );
        final updated = original.copyWith();

        expect(updated.themeMode, original.themeMode);
        expect(updated.language, original.language);
        expect(updated.autoPlayNext, original.autoPlayNext);
        expect(updated.qaPromptEnabled, original.qaPromptEnabled);
      });

      test('should update multiple values at once', () {
        const original = AppSettings();
        final updated = original.copyWith(
          themeMode: ThemeMode.dark,
          autoPlayNext: false,
        );

        expect(updated.themeMode, ThemeMode.dark);
        expect(updated.autoPlayNext, false);
        expect(updated.language, original.language);
        expect(updated.qaPromptEnabled, original.qaPromptEnabled);
      });
    });
  });

  group('SettingsKeys', () {
    test('should have correct key values', () {
      expect(SettingsKeys.themeMode, 'theme_mode');
      expect(SettingsKeys.language, 'language');
      expect(SettingsKeys.autoPlayNext, 'auto_play_next');
      expect(SettingsKeys.qaPromptEnabled, 'qa_prompt_enabled');
    });
  });
}
