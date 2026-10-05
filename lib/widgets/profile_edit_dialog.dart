import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../profile_store.dart';
import '../theme/activity_appearance.dart';

class ProfileEditResult {
  final String name;
  final int avatarColor;

  /// If the user picked a new photo, this is the source path returned by
  /// the picker. The caller is responsible for copying it into the app
  /// folder via ProfileStore.saveAvatarImage().
  final String? newAvatarSourcePath;

  /// Set to true if the user tapped "Use colour" (remove any photo).
  final bool removeAvatarImage;

  const ProfileEditResult({
    required this.name,
    required this.avatarColor,
    this.newAvatarSourcePath,
    this.removeAvatarImage = false,
  });
}

class ProfileEditDialog extends StatefulWidget {
  final String initialName;
  final int initialAvatarColor;
  final String? initialAvatarImagePath;

  const ProfileEditDialog({
    super.key,
    required this.initialName,
    required this.initialAvatarColor,
    this.initialAvatarImagePath,
  });

  @override
  State<ProfileEditDialog> createState() => _ProfileEditDialogState();
}

class _ProfileEditDialogState extends State<ProfileEditDialog> {
  late final TextEditingController _controller;
  late int _colorIndex;

  /// If non-null, the user picked a new photo (local file path).
  String? _pendingImagePath;

  /// If true, the user tapped "Use colour" — remove any existing photo.
  bool _removeImage = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
    _colorIndex = widget.initialAvatarColor;
    _pendingImagePath = widget.initialAvatarImagePath;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() {
      _pendingImagePath = picked.path;
      _removeImage = false;
    });
  }

  void _useColour() {
    setState(() {
      _pendingImagePath = null;
      _removeImage = true;
    });
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    Navigator.of(context).pop(
      ProfileEditResult(
        name: text,
        avatarColor: _colorIndex,
        // Only pass newAvatarSourcePath if the user actually picked a NEW
        // photo during this dialog session. If _pendingImagePath equals
        // widget.initialAvatarImagePath, nothing changed.
        newAvatarSourcePath:
            (_pendingImagePath != null &&
                _pendingImagePath != widget.initialAvatarImagePath)
            ? _pendingImagePath
            : null,
        removeAvatarImage: _removeImage,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = ActivityAppearance.color(_colorIndex);
    final hasPhoto = _pendingImagePath != null && !_removeImage;

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
                    return _AvatarPreview(
                      name: name,
                      color: color,
                      imagePath: hasPhoto ? _pendingImagePath : null,
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Photo / colour buttons
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: const Text('Choose photo'),
                    onPressed: _pickPhoto,
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.palette_outlined, size: 18),
                    label: const Text('Use colour'),
                    onPressed: _useColour,
                  ),
                ],
              ),
              const SizedBox(height: 8),

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
              const SizedBox(height: 4),
              Text(
                hasPhoto
                    ? 'Only used if you remove the photo.'
                    : 'Used for your avatar circle.',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
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

/// Big circle showing either a photo or the initial in the colour.
class _AvatarPreview extends StatelessWidget {
  final String name;
  final Color color;
  final String? imagePath;

  const _AvatarPreview({
    required this.name,
    required this.color,
    this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();

    if (imagePath != null) {
      return ClipOval(
        child: Image.file(
          File(imagePath!),
          width: 96,
          height: 96,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => _initialCircle(initial),
        ),
      );
    }
    return _initialCircle(initial);
  }

  Widget _initialCircle(String initial) {
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
  }
}
