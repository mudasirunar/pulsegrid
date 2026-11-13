/// Centralized local-timezone, 12-hour date and time formatting utilities.
abstract class DateTimeFormatter {
  static const List<String> _shortMonths = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// Formats [dt] in local time using 12-hour format (e.g. `9:40 PM`).
  static String time12Hour(DateTime dt) {
    final local = dt.toLocal();
    final hour24 = local.hour;
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour12:$minute $period';
  }

  /// Formats [dt] in local time as `9:40 PM • 13-11-2026`.
  static String dateTime12Hour(DateTime dt) {
    final local = dt.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '${time12Hour(local)} • $day-$month-${local.year}';
  }

  /// Formats [dt] in local time for timeline entries:
  /// `Today · 9:40 PM`, `Yesterday · 9:40 PM`, or `Nov 13 · 9:40 PM`.
  static String timelineTimestamp(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();
    final isToday = local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = local.year == yesterday.year &&
        local.month == yesterday.month &&
        local.day == yesterday.day;

    final timeStr = time12Hour(local);
    if (isToday) {
      return 'Today · $timeStr';
    } else if (isYesterday) {
      return 'Yesterday · $timeStr';
    } else {
      final monthStr = _shortMonths[local.month - 1];
      return '$monthStr ${local.day} · $timeStr';
    }
  }

  /// Formats [dt] relative to current local time (e.g. `5 mins ago`).
  static String timeAgo(DateTime dt) {
    final local = dt.toLocal();
    final difference = DateTime.now().difference(local);

    if (difference.isNegative || difference.inSeconds < 45) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      final mins = difference.inMinutes;
      return '$mins ${mins == 1 ? 'min' : 'mins'} ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return '$days ${days == 1 ? 'day' : 'days'} ago';
    } else {
      final day = local.day.toString().padLeft(2, '0');
      final month = local.month.toString().padLeft(2, '0');
      return '$day-$month-${local.year}';
    }
  }

  /// Compact relative time (e.g. `just now`, `5m ago`, `2h ago`, `3d ago`).
  static String compactTimeAgo(DateTime dt) {
    final local = dt.toLocal();
    final diff = DateTime.now().difference(local);
    if (diff.isNegative || diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

