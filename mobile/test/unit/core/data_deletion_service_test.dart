import 'package:flutter_test/flutter_test.dart';
import 'package:storybuddy/core/data/data_deletion_service.dart';

void main() {
  group('DataDeletionResult', () {
    test('should have correct default values', () {
      const result = DataDeletionResult(success: true);

      expect(result.success, true);
      expect(result.filesDeleted, 0);
      expect(result.recordsDeleted, 0);
      expect(result.errors, isEmpty);
    });

    test('should create with custom values', () {
      const result = DataDeletionResult(
        success: false,
        filesDeleted: 5,
        recordsDeleted: 10,
        errors: ['Error 1', 'Error 2'],
      );

      expect(result.success, false);
      expect(result.filesDeleted, 5);
      expect(result.recordsDeleted, 10);
      expect(result.errors, hasLength(2));
    });

    group('totalDeleted', () {
      test('should return sum of files and records deleted', () {
        const result = DataDeletionResult(
          success: true,
          filesDeleted: 5,
          recordsDeleted: 10,
        );

        expect(result.totalDeleted, 15);
      });

      test('should return zero when nothing deleted', () {
        const result = DataDeletionResult(success: true);

        expect(result.totalDeleted, 0);
      });

      test('should handle only files deleted', () {
        const result = DataDeletionResult(
          success: true,
          filesDeleted: 5,
        );

        expect(result.totalDeleted, 5);
      });

      test('should handle only records deleted', () {
        const result = DataDeletionResult(
          success: true,
          recordsDeleted: 10,
        );

        expect(result.totalDeleted, 10);
      });
    });
  });
}
