import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Simple persistent store for the user's profile.
/// Backed by shared_preferences, plus a file in the app's documents folder
/// for the avatar image (if one has been chosen).
class ProfileStore {
  static const _keyName = 'profile_name';
  static const _keyAvatarColor = 'profile_avatar_color';
  static const _keyAvatarImage = 'profile_avatar_image';

  static const String defaultName = 'You';
  static const int defaultAvatarColor = 0;

  /// Load the profile. If an avatar image path is stored but the file
  /// no longer exists, treat it as absent (fall back to colour+initial).
  static Future<({String name, int avatarColor, String? avatarImagePath})>
  load() async {
    final prefs = await SharedPreferences.getInstance();
    final imagePath = prefs.getString(_keyAvatarImage);

    String? verifiedPath;
    if (imagePath != null) {
      final file = File(imagePath);
      if (await file.exists()) {
        verifiedPath = imagePath;
      }
    }

    return (
      name: prefs.getString(_keyName) ?? defaultName,
      avatarColor: prefs.getInt(_keyAvatarColor) ?? defaultAvatarColor,
      avatarImagePath: verifiedPath,
    );
  }

  static Future<void> saveName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyName, name.trim());
  }

  static Future<void> saveAvatarColor(int colorIndex) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyAvatarColor, colorIndex);
  }

  /// Copy [sourcePath] into the app's documents folder as the avatar,
  /// and remember the new path. Overwrites any existing avatar file.
  /// Returns the new file path.
  static Future<String> saveAvatarImage(String sourcePath) async {
    final docsDir = await getApplicationDocumentsDirectory();

    // Delete any existing avatar files so we don't accumulate them.
    final existing = Directory(docsDir.path);
    if (await existing.exists()) {
      await for (final entity in existing.list()) {
        if (entity is File && entity.path.contains('profile_avatar_')) {
          try {
            await entity.delete();
          } catch (_) {
            // Ignore delete errors — probably in use, we'll just leave it.
          }
        }
      }
    }

    // Unique filename so Flutter's image cache can't serve a stale image.
    final filename =
        'profile_avatar_${DateTime.now().millisecondsSinceEpoch}.png';
    final destPath = '${docsDir.path}/$filename';
    final destFile = File(destPath);

    final bytes = await File(sourcePath).readAsBytes();
    await destFile.writeAsBytes(bytes, flush: true);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAvatarImage, destPath);

    return destPath;
  }

  /// Remove the avatar image (revert to colour+initial).
  static Future<void> clearAvatarImage() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_keyAvatarImage);
    if (path != null) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
    await prefs.remove(_keyAvatarImage);
  }

  /// Save everything in one go.
  static Future<void> save({
    required String name,
    required int avatarColor,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyName, name.trim());
    await prefs.setInt(_keyAvatarColor, avatarColor);
  }
}
