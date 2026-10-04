import 'package:flutter/material.dart';

import '../theme/activity_appearance.dart';

class ProfileEditResult {
  final String name;
  final int avatarColor;
  const ProfileEditResult({required this.name, required this.avatarColor});
}

class ProfileEditDialog extends StatefulWidget {
  final String initialName;
  final int initialAvatarColor;

  const ProfileEditDialog({
    super.key,
    required this.initialName,
    required this.initialAvatarColor,
  });

  @override
  State<ProfileEditDialog> createState() => _ProfileEditDialogState();
}

class _ProfileEditDialogState extends State<ProfileEditDialog> {
  late final TextEditingController _controller;
  late int _colorIndex;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
    _colorIndex = widget.initialAvatarColor;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    Navigator.of(context)
        .pop(ProfileEditResult(name: text, avatarColor: _colorIndex));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = ActivityAppearance.color(_colorIndex);

    return AlertDialog(
      title: const Text('Edit profile'),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      content: SizedBox(
        width: 340,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Live preview
              Center(
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _controller,
                  builder: (context, value, _) {
                    final name = value.text.trim();
                    final initial = name.isEmpty ? '?' : name[0].toUpperCase();
                    return Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initial,
                        style: TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),

              TextField(
                controller: _controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Display name'),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 16),

              Text(
                'Avatar colour',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (int i = 0; i < ActivityAppearance.colors.length; i++)
                    GestureDetector(
                      onTap: () => setState(() => _colorIndex = i),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: ActivityAppearance.color(i),
                          shape: BoxShape.circle,
                          border: i == _colorIndex
                              ? Border.all(color: scheme.onSurface, width: 2)
                              : null,
                        ),
                        child: i == _colorIndex
                            ? const Icon(
                                Icons.check,
                                size: 18,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ),
                ],
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
