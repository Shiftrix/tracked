import 'package:flutter/material.dart';

/// A dialog for creating or renaming an activity.
/// Returns the entered string via Navigator.pop, or null if cancelled.
class ActivityNameDialog extends StatefulWidget {
  /// Prefilled name (for edit mode). Leave null for add mode.
  final String? initialName;

  /// Title shown at the top. e.g. "New activity" or "Rename activity".
  final String title;

  const ActivityNameDialog({super.key, this.initialName, required this.title});

  @override
  State<ActivityNameDialog> createState() => _ActivityNameDialogState();
}

class _ActivityNameDialogState extends State<ActivityNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Name',
          hintText: 'e.g. Reading',
        ),
        onSubmitted: (_) => _submit(),
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
