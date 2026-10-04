import 'package:shared_preferences/shared_preferences.dart';

/// Simple persistent store for the user's profile (name + avatar colour).
/// Backed by shared_preferences — one row of settings, not queryable data.
class ProfileStore {
  static const _keyName = 'profile_name';
  static const _keyAvatarColor = 'profile_avatar_color';

  /// Default profile name shown on first launch.
  static const String defaultName = 'You';

  /// Default avatar colour index (0 = indigo, from ActivityAppearance).
  static const int defaultAvatarColor = 0;

  static Future<({String name, int avatarColor})> load() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      name: prefs.getString(_keyName) ?? defaultName,
      avatarColor: prefs.getInt(_keyAvatarColor) ?? defaultAvatarColor,
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

  static Future<void> save({
    required String name,
    required int avatarColor,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyName, name.trim());
    await prefs.setInt(_keyAvatarColor, avatarColor);
  }
}
