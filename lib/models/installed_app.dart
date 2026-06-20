import 'dart:typed_data';

/// A user-facing app installed on the device.
class InstalledApp {
  final String package;
  final String name;
  final bool system;

  /// Small PNG icon bytes, or null if it couldn't be loaded.
  final Uint8List? icon;

  const InstalledApp({
    required this.package,
    required this.name,
    required this.system,
    this.icon,
  });
}
