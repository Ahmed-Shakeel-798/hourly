/// A daily to-do item: title, optional notes, done state with a timestamp.
class Task {
  final int? id;
  final String title;
  final String notes;
  final bool done;
  final DateTime createdAt;
  final DateTime? doneAt; // when it was last marked done

  const Task({
    this.id,
    required this.title,
    this.notes = '',
    this.done = false,
    required this.createdAt,
    this.doneAt,
  });

  Task copyWith({
    String? title,
    String? notes,
    bool? done,
    DateTime? doneAt,
    bool clearDoneAt = false,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      done: done ?? this.done,
      createdAt: createdAt,
      doneAt: clearDoneAt ? null : (doneAt ?? this.doneAt),
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'notes': notes,
        'done': done ? 1 : 0,
        'created_at': createdAt.millisecondsSinceEpoch,
        'done_at': doneAt?.millisecondsSinceEpoch,
      };

  factory Task.fromMap(Map<String, Object?> map) => Task(
        id: map['id'] as int?,
        title: (map['title'] as String?) ?? '',
        notes: (map['notes'] as String?) ?? '',
        done: ((map['done'] as int?) ?? 0) == 1,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch((map['created_at'] as int?) ?? 0),
        doneAt: map['done_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(map['done_at'] as int),
      );
}
