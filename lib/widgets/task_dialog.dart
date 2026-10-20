import 'package:flutter/material.dart';

import '../database.dart';

class TaskDialog extends StatefulWidget {
  final Task? initialTask;

  const TaskDialog({super.key, this.initialTask});

  @override
  State<TaskDialog> createState() => _TaskDialogState();
}

class _TaskDialogState extends State<TaskDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late final TextEditingController _xpController;

  DateTime? _dueAt;

  @override
  void initState() {
    super.initState();
    final task = widget.initialTask;
    _titleController = TextEditingController(text: task?.title ?? '');
    _notesController = TextEditingController(text: task?.notes ?? '');
    _xpController = TextEditingController(
      text: (task?.xpReward ?? 20).toString(),
    );
    _dueAt = task?.dueAt;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _xpController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();

    // Default to today if nothing is set, else use current _dueAt
    final initialDate = _dueAt ?? now;

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (date == null) return;

    if (!mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: _dueAt != null
          ? TimeOfDay.fromDateTime(_dueAt!)
          : const TimeOfDay(hour: 23, minute: 59), // Default to end of day
    );
    if (time == null) return;

    setState(() {
      _dueAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final xp = int.tryParse(_xpController.text.trim()) ?? 20;
    final notes = _notesController.text.trim();

    final task = Task(
      id: widget.initialTask?.id,
      title: title,
      notes: notes.isEmpty ? null : notes,
      dueAt: _dueAt,
      xpReward: xp,
      completedAt: widget.initialTask?.completedAt,
      createdAt: widget.initialTask?.createdAt ?? DateTime.now(),
    );

    Navigator.of(context).pop(task);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(widget.initialTask == null ? 'New task' : 'Edit task'),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      content: SizedBox(
        width: 340,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _titleController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Task name',
                  hintText: 'e.g. Edit YouTube video',
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                ),
              ),
              const SizedBox(height: 16),

              // Due Date & Time
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(
                        _dueAt == null
                            ? 'Set due date'
                            : '${_dueAt!.day}/${_dueAt!.month} at ${_dueAt!.hour.toString().padLeft(2, '0')}:${_dueAt!.minute.toString().padLeft(2, '0')}',
                      ),
                      onPressed: _pickDueDate,
                    ),
                  ),
                  if (_dueAt != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _dueAt = null),
                      tooltip: 'Clear date',
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),

              // XP Reward
              TextField(
                controller: _xpController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'XP Reward',
                  prefixIcon: Icon(Icons.auto_awesome, size: 20),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}
