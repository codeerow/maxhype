import 'package:flutter_test/flutter_test.dart';
import 'package:maxhype/services/generator/seeded_rng.dart';

void main() {
  group('SeededRng determinism', () {
    test('same seed produces identical sequences', () {
      final a = SeededRng(42);
      final b = SeededRng(42);
      for (var i = 0; i < 50; i++) {
        expect(a.nextDouble(), b.nextDouble());
      }
    });

    test('different seeds diverge', () {
      final a = SeededRng(1);
      final b = SeededRng(2);
      var anyDifferent = false;
      for (var i = 0; i < 20; i++) {
        if (a.nextDouble() != b.nextDouble()) anyDifferent = true;
      }
      expect(anyDifferent, isTrue);
    });
  });

  group('primitives', () {
    test('nextRange stays within bounds', () {
      final r = SeededRng(7);
      for (var i = 0; i < 100; i++) {
        final v = r.nextRange(5, 10);
        expect(v, greaterThanOrEqualTo(5));
        expect(v, lessThan(10));
      }
    });

    test('chance(0) is never true, chance(1) is always true', () {
      final r = SeededRng(3);
      for (var i = 0; i < 20; i++) {
        expect(r.chance(0), isFalse);
        expect(r.chance(1), isTrue);
      }
    });

    test('pick returns a member and throws on empty', () {
      final r = SeededRng(9);
      expect(['a', 'b', 'c'], contains(r.pick(['a', 'b', 'c'])));
      expect(() => r.pick(<int>[]), throwsArgumentError);
    });

    test('weightedIndex favors heavier weights', () {
      final r = SeededRng(11);
      var zeroCount = 0;
      for (var i = 0; i < 1000; i++) {
        if (r.weightedIndex([10, 1]) == 0) zeroCount++;
      }
      // Index 0 has ~10x the weight; expect a strong majority.
      expect(zeroCount, greaterThan(800));
    });

    test('weightedIndex handles all-zero weights without crashing', () {
      final r = SeededRng(13);
      final idx = r.weightedIndex([0, 0, 0]);
      expect(idx, inInclusiveRange(0, 2));
    });

    test('shuffle is a permutation and deterministic per seed', () {
      final a = [1, 2, 3, 4, 5];
      final b = [1, 2, 3, 4, 5];
      SeededRng(21).shuffle(a);
      SeededRng(21).shuffle(b);
      expect(a, b); // same seed → same order
      expect(a..sort(), [1, 2, 3, 4, 5]); // still a permutation
    });
  });

  group('weightedPickFromTop', () {
    ({T item, double score}) s<T>(T item, double score) =>
        (item: item, score: score);

    test('empty → null, single → that item', () {
      final r = SeededRng(1);
      expect(r.weightedPickFromTop(<({String item, double score})>[]), isNull);
      expect(r.weightedPickFromTop([s('solo', 9)]), 'solo');
    });

    test('deterministic per seed across all three branches', () {
      // small pool (≤5), and large pool (>5) exercise different code paths.
      final small = [s('a', 10), s('b', 6), s('c', 3)];
      final large = [
        for (var i = 0; i < 9; i++) s('e$i', (9 - i).toDouble()),
      ];
      expect(
        SeededRng(5).weightedPickFromTop(small),
        SeededRng(5).weightedPickFromTop(small),
      );
      expect(
        SeededRng(5).weightedPickFromTop(large),
        SeededRng(5).weightedPickFromTop(large),
      );
    });

    test('favors higher scores but does not always pick the top', () {
      // Over many seeds the top-scored item wins most, but not all, of the time.
      final scored = [
        s('top', 100),
        s('mid', 40),
        s('low', 5),
      ];
      var topWins = 0;
      var otherWins = 0;
      for (var seed = 0; seed < 400; seed++) {
        final pick = SeededRng(seed).weightedPickFromTop(scored);
        if (pick == 'top') {
          topWins++;
        } else {
          otherWins++;
        }
      }
      expect(topWins, greaterThan(otherWins),
          reason: 'high score should win the majority');
      expect(otherWins, greaterThan(0),
          reason: 'selection must stay stochastic, not deterministic');
    });

    test('respects TOP_K: candidates past rank 7 are never chosen', () {
      final scored = [
        for (var i = 0; i < 12; i++) s('e$i', (100 - i).toDouble()),
      ];
      final chosen = <String>{};
      for (var seed = 0; seed < 500; seed++) {
        chosen.add(SeededRng(seed).weightedPickFromTop(scored)!);
      }
      // Only the top 7 (e0..e6) can ever be picked.
      for (final name in chosen) {
        final rank = int.parse(name.substring(1));
        expect(rank, lessThan(7), reason: '$name is past TOP_K=7 but was picked');
      }
    });
  });
}
