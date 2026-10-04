import 'package:flutter/material.dart';

/// Fixed palette of 12 colors that look good in dark mode.
/// Index into this list is what we store in the DB.
class ActivityAppearance {
  static const List<Color> colors = [
    Color(0xFF6366F1), // 0 Indigo (default)
    Color(0xFFA855F7), // 1 Purple
    Color(0xFFEC4899), // 2 Pink
    Color(0xFFEF4444), // 3 Red
    Color(0xFFF97316), // 4 Orange
    Color(0xFFF59E0B), // 5 Amber
    Color(0xFF84CC16), // 6 Lime
    Color(0xFF22C55E), // 7 Green
    Color(0xFF14B8A6), // 8 Teal
    Color(0xFF06B6D4), // 9 Cyan
    Color(0xFF3B82F6), // 10 Blue
    Color(0xFF64748B), // 11 Slate
  ];

  static const List<IconData> icons = [
    Icons.fitness_center, // 0
    Icons.sports_esports, // 1
    Icons.videocam, // 2
    Icons.music_note, // 3
    Icons.desktop_windows, // 4
    Icons.menu_book, // 5
    Icons.edit, // 6
    Icons.restaurant, // 7
    Icons.directions_run, // 8
    Icons.code, // 9
    Icons.palette, // 10
    Icons.book, // 11
    Icons.self_improvement, // 12
    Icons.headphones, // 13
    Icons.photo_camera, // 14
    Icons.directions_bike, // 15
    Icons.psychology, // 16
    Icons.movie, // 17
    Icons.create, // 18
    Icons.build, // 19
    Icons.eco, // 20
    Icons.directions_walk, // 21
    Icons.bedtime, // 22
    Icons.star, // 23
  ];

  /// Safe lookup — falls back to index 0 if out of range.
  static Color color(int index) => colors[index.clamp(0, colors.length - 1)];

  static IconData icon(int index) => icons[index.clamp(0, icons.length - 1)];

  /// Best-effort default icon for a given activity name.
  /// Used when creating a new activity so the icon isn't always star.
  static int suggestIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('gym') || n.contains('workout') || n.contains('exercise')) {
      return 0;
    }
    if (n.contains('gam')) return 1;
    if (n.contains('edit')) return 2;
    if (n.contains('music')) return 3;
    if (n.contains('game dev') || n.contains('gamedev')) return 4;
    if (n.contains('revis') || n.contains('study')) return 5;
    if (n.contains('draw') || n.contains('art')) return 10;
    if (n.contains('cook')) return 7;
    if (n.contains('run')) return 8;
    if (n.contains('cod') || n.contains('program')) return 9;
    if (n.contains('read')) return 11;
    if (n.contains('meditat') || n.contains('yoga')) return 12;
    if (n.contains('listen') || n.contains('podcast')) return 13;
    if (n.contains('photo')) return 14;
    if (n.contains('cycl') || n.contains('bike')) return 15;
    if (n.contains('walk')) return 21;
    if (n.contains('sleep')) return 22;
    return 23;
  }
}
