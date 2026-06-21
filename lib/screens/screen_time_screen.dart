import 'package:flutter/material.dart';

import '../models/app_usage.dart';
import '../services/usage_service.dart';
import '../services/widget_service.dart';
import '../theme.dart';
import '../utils/formatting.dart';
import '../widgets/day_selector.dart';
import '../widgets/theme_menu_button.dart';

class ScreenTimeScreen extends StatefulWidget {
  const ScreenTimeScreen({super.key});

  @override
  State<ScreenTimeScreen> createState() => _ScreenTimeScreenState();
}

class _ScreenTimeScreenState extends State<ScreenTimeScreen>
    with WidgetsBindingObserver {
  final _usage = UsageService();

  DateTime _day = DateTime.now();
  bool _loading = true;
  bool _hasPermission = false;
  Duration _total = Duration.zero;
  List<AppUsage> _apps = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
    // Keep the home-screen mood widget in sync as the user enters/leaves the app.
    if (state == AppLifecycleState.resumed ||
        state == AppLifecycleState.paused) {
      WidgetService.refresh();
    }
  }

  Future<void> _load() async {
    final granted = await _usage.hasPermission();
    final apps = granted ? await _usage.usageForDay(_day) : <AppUsage>[];
    final total = apps.fold<Duration>(Duration.zero, (s, a) => s + a.time);
    if (!mounted) return;
    setState(() {
      _hasPermission = granted;
      _apps = apps;
      _total = total;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Screen time'),
        actions: const [ThemeMenuButton()],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                children: [
                  DaySelector(
                    day: _day,
                    onChanged: (d) {
                      _day = d;
                      _load();
                    },
                  ),
                  const SizedBox(height: 16),
                  if (!_hasPermission) _permissionCard(),
                  _totalCard(),
                  const SizedBox(height: 28),
                  _sectionLabel('App breakdown'),
                  const SizedBox(height: 10),
                  _breakdown(),
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
          const Text('Usage access needed',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 6),
          const Text(
            'Grant "Usage access" so the app can read your screen time.',
            style: TextStyle(color: AppTheme.muted, height: 1.4),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: () => _usage.requestPermission(),
            child: const Text('Grant access'),
          ),
        ],
      ),
    );
  }

  Widget _totalCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 24),
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
                fontSize: 48, fontWeight: FontWeight.w700, height: 1.0),
          ),
        ],
      ),
    );
  }

  Widget _breakdown() {
    if (!_hasPermission) {
      return const Text('Grant usage access to see your app breakdown.',
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
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(app.label,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w500)),
                    ),
                    Text(formatDuration(app.time),
                        style: const TextStyle(color: AppTheme.muted)),
                  ],
                ),
                const SizedBox(height: 8),
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
}
