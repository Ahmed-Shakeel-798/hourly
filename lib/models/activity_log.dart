/// A single "what are you doing?" check-in (or a manually added note).
class ActivityLog {
  final int? id;
  final DateTime time;
  final String text;
  final String source; // 'checkin' (from notification) or 'manual'

  const ActivityLog({
    this.id,
    required this.time,
    required this.text,
    this.source = 'checkin',
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'ts': time.millisecondsSinceEpoch,
        'text': text,
        'source': source,
      };

  factory ActivityLog.fromMap(Map<String, Object?> map) => ActivityLog(
        id: map['id'] as int?,
        time: DateTime.fromMillisecondsSinceEpoch(map['ts'] as int),
        text: (map['text'] as String?) ?? '',
        source: (map['source'] as String?) ?? 'checkin',
      );
}
