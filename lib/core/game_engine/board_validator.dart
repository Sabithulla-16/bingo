/// Result of validating a Bingo board numbers configuration.
class BoardValidationResult {
  final bool isValid;
  final String? errorSummary;
  final Set<int> missingNumbers;
  final Set<int> duplicateNumbers;
  final Set<int> outOfRangeNumbers;
  final int emptySlotsCount;

  const BoardValidationResult({
    required this.isValid,
    this.errorSummary,
    this.missingNumbers = const {},
    this.duplicateNumbers = const {},
    this.outOfRangeNumbers = const {},
    this.emptySlotsCount = 0,
  });

  static const BoardValidationResult valid = BoardValidationResult(isValid: true);
}

/// Static validator enforcing the bijection invariant on 5x5 Bingo boards.
class BoardValidator {
  const BoardValidator._();

  /// Validates a list of 25 cell numbers against the official BINGO rules:
  /// - Exactly 25 total cells.
  /// - Every number from 1 to 25 inclusive must appear exactly once.
  /// - No 0, negative, or >25 numbers.
  static BoardValidationResult validate(List<int> numbers) {
    if (numbers.length != 25) {
      return BoardValidationResult(
        isValid: false,
        errorSummary: 'Board must contain exactly 25 cells (found ${numbers.length}).',
        emptySlotsCount: 25 - numbers.length > 0 ? 25 - numbers.length : 0,
      );
    }

    final seen = <int>{};
    final duplicates = <int>{};
    final outOfRange = <int>{};
    int emptyCount = 0;

    for (final num in numbers) {
      if (num == 0) {
        emptyCount++;
        continue;
      }

      if (num < 1 || num > 25) {
        outOfRange.add(num);
      }

      if (seen.contains(num)) {
        duplicates.add(num);
      } else {
        seen.add(num);
      }
    }

    final allExpected = List<int>.generate(25, (i) => i + 1).toSet();
    final missing = allExpected.difference(seen);

    if (emptyCount > 0) {
      return BoardValidationResult(
        isValid: false,
        errorSummary: '$emptyCount cells are unassigned. Please fill all 25 numbers.',
        missingNumbers: missing,
        duplicateNumbers: duplicates,
        outOfRangeNumbers: outOfRange,
        emptySlotsCount: emptyCount,
      );
    }

    if (outOfRange.isNotEmpty) {
      return BoardValidationResult(
        isValid: false,
        errorSummary: 'Numbers must be between 1 and 25 (found: ${outOfRange.join(', ')}).',
        missingNumbers: missing,
        duplicateNumbers: duplicates,
        outOfRangeNumbers: outOfRange,
      );
    }

    if (duplicates.isNotEmpty) {
      return BoardValidationResult(
        isValid: false,
        errorSummary: 'Duplicate numbers detected: ${duplicates.join(', ')}.',
        missingNumbers: missing,
        duplicateNumbers: duplicates,
      );
    }

    if (missing.isNotEmpty) {
      return BoardValidationResult(
        isValid: false,
        errorSummary: 'Missing numbers from 1 to 25: ${missing.join(', ')}.',
        missingNumbers: missing,
      );
    }

    return BoardValidationResult.valid;
  }
}
