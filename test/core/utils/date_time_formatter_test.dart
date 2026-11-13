import 'package:flutter_test/flutter_test.dart';
import 'package:pulsegrid/core/utils/date_time_formatter.dart';

void main() {
  test('time12Hour converts UTC DateTime to local 12-hour format', () {
    final utc = DateTime.utc(2026, 11, 13, 16, 40);
    final local = utc.toLocal();
    final expectedHour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final expectedPeriod = local.hour >= 12 ? 'PM' : 'AM';
    final expectedMinute = local.minute.toString().padLeft(2, '0');

    expect(
      DateTimeFormatter.time12Hour(utc),
      '$expectedHour12:$expectedMinute $expectedPeriod',
    );
  });

  test('timelineTimestamp includes Today and local 12-hour time', () {
    final nowUtc = DateTime.now().toUtc();
    final result = DateTimeFormatter.timelineTimestamp(nowUtc);

    expect(result, startsWith('Today · '));
    expect(result, contains(DateTimeFormatter.time12Hour(nowUtc)));
  });

  test('dateTime12Hour formats local 12-hour time and dd-MM-yyyy date', () {
    final local = DateTime(2026, 11, 13, 0, 5);
    expect(
      DateTimeFormatter.dateTime12Hour(local.toUtc()),
      '12:05 AM • 13-11-2026',
    );
  });
}

