import 'package:flutter_test/flutter_test.dart';
import 'package:maxhype/models/session/personal_record.dart';

void main() {
  PersonalRecord pr({double weight = 100, int reps = 5}) => PersonalRecord(
        exerciseId: 'ex1',
        weight: weight,
        reps: reps,
        achievedAt: DateTime(2025, 1, 1),
      );

  group('PersonalRecord.isBeatenBy', () {
    test('heavier weight beats lighter weight regardless of reps', () {
      expect(pr().isBeatenBy(weight: 101, reps: 1), isTrue);
      expect(pr().isBeatenBy(weight: 101, reps: 10), isTrue);
    });

    test('same weight more reps beats', () {
      expect(pr().isBeatenBy(weight: 100, reps: 6), isTrue);
    });

    test('same weight same reps does NOT beat (strict inequality)', () {
      expect(pr().isBeatenBy(weight: 100, reps: 5), isFalse);
    });

    test('same weight fewer reps does NOT beat', () {
      expect(pr().isBeatenBy(weight: 100, reps: 4), isFalse);
    });

    test('lighter weight more reps does NOT beat', () {
      expect(pr().isBeatenBy(weight: 99, reps: 50), isFalse);
    });

    test('non-positive weight or reps is rejected', () {
      expect(pr().isBeatenBy(weight: 0, reps: 5), isFalse);
      expect(pr().isBeatenBy(weight: -1, reps: 5), isFalse);
      expect(pr().isBeatenBy(weight: 200, reps: 0), isFalse);
      expect(pr().isBeatenBy(weight: 200, reps: -1), isFalse);
    });
  });
}