import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/activity_log.dart';
import '../models/task.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../theme.dart';
import '../widgets/day_selector.dart';
import '../widgets/theme_menu_button.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> with WidgetsBindingObserver {
  final _db = DatabaseService.instance;

  DateTime _day = DateTime.now();
  bool _loading = true;
  bool _checkinsEnabled = false;
  List<Task> _tasks = [];
  List<ActivityLog> _logs = [];

  bool get _isToday {
    final now = DateTime.now();
    return _day.year == now.year &&
        _day.month == now.month &&
        _day.day == now.day;
  }

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
    final tasks = await _db.tasksForDay(_day);
    final logs = await _db.logsForDay(_day);
    final enabled = await NotificationService.instance.isCheckinEnabled();
    if (!mounted) return;
    setState(() {
      _tasks = tasks;
      _logs = logs;
      _checkinsEnabled = enabled;
      _loading = false;
    });
  }

  // --- Tasks ---------------------------------------------------------------

  Future<void> _addTask() async {
    final result = await showModalBottomSheet<_TaskEdit>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _TaskSheet(),
    );
    if (result == null || result.title.trim().isEmpty) return;
    await _db.insertTask(Task(
      title: result.title.trim(),
      notes: result.notes.trim(),
      createdAt: DateTime.now(),
    ));
    _load();
  }

  Future<void> _editTask(Task task) async {
    final result = await showModalBottomSheet<_TaskEdit>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TaskSheet(initial: task),
    );
    if (result == null) return;
    if (result.delete) {
      if (task.id != null) await _db.deleteTask(task.id!);
    } else if (result.title.trim().isNotEmpty) {
      await _db.updateTask(task.copyWith(
        title: result.title.trim(),
        notes: result.notes.trim(),
      ));
    }
    _load();
  }

  Future<void> _toggleTask(Task task) async {
    final nowDone = !task.done;
    await _db.updateTask(task.copyWith(
      done: nowDone,
      doneAt: nowDone ? DateTime.now() : null,
      clearDoneAt: !nowDone,
    ));
    _load();
  }

  // --- Check-ins -----------------------------------------------------------

  Future<void> _enableCheckins() async {
    await NotificationService.instance.enableCheckins();
    if (!mounted) return;
    setState(() => _checkinsEnabled = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Hourly check-ins enabled.')),
    );
  }

  Future<void> _disableCheckins() async {
    await NotificationService.instance.disableCheckins();
    if (!mounted) return;
    setState(() => _checkinsEnabled = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Hourly check-ins turned off.')),
    );
  }

  Future<void> _addManualLog() async {
    final result = await showModalBottomSheet<_TaskEdit>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _TaskSheet(
        hint: 'e.g. Reading email',
        titleLabel: 'What are you doing?',
        notesEnabled: false,
      ),
    );
    if (result == null || result.title.trim().isEmpty) return;
    await _db.insertLog(ActivityLog(
      time: DateTime.now(),
      text: result.title.trim(),
      source: 'manual',
    ));
    _load();
  }

  // --- Build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Today'),
        actions: const [ThemeMenuButton()],
      ),
      floatingActionButton: _isToday
          ? FloatingActionButton(
              backgroundColor: AppTheme.ink(context),
              foregroundColor: AppTheme.onInk(context),
              elevation: 0,
              onPressed: _addTask,
              child: const Icon(Icons.add),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
                children: [
                  DaySelector(
                    day: _day,
                    onChanged: (d) {
                      _day = d;
                      _load();
                    },
                  ),
                  const SizedBox(height: 16),
                  _sectionLabel('Tasks'),
                  const SizedBox(height: 8),
                  _tasksList(),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      _sectionLabel('Check-ins'),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Add a note',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.add,
                            size: 20, color: AppTheme.muted),
                        onPressed: _addManualLog,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (_isToday) _checkinControl(),
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

  Widget _tasksList() {
    if (_tasks.isEmpty) {
      return _Empty(_isToday
          ? 'No tasks yet. Tap + to add one.'
          : 'No tasks on this day.');
    }
    return Column(
      children: [
        for (final task in _tasks)
          Dismissible(
            key: ValueKey('task_${task.id}'),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: const Icon(Icons.delete_outline, color: AppTheme.muted),
            ),
            onDismissed: (_) async {
              if (task.id != null) await _db.deleteTask(task.id!);
              _load();
            },
            child: _TaskRow(
              task: task,
              onToggle: () => _toggleTask(task),
              onTap: () => _editTask(task),
            ),
          ),
      ],
    );
  }

  Widget _checkinControl() {
    if (!_checkinsEnabled) {
      return Align(
        alignment: Alignment.centerLeft,
        child: FilledButton(
          onPressed: _enableCheckins,
          child: const Text('Enable hourly check-ins'),
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 16, color: AppTheme.ink(context)),
          const SizedBox(width: 6),
          const Expanded(
            child: Text('On · 8 AM – 10 PM, on the hour',
                style: TextStyle(color: AppTheme.muted, fontSize: 12)),
          ),
          TextButton(
            onPressed: () => NotificationService.instance.sendTestCheckin(),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.muted,
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('Test'),
          ),
          TextButton(
            onPressed: _disableCheckins,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.muted,
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('Off'),
          ),
        ],
      ),
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
            key: ValueKey('log_${log.id}'),
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

class _TaskRow extends StatelessWidget {
  final Task task;
  final VoidCallback onToggle;
  final VoidCallback onTap;
  const _TaskRow(
      {required this.task, required this.onToggle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: onToggle,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(right: 12, top: 1),
                child: Icon(
                  task.done
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  size: 22,
                  color: task.done ? ink : AppTheme.muted,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.3,
                      color: task.done ? AppTheme.muted : ink,
                      decoration:
                          task.done ? TextDecoration.lineThrough : null,
                      decorationColor: AppTheme.muted,
                    ),
                  ),
                  if (task.notes.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      task.notes,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppTheme.muted, fontSize: 13, height: 1.3),
                    ),
                  ],
                  if (task.done && task.doneAt != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Done ${DateFormat('HH:mm').format(task.doneAt!)}',
                      style: const TextStyle(
                          color: AppTheme.muted, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
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
                  color: AppTheme.muted, fontWeight: FontWeight.w600),
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

/// Result of the add/edit sheet.
class _TaskEdit {
  final String title;
  final String notes;
  final bool delete;
  const _TaskEdit(this.title, this.notes, {this.delete = false});
}

/// Bottom sheet for adding/editing a task (also reused for manual check-ins).
class _TaskSheet extends StatefulWidget {
  final Task? initial;
  final String titleLabel;
  final String hint;
  final bool notesEnabled;

  const _TaskSheet({
    this.initial,
    this.titleLabel = 'Task',
    this.hint = 'What do you need to do?',
    this.notesEnabled = true,
  });

  @override
  State<_TaskSheet> createState() => _TaskSheetState();
}

class _TaskSheetState extends State<_TaskSheet> {
  late final TextEditingController _title =
      TextEditingController(text: widget.initial?.title ?? '');
  late final TextEditingController _notes =
      TextEditingController(text: widget.initial?.notes ?? '');

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initial != null;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.muted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(widget.titleLabel,
                style: const TextStyle(
                    fontSize: 12,
                    letterSpacing: 1,
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _title,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: widget.hint,
                border: InputBorder.none,
              ),
              style: const TextStyle(fontSize: 18),
              onSubmitted: (_) {
                if (!widget.notesEnabled) _save();
              },
            ),
            if (widget.notesEnabled) ...[
              const Divider(),
              TextField(
                controller: _notes,
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Notes (optional)',
                  border: InputBorder.none,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                if (editing)
                  TextButton.icon(
                    onPressed: () => Navigator.of(context)
                        .pop(const _TaskEdit('', '', delete: true)),
                    style:
                        TextButton.styleFrom(foregroundColor: AppTheme.muted),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Delete'),
                  ),
                const Spacer(),
                FilledButton(
                  onPressed: _save,
                  child: Text(editing ? 'Save' : 'Add'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _save() =>
      Navigator.of(context).pop(_TaskEdit(_title.text, _notes.text));
}
