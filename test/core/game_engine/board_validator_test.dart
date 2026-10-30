import 'package:flutter_test/flutter_test.dart';
import 'package:bingo/core/game_engine/board_validator.dart';

void main() {
  group('BoardValidator Tests', () {
    test('validates 1..25 permutation successfully', () {
      final validNumbers = List<int>.generate(25, (i) => i + 1);
      final result = BoardValidator.validate(validNumbers);

      expect(result.isValid, isTrue);
      expect(result.errorSummary, isNull);
      expect(result.missingNumbers, isEmpty);
      expect(result.duplicateNumbers, isEmpty);
    });

    test('rejects board with incorrect length', () {
      final shortList = [1, 2, 3, 4, 5];
      final result = BoardValidator.validate(shortList);

      expect(result.isValid, isFalse);
      expect(result.errorSummary, contains('Board must contain exactly 25 cells'));
    });

    test('detects duplicate numbers and identifies them', () {
      final numbers = List<int>.generate(25, (i) => i + 1);
      numbers[24] = 1; // Duplicate 1, missing 25

      final result = BoardValidator.validate(numbers);

      expect(result.isValid, isFalse);
      expect(result.duplicateNumbers, contains(1));
      expect(result.missingNumbers, contains(25));
    });

    test('detects numbers out of the 1..25 range', () {
      final numbers = List<int>.generate(25, (i) => i + 1);
      numbers[0] = 99; // 99 is out of range, missing 1

      final result = BoardValidator.validate(numbers);

      expect(result.isValid, isFalse);
      expect(result.outOfRangeNumbers, contains(99));
      expect(result.missingNumbers, contains(1));
    });

    test('detects unassigned zeros during board preparation', () {
      final partialNumbers = List<int>.filled(25, 0);
      partialNumbers[0] = 5;
      partialNumbers[1] = 12;

      final result = BoardValidator.validate(partialNumbers);

      expect(result.isValid, isFalse);
      expect(result.emptySlotsCount, equals(23));
      expect(result.errorSummary, contains('23 cells are unassigned'));
    });
  });
}
