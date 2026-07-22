import 'package:flutter_test/flutter_test.dart';
import 'package:maxhype/core/demo_clock.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RealWeekClock', () {
    test('now() is real time (within a second)', () {
      final clock = const RealWeekClock();
      final delta = clock.now().difference(DateTime.now()).inSeconds.abs();
      expect(delta, lessThanOrEqualTo(1));
    });
  });

  group('DemoWeekClock', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('default offset is 0 → now() equals real time', () async {
      final clock = DemoWeekClock();
      await clock.load();
      expect(clock.weekOffset, 0);
      final delta = clock.now().difference(DateTime.now()).inDays;
      expect(delta, 0);
    });

    test('bumpWeeks shifts now() forward by whole weeks', () async {
      final clock = DemoWeekClock();
      await clock.load();
      await clock.bumpWeeks(2);
      expect(clock.weekOffset, 2);
      final shift = clock.now().difference(DateTime.now()).inDays;
      // 14 days ahead (allow a 1-day slack for the sub-second real-time drift).
      expect(shift, inInclusiveRange(13, 14));
    });

    test('offset is clamped to 0..12', () async {
      final clock = DemoWeekClock();
      await clock.load();
      await clock.bumpWeeks(-5);
      expect(clock.weekOffset, 0);
      await clock.setWeekOffset(99);
      expect(clock.weekOffset, 12);
    });

    test('reset returns to real time', () async {
      final clock = DemoWeekClock();
      await clock.load();
      await clock.bumpWeeks(3);
      await clock.reset();
      expect(clock.weekOffset, 0);
    });

    test('offset persists across instances (survives restart)', () async {
      final a = DemoWeekClock();
      await a.load();
      await a.bumpWeeks(4);

      // A fresh instance reads the persisted offset.
      final b = DemoWeekClock();
      await b.load();
      expect(b.weekOffset, 4);
    });
  });
}
