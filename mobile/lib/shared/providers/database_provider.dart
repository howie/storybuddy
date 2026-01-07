import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';

/// Provider for the app database.
///
/// This is a singleton that should be disposed when the app is closed.
final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();

  ref.onDispose(() {
    database.close();
  });

  return database;
});
