import 'package:flutter/material.dart';

import '../theme/activity_appearance.dart';

/// Result of the dialog: a name + chosen appearance.
class ActivityDialogResult {
  final String name;
  final int colorIndex;
  final int iconIndex;
  final double multiplier;

  const ActivityDialogResult({
    required this.name,
    required this.colorIndex,
    required this.iconIndex,
    required this.multiplier,
  });
}

class ActivityDialog extends StatefulWidget {
  final String? initialName;
  final int? initialColorIndex;
  final int? initialIconIndex;
  final double? initialMultiplier;
  final String title;

  const ActivityDialog({
    super.key,
    this.initialName,
    this.initialColorIndex,
    this.initialIconIndex,
    this.initialMultiplier,
    required this.title,
  });

  @override
  State<ActivityDialog> createState() => _ActivityDialogState();
}

class _ActivityDialogState extends State<ActivityDialog> {
  late final TextEditingController _controller;
  late int _colorIndex;
  late int _iconIndex;
  late double _multiplier;
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName ?? '');
    _colorIndex = widget.initialColorIndex ?? 0;
    _iconIndex = widget.initialIconIndex ?? 23;
    _multiplier = widget.initialMultiplier ?? 1.0;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    Navigator.of(context).pop(
      ActivityDialogResult(
        name: text,
        colorIndex: _colorIndex,
        iconIndex: _iconIndex,
        multiplier: _multiplier,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selectedColor = ActivityAppearance.color(_colorIndex);

    return AlertDialog(
      title: Text(widget.title),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      content: SizedBox(
        width: 340,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Preview
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: selectedColor.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        ActivityAppearance.icon(_iconIndex),
                        color: selectedColor,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _controller,
                        builder: (context, value, _) {
                          final name = value.text.trim();
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                name.isEmpty ? 'Preview' : name,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '0h 0m',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Name field
              TextField(
                controller: _controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'e.g. Reading',
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 16),

              // Color picker
              Text('Colour', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (int i = 0; i < ActivityAppearance.colors.length; i++)
                    _ColorSwatch(
                      color: ActivityAppearance.color(i),
                      selected: i == _colorIndex,
                      onTap: () => setState(() => _colorIndex = i),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Icon picker
              Text('Icon', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (int i = 0; i < ActivityAppearance.icons.length; i++)
                    _IconSwatch(
                      icon: ActivityAppearance.icon(i),
                      color: selectedColor,
                      selected: i == _iconIndex,
                      onTap: () => setState(() => _iconIndex = i),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'XP multiplier',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'Higher = more XP per minute. 1.0 is the baseline.',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final m in const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0])
                    _MultiplierChip(
                      multiplier: m,
                      selected: _multiplier == m,
                      accent: selectedColor,
                      onTap: () => setState(() => _multiplier = m),
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

class _ColorSwatch extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _ColorSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: selected
              ? Border.all(
                  color: Theme.of(context).colorScheme.onSurface,
                  width: 2,
                )
              : null,
        ),
        child: selected
            ? const Icon(Icons.check, size: 18, color: Colors.white)
            : null,
      ),
    );
  }
}

class _IconSwatch extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _IconSwatch({
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.25)
              : Theme.of(context).colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: selected ? Border.all(color: color, width: 2) : null,
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 22,
          color: selected
              ? color
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _MultiplierChip extends StatelessWidget {
  final double multiplier;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _MultiplierChip({
    required this.multiplier,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  String get _label => '${multiplier.toString()}x';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.25)
              : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: selected ? Border.all(color: accent, width: 1.5) : null,
        ),
        child: Text(
          _label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? accent : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
