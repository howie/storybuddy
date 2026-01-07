import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Service for initializing the app on startup.
class AppInitializer {
  AppInitializer._();

  static bool _isInitialized = false;

  /// Initializes all app dependencies.
  static Future<void> initialize() async {
    if (_isInitialized) return;

    // Ensure Flutter bindings are initialized
    WidgetsFlutterBinding.ensureInitialized();

    // Set preferred orientations
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // Set system UI overlay style
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    // Database and other services are lazily initialized through Riverpod
    debugPrint('App initialization complete');

    _isInitialized = true;
  }
}

/// Configuration for the app environment.
class AppConfig {
  AppConfig._();

  static const String _devApiUrl = 'http://localhost:8001/api/v1';
  static const String _prodApiUrl = 'https://api.storybuddy.app/api/v1';

  /// Whether the app is in debug mode.
  static bool get isDebug => kDebugMode;

  /// The base URL for the API.
  static String get apiBaseUrl {
    return isDebug ? _devApiUrl : _prodApiUrl;
  }

  /// App version.
  static const String version = '1.0.0';

  /// Build number.
  static const String buildNumber = '1';

  /// Full version string.
  static String get fullVersion => '$version+$buildNumber';
}
