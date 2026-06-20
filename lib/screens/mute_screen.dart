import 'package:flutter/material.dart';

import '../models/installed_app.dart';
import '../services/installed_apps_service.dart';
import '../theme.dart';
import '../widgets/theme_menu_button.dart';

/// Search installed apps and jump to an app's system notification settings,
/// where the user can switch its notifications off.
class MuteScreen extends StatefulWidget {
  const MuteScreen({super.key});

  @override
  State<MuteScreen> createState() => _MuteScreenState();
}

class _MuteScreenState extends State<MuteScreen> {
  final _service = InstalledAppsService();
  final _searchController = TextEditingController();

  bool _loading = true;
  List<InstalledApp> _all = [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    List<InstalledApp> apps;
    try {
      apps = await _service.getInstalledApps();
    } catch (_) {
      apps = const [];
    }
    if (!mounted) return;
    setState(() {
      _all = apps;
      _loading = false;
    });
  }

  List<InstalledApp> get _filtered {
    if (_query.isEmpty) return _all;
    final q = _query.toLowerCase();
    return _all
        .where((a) =>
            a.name.toLowerCase().contains(q) ||
            a.package.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _openSettings(InstalledApp app) async {
    final ok = await _service.openNotificationSettings(app.package);
    if (!mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Couldn't open settings for ${app.name}")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mute apps'),
        actions: const [ThemeMenuButton()],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: _searchField(),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              'Tap an app to open its notification settings, where you can turn '
              'notifications off.',
              style: TextStyle(color: AppTheme.muted, fontSize: 13, height: 1.4),
            ),
          ),
          Expanded(child: _list()),
        ],
      ),
    );
  }

  Widget _searchField() {
    return TextField(
      controller: _searchController,
      onChanged: (v) => setState(() => _query = v),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search apps',
        prefixIcon: const Icon(Icons.search, size: 22),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _query = '');
                },
              ),
        filled: true,
        fillColor: AppTheme.surface(context),
        contentPadding: const EdgeInsets.symmetric(vertical: 0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _list() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final apps = _filtered;
    if (apps.isEmpty) {
      return Center(
        child: Text(
          _all.isEmpty ? 'No apps found.' : 'No apps match "$_query".',
          style: const TextStyle(color: AppTheme.muted),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: apps.length,
        itemBuilder: (context, i) => _appTile(apps[i]),
      ),
    );
  }

  Widget _appTile(InstalledApp app) {
    return ListTile(
      onTap: () => _openSettings(app),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: _appIcon(app),
      title: Text(
        app.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        app.package,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: AppTheme.muted, fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppTheme.muted),
    );
  }

  Widget _appIcon(InstalledApp app) {
    if (app.icon != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.memory(
          app.icon!,
          width: 40,
          height: 40,
          gaplessPlayback: true,
        ),
      );
    }
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        app.name.isNotEmpty ? app.name[0].toUpperCase() : '?',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: AppTheme.ink(context),
        ),
      ),
    );
  }
}
