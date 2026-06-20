import 'package:flutter/material.dart';

import 'mute_screen.dart';
import 'screen_time_screen.dart';
import 'today_screen.dart';

/// Bottom-nav shell: Today (tasks + check-ins), Screen time and Mute.
class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int _index = 0;

  static const _screens = [TodayScreen(), ScreenTimeScreen(), MuteScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.check_circle_outline),
            selectedIcon: Icon(Icons.check_circle),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Screen time',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_off_outlined),
            selectedIcon: Icon(Icons.notifications_off),
            label: 'Mute',
          ),
        ],
      ),
    );
  }
}
