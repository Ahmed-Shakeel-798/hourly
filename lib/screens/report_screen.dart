import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/activity_log.dart';
import '../models/app_usage.dart';
import '../services/database_service.dart';
import '../services/usage_service.dart';
import '../theme.dart';
import '../utils/formatting.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _usage = UsageService();
  final _db = DatabaseService.instance;

  DateTime _day = DateTime.now();
  bool _loading = true;
  bool _hasPermission = false;
  Duration _total = Duration.zero;
  List<AppUsage> _apps = [];
  List<ActivityLog> _logs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final granted = await _usage.hasPermission();
    final apps = granted ? await _usage.usageForDay(_day) : <AppUsage>[];
    final total = apps.fold(Duration.zero, (s, a) => s + a.time);
    final logs = await _db.logsForDay(_day);
    if (!mounted) return;
    setState(() {
      _hasPermission = granted;
      _apps = apps;
      _total = total;
      _logs = logs;
      _loading = false;
    });
  }

  void _shiftDay(int days) {
    final next = _day.add(Duration(days: days));
    if (next.isAfter(DateTime.now())) return; // no future days
    _day = next;
    _load();
  }

  bool get _isToday {
    final now = DateTime.now();
    return _day.year == now.year &&
        _day.month == now.month &&
        _day.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: [
                _dayPicker(),
                const SizedBox(height: 20),
                _summary(),
                const SizedBox(height: 28),
                _section('App breakdown'),
                const SizedBox(height: 10),
                _breakdown(),
                const SizedBox(height: 28),
                _section('Activity timeline'),
                const SizedBox(height: 10),
                _timeline(),
              ],
            ),
    );
  }

  Widget _dayPicker() {
    final label = _isToday
        ? 'Today'
        : DateFormat('EEE, d MMM').format(_day);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: () => _shiftDay(-1),
          icon: const Icon(Icons.chevron_left),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        IconButton(
          onPressed: _isToday ? null : () => _shiftDay(1),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Widget _summary() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Text(
            _hasPermission ? formatDuration(_total) : '—',
            style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text('total screen time',
              style: TextStyle(color: AppTheme.muted)),
          const SizedBox(height: 16),
          Text(
            '${_logs.length} check-in${_logs.length == 1 ? '' : 's'} logged',
            style: const TextStyle(color: AppTheme.muted),
          ),
        ],
      ),
    );
  }

  Widget _section(String text) => Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppTheme.muted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.0,
        ),
      );

  Widget _breakdown() {
    if (!_hasPermission) {
      return const Text('Grant usage access on the home screen.',
          style: TextStyle(color: AppTheme.muted));
    }
    if (_apps.isEmpty) {
      return const Text('No usage recorded.',
          style: TextStyle(color: AppTheme.muted));
    }
    final max = _apps.first.time.inSeconds.clamp(1, 1 << 31);
    return Column(
      children: [
        for (final app in _apps.take(12))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(app.label,
                          overflow: TextOverflow.ellipsis,
                          style:
                              const TextStyle(fontWeight: FontWeight.w500)),
                    ),
                    Text(formatDuration(app.time),
                        style: const TextStyle(color: AppTheme.muted)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (app.time.inSeconds / max).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: AppTheme.surface(context),
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppTheme.ink(context)),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _timeline() {
    if (_logs.isEmpty) {
      return const Text('No check-ins logged this day.',
          style: TextStyle(color: AppTheme.muted));
    }
    return Column(
      children: [
        for (final log in _logs)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 52,
                  child: Text(
                    DateFormat('HH:mm').format(log.time),
                    style: const TextStyle(
                      color: AppTheme.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(log.text, style: const TextStyle(height: 1.3)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
