import 'package:flutter/material.dart';

import '../services/theme_controller.dart';
import '../theme.dart';

/// AppBar action: choose System / Light / Dark theme.
class ThemeMenuButton extends StatelessWidget {
  const ThemeMenuButton({super.key});

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

  String _labelFor(ThemeMode m) {
    switch (m) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
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
                  Text(_labelFor(m)),
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
