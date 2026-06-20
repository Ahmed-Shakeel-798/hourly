import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// A ‹ Today › header for browsing days. Disables the forward arrow on today.
class DaySelector extends StatelessWidget {
  final DateTime day;
  final ValueChanged<DateTime> onChanged;

  const DaySelector({super.key, required this.day, required this.onChanged});

  bool get _isToday {
    final now = DateTime.now();
    return day.year == now.year && day.month == now.month && day.day == now.day;
  }

  void _shift(int days) {
    final next = day.add(Duration(days: days));
    if (next.isAfter(DateTime.now())) return;
    onChanged(DateTime(next.year, next.month, next.day));
  }

  @override
  Widget build(BuildContext context) {
    final label = _isToday ? 'Today' : DateFormat('EEE, d MMM').format(day);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: () => _shift(-1),
          icon: const Icon(Icons.chevron_left),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        IconButton(
          onPressed: _isToday ? null : () => _shift(1),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}
