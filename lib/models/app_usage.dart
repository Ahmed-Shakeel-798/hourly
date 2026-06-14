/// Aggregated foreground time for a single app over a period.
class AppUsage {
  final String packageName;
  final Duration time;

  const AppUsage({required this.packageName, required this.time});

  /// Best-effort human label derived from the package name, e.g.
  /// `com.instagram.android` -> `Instagram`.
  String get label {
    final parts = packageName.split('.');
    if (parts.isEmpty) return packageName;
    // Skip generic trailing segments like "android" / "app".
    String pick = parts.last;
    if ((pick == 'android' || pick == 'app') && parts.length >= 2) {
      pick = parts[parts.length - 2];
    }
    if (pick.isEmpty) return packageName;
    return pick[0].toUpperCase() + pick.substring(1);
  }
}
