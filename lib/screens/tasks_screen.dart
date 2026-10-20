import 'package:flutter/material.dart';

import '../database.dart';
import '../widgets/task_dialog.dart';
import '../xp.dart'; // For formatting durations later if needed
import '../widgets/xp_toast.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  List<Task> _tasks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() => _loading = true);
    final tasks = await AppDatabase.getAllTasks();
    if (!mounted) return;
    setState(() {
      _tasks = tasks;
      _loading = false;
    });
  }

  Future<void> _addTask() async {
    final newTask = await showDialog<Task>(
      context: context,
      builder: (_) => const TaskDialog(),
    );
    if (newTask == null) return;
    await AppDatabase.insertTask(newTask);
    await _loadTasks();
  }

  Future<void> _editTask(Task task) async {
    final updatedTask = await showDialog<Task>(
      context: context,
      builder: (_) => TaskDialog(initialTask: task),
    );
    if (updatedTask == null) return;
    await AppDatabase.updateTask(updatedTask);
    await _loadTasks();
  }

  Future<void> _toggleComplete(Task task) async {
    if (task.isCompleted) {
      await AppDatabase.uncompleteTask(task.id!);
    } else {
      await AppDatabase.completeTask(task.id!);

      // Show the toast if the task was worth XP!
      if (task.xpReward > 0 && mounted) {
        showXpToast(
          context,
          amount: task.xpReward,
          // Use the theme's primary color, or a specific color for tasks
          color: Theme.of(context).colorScheme.primary,
        );
      }
    }
    await _loadTasks();
  }

  Future<void> _deleteTask(Task task) async {
    // Show a confirm dialog before deleting
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text('Are you sure you want to delete "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await AppDatabase.deleteTask(task.id!);
    await _loadTasks();
  }

  // ── Urgency Sorting Logic ───────────────────────────────────────────────

  String _getSectionFor(Task task) {
    if (task.isCompleted) return 'Completed';
    if (task.dueAt == null) return 'No Date';

    final now = DateTime.now();
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final weekEnd = todayEnd.add(const Duration(days: 7));

    if (task.dueAt!.isBefore(now)) return 'Overdue';
    if (task.dueAt!.isBefore(todayEnd)) return 'Today';
    if (task.dueAt!.isBefore(weekEnd)) return 'This Week';
    return 'Later';
  }

  String _formatDueDate(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final taskDay = DateTime(date.year, date.month, date.day);

    String dayStr;
    if (taskDay == today) {
      dayStr = 'Today';
    } else if (taskDay == tomorrow) {
      dayStr = 'Tomorrow';
    } else {
      dayStr = '${date.day}/${date.month}';
    }

    // Only show time if it's not the default 23:59 end-of-day
    if (date.hour != 23 || date.minute != 59) {
      final timeStr =
          '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      return '$dayStr $timeStr';
    }
    return dayStr;
  }

  @override
  Widget build(BuildContext context) {
    // 1. Group tasks by their section
    final sections = <String, List<Task>>{
      'Overdue': [],
      'Today': [],
      'This Week': [],
      'Later': [],
      'No Date': [],
      'Completed': [],
    };

    for (final task in _tasks) {
      sections[_getSectionFor(task)]!.add(task);
    }

    // 2. Build a flat list of widgets (headers + cards)
    final List<Widget> listItems = [];

    for (final sectionName in [
      'Overdue',
      'Today',
      'This Week',
      'Later',
      'No Date',
      'Completed',
    ]) {
      final sectionTasks = sections[sectionName]!;
      if (sectionTasks.isEmpty) continue;

      // Section Header
      listItems.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            sectionName,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: sectionName == 'Overdue'
                  ? Colors.red
                  : Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      );

      // Section Tasks
      for (final task in sectionTasks) {
        final isCompleted = task.isCompleted;
        final scheme = Theme.of(context).colorScheme;

        listItems.add(
          Dismissible(
            key: ValueKey(task.id),
            background: Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 20),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.check, color: Colors.white),
            ),
            secondaryBackground: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            onDismissed: (direction) {
              // 1. Immediately remove the task from the local UI list
              // so Flutter doesn't throw an error.
              setState(() {
                _tasks.remove(task);
              });

              // 2. Then do the database work in the background.
              if (direction == DismissDirection.startToEnd) {
                _toggleComplete(task);
              } else {
                _deleteTask(task);
              }
            },
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                onTap: () => _toggleComplete(task),
                leading: Icon(
                  isCompleted
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: isCompleted ? Colors.green : scheme.onSurfaceVariant,
                ),
                title: Text(
                  task.title,
                  style: TextStyle(
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                    color: isCompleted ? scheme.onSurfaceVariant : null,
                  ),
                ),
                subtitle: task.notes != null
                    ? Text(
                        task.notes!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: isCompleted
                              ? scheme.onSurfaceVariant.withValues(alpha: 0.5)
                              : null,
                        ),
                      )
                    : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (task.dueAt != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: sectionName == 'Overdue'
                              ? Colors.red.withValues(alpha: 0.2)
                              : scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _formatDueDate(task.dueAt),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: sectionName == 'Overdue'
                                ? Colors.red
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    if (task.xpReward > 0) ...[
                      const SizedBox(width: 8),
                      Text(
                        '+${task.xpReward} XP',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: scheme.primary.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 18),
                      onPressed: () => _editTask(task),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New task',
            onPressed: _addTask,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _tasks.isEmpty
          ? _EmptyState()
          : ListView(
              padding: const EdgeInsets.only(
                bottom: 100,
              ), // Padding for the floating pill
              children: listItems,
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 64,
            color: scheme.primary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'No tasks yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap + to add your first one',
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
