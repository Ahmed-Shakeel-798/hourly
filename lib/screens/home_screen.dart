import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/activity_log.dart';
import '../models/app_usage.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../services/theme_controller.dart';
import '../services/usage_service.dart';
import '../theme.dart';
import '../utils/formatting.dart';
import 'report_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _usage = UsageService();
  final _db = DatabaseService.instance;

  bool _loading = true;
  bool _hasPermission = false;
  bool _checkinsEnabled = false;
  Duration _total = Duration.zero;
  List<AppUsage> _apps = [];
  List<ActivityLog> _logs = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    logsRevision.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    logsRevision.removeListener(_load);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final today = DateTime.now();
    final granted = await _usage.hasPermission();

    Duration total = Duration.zero;
    List<AppUsage> apps = [];
    if (granted) {
      apps = await _usage.usageForDay(today);
      total = apps.fold(Duration.zero, (s, a) => s + a.time);
    }
    final logs = await _db.logsForDay(today);
    final enabled = await NotificationService.instance.isCheckinEnabled();

    if (!mounted) return;
    setState(() {
      _hasPermission = granted;
      _checkinsEnabled = enabled;
      _total = total;
      _apps = apps;
      _logs = logs;
      _loading = false;
    });
  }

  Future<void> _enableTracking() async {
    await NotificationService.instance.enableCheckins();
    if (!mounted) return;
    setState(() => _checkinsEnabled = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Hourly check-ins enabled.')),
    );
  }

  Future<void> _disableTracking() async {
    await NotificationService.instance.disableCheckins();
    if (!mounted) return;
    setState(() => _checkinsEnabled = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Hourly check-ins turned off.')),
    );
  }

  Future<void> _addManualLog() async {
    final text = await showDialog<String>(
      context: context,
      builder: (_) => const _AddLogDialog(),
    );
    if (text == null || text.trim().isEmpty) return;
    await _db.insertLog(
      ActivityLog(time: DateTime.now(), text: text.trim(), source: 'manual'),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Today'),
        actions: [
          const _ThemeMenuButton(),
          IconButton(
            tooltip: 'Report',
            icon: const Icon(Icons.bar_chart_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ReportScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.ink(context),
        foregroundColor: AppTheme.onInk(context),
        elevation: 0,
        onPressed: _addManualLog,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
                children: [
                  if (!_hasPermission) _permissionCard(),
                  _totalCard(),
                  const SizedBox(height: 28),
                  _sectionLabel('Top apps'),
                  const SizedBox(height: 8),
                  _appsList(),
                  const SizedBox(height: 28),
                  _sectionLabel('Check-ins'),
                  const SizedBox(height: 8),
                  _logsList(),
                ],
              ),
            ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppTheme.muted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.0,
        ),
      );

  Widget _permissionCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Usage access needed',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 6),
          const Text(
            'Grant "Usage access" so the app can read your screen time.',
            style: TextStyle(color: AppTheme.muted, height: 1.4),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: () async {
              await _usage.requestPermission();
            },
            child: const Text('Grant access'),
          ),
        ],
      ),
    );
  }

  Widget _totalCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          const Text(
            'SCREEN TIME',
            style: TextStyle(
              color: AppTheme.muted,
              fontSize: 12,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _hasPermission ? formatDuration(_total) : '—',
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w700,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 20),
          _checkinsEnabled ? _checkinsOnControl() : _enableButton(),
        ],
      ),
    );
  }

  Widget _enableButton() => FilledButton(
        onPressed: _enableTracking,
        child: const Text('Enable hourly check-ins'),
      );

  Widget _checkinsOnControl() {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 18, color: AppTheme.ink(context)),
            const SizedBox(width: 8),
            Text(
              'Hourly check-ins on',
              style: TextStyle(
                color: AppTheme.ink(context),
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          '8 AM – 10 PM, on the hour',
          style: TextStyle(color: AppTheme.muted, fontSize: 12),
        ),
        TextButton(
          onPressed: _disableTracking,
          style: TextButton.styleFrom(foregroundColor: AppTheme.muted),
          child: const Text('Turn off'),
        ),
      ],
    );
  }

  Widget _appsList() {
    if (!_hasPermission) {
      return const _Empty('Grant usage access to see app breakdown.');
    }
    if (_apps.isEmpty) return const _Empty('No usage recorded yet today.');

    final top = _apps.take(6).toList();
    final max = top.first.time.inSeconds.clamp(1, 1 << 31);

    return Column(
      children: [
        for (final app in top) _AppRow(app: app, maxSeconds: max),
      ],
    );
  }

  Widget _logsList() {
    if (_logs.isEmpty) {
      return const _Empty('No check-ins yet. They appear here once you reply.');
    }
    return Column(
      children: [
        for (final log in _logs)
          Dismissible(
            key: ValueKey(log.id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: const Icon(Icons.delete_outline, color: AppTheme.muted),
            ),
            onDismissed: (_) async {
              if (log.id != null) await _db.deleteLog(log.id!);
              _load();
            },
            child: _LogRow(log: log),
          ),
      ],
    );
  }
}

class _AppRow extends StatelessWidget {
  final AppUsage app;
  final int maxSeconds;
  const _AppRow({required this.app, required this.maxSeconds});

  @override
  Widget build(BuildContext context) {
    final fraction = (app.time.inSeconds / maxSeconds).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  app.label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              Text(
                formatDuration(app.time),
                style: const TextStyle(color: AppTheme.muted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              backgroundColor: AppTheme.surface(context),
              valueColor:
                  AlwaysStoppedAnimation<Color>(AppTheme.ink(context)),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  final ActivityLog log;
  const _LogRow({required this.log});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            child: Text(
              DateFormat('HH:mm').format(log.time),
              style: const TextStyle(
                color: AppTheme.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: Text(log.text, style: const TextStyle(height: 1.3))),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final String text;
  const _Empty(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(text, style: const TextStyle(color: AppTheme.muted)),
      );
}

/// AppBar action: choose System / Light / Dark theme.
class _ThemeMenuButton extends StatelessWidget {
  const _ThemeMenuButton();

  IconData _iconFor(ThemeMode m) {
    switch (m) {
      case ThemeMode.light:
        return Icons.light_mode_outlined;
      case ThemeMode.dark:
        return Icons.dark_mode_outlined;
      case ThemeMode.system:
        return Icons.brightness_auto_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ThemeController.instance;
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: controller.mode,
      builder: (context, current, _) => PopupMenuButton<ThemeMode>(
        tooltip: 'Theme',
        icon: Icon(_iconFor(current)),
        onSelected: controller.setMode,
        itemBuilder: (context) => [
          for (final m in ThemeMode.values)
            PopupMenuItem<ThemeMode>(
              value: m,
              child: Row(
                children: [
                  Icon(_iconFor(m), size: 20, color: AppTheme.ink(context)),
                  const SizedBox(width: 12),
                  Text(switch (m) {
                    ThemeMode.light => 'Light',
                    ThemeMode.dark => 'Dark',
                    ThemeMode.system => 'System',
                  }),
                  const Spacer(),
                  if (m == current)
                    Icon(Icons.check, size: 18, color: AppTheme.ink(context)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _AddLogDialog extends StatefulWidget {
  const _AddLogDialog();

  @override
  State<_AddLogDialog> createState() => _AddLogDialogState();
}

class _AddLogDialogState extends State<_AddLogDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('What are you doing?'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'e.g. Reading email'),
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
