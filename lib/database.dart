import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// A single row in the `activities` table.
/// e.g. "Gym", "Editing", "Music"
class Activity {
  final int? id;
  final String name;
  final int colorIndex;
  final int iconIndex;

  Activity({
    this.id,
    required this.name,
    this.colorIndex = 0,
    this.iconIndex = 23,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'colorIndex': colorIndex,
    'iconIndex': iconIndex,
  };

  factory Activity.fromMap(Map<String, dynamic> map) => Activity(
    id: map['id'] as int?,
    name: map['name'] as String,
    colorIndex: (map['colorIndex'] as int?) ?? 0,
    iconIndex: (map['iconIndex'] as int?) ?? 23,
  );
}

/// A single row in the `sessions` table.
/// One row = one completed (or in-progress) stretch of time.
class Session {
  final int? id;
  final int activityId;
  final DateTime startedAt;
  final DateTime? endedAt; // null means "still running"

  Session({
    this.id,
    required this.activityId,
    required this.startedAt,
    this.endedAt,
  });

  /// Duration of this session. If it's still running, returns null.
  Duration? get duration => endedAt?.difference(startedAt);

  Map<String, dynamic> toMap() => {
    'id': id,
    'activityId': activityId,
    'startedAt': startedAt.millisecondsSinceEpoch,
    'endedAt': endedAt?.millisecondsSinceEpoch,
  };

  factory Session.fromMap(Map<String, dynamic> map) => Session(
    id: map['id'] as int?,
    activityId: map['activityId'] as int,
    startedAt: DateTime.fromMillisecondsSinceEpoch(map['startedAt'] as int),
    endedAt: map['endedAt'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(map['endedAt'] as int),
  );
}

/// Handles opening the database and exposing it to the rest of the app.
class AppDatabase {
  static Database? _db;

  /// Get the database, opening it on first call.
  static Future<Database> get instance async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  static Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'life_tracker.db');

    return openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        // Activities: one row per thing you track.
        await db.execute('''
          CREATE TABLE activities (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            colorIndex INTEGER NOT NULL DEFAULT 0,
            iconIndex INTEGER NOT NULL DEFAULT 23
          )
        ''');

        // Sessions: one row per start/stop cycle.
        // startedAt / endedAt are stored as milliseconds since 1970 (int),
        // which makes date math and sorting trivial.
        await db.execute('''
          CREATE TABLE sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            activityId INTEGER NOT NULL,
            startedAt INTEGER NOT NULL,
            endedAt INTEGER,
            FOREIGN KEY (activityId) REFERENCES activities (id)
          )
        ''');

        // One example activity for fresh installs.
        await db.insert('activities', {
          'name': 'Example',
          'colorIndex': 0,
          'iconIndex': 23,
        });
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // v1 → v2: added colorIndex and iconIndex columns.
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE activities ADD COLUMN colorIndex INTEGER NOT NULL DEFAULT 0',
          );
          await db.execute(
            'ALTER TABLE activities ADD COLUMN iconIndex INTEGER NOT NULL DEFAULT 23',
          );
        }
      },
    );
  }

  /// Insert a new, still-running session. Returns the new session's id.
  static Future<int> startSession(int activityId) async {
    final db = await instance;
    return db.insert('sessions', {
      'activityId': activityId,
      'startedAt': DateTime.now().millisecondsSinceEpoch,
      'endedAt': null,
    });
  }

  /// Mark a session as finished by writing its end time.
  static Future<void> stopSession(int sessionId) async {
    final db = await instance;
    await db.update(
      'sessions',
      {'endedAt': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  /// Fetch all activities (for the list screen later).
  static Future<List<Activity>> getActivities() async {
    final db = await instance;
    final rows = await db.query('activities', orderBy: 'name ASC');
    return rows.map((r) => Activity.fromMap(r)).toList();
  }

  /// Insert a new activity. Returns its new id.
  static Future<int> insertActivity(
    String name, {
    int colorIndex = 0,
    int iconIndex = 23,
  }) async {
    final db = await instance;
    return db.insert('activities', {
      'name': name.trim(),
      'colorIndex': colorIndex,
      'iconIndex': iconIndex,
    });
  }

  /// Update just the color and icon of an activity.
  static Future<void> updateActivityAppearance(
    int id, {
    required int colorIndex,
    required int iconIndex,
  }) async {
    final db = await instance;
    await db.update(
      'activities',
      {'colorIndex': colorIndex, 'iconIndex': iconIndex},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Rename an existing activity.
  static Future<void> updateActivity(int id, String newName) async {
    final db = await instance;
    await db.update(
      'activities',
      {'name': newName.trim()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete an activity AND all its sessions.
  /// Returns the number of sessions that were also removed.
  static Future<int> deleteActivity(int id) async {
    final db = await instance;
    return db.transaction((txn) async {
      final deleted = await txn.delete(
        'sessions',
        where: 'activityId = ?',
        whereArgs: [id],
      );
      await txn.delete('activities', where: 'id = ?', whereArgs: [id]);
      return deleted;
    });
  }

  /// Total time spent on an activity, summed across all completed sessions.
  /// Running sessions (endedAt IS NULL) are excluded — their time is not
  /// yet final, so they shouldn't count toward the total.
  static Future<Duration> totalDurationFor(int activityId) async {
    final db = await instance;
    final rows = await db.rawQuery(
      '''
      SELECT SUM(endedAt - startedAt) AS totalMs
      FROM sessions
      WHERE activityId = ? AND endedAt IS NOT NULL
    ''',
      [activityId],
    );

    final totalMs = rows.first['totalMs'] as int?;
    if (totalMs == null) return Duration.zero;
    return Duration(milliseconds: totalMs);
  }

  /// Total completed-session time for an activity on a specific calendar day.
  static Future<Duration> totalForDay(int activityId, DateTime day) async {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final db = await instance;
    final rows = await db.rawQuery(
      '''
      SELECT SUM(endedAt - startedAt) AS totalMs
      FROM sessions
      WHERE activityId = ?
        AND endedAt IS NOT NULL
        AND startedAt >= ?
        AND startedAt < ?
    ''',
      [
        activityId,
        dayStart.millisecondsSinceEpoch,
        dayEnd.millisecondsSinceEpoch,
      ],
    );
    final totalMs = rows.first['totalMs'] as int?;
    if (totalMs == null) return Duration.zero;
    return Duration(milliseconds: totalMs);
  }

  /// Find any session that's still running (endedAt is null).
  /// Used to recover if the app was killed mid-timer.
  static Future<Session?> getRunningSession() async {
    final db = await instance;
    final rows = await db.query('sessions', where: 'endedAt IS NULL', limit: 1);
    if (rows.isEmpty) return null;
    return Session.fromMap(rows.first);
  }

  /// Get the running (endedAt = null) session for a SPECIFIC activity.
  static Future<Session?> getRunningSessionFor(int activityId) async {
    final db = await instance;
    final rows = await db.query(
      'sessions',
      where: 'activityId = ? AND endedAt IS NULL',
      whereArgs: [activityId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Session.fromMap(rows.first);
  }

  /// All COMPLETED sessions for an activity, newest first.
  static Future<List<Session>> getSessionsFor(int activityId) async {
    final db = await instance;
    final rows = await db.query(
      'sessions',
      where: 'activityId = ? AND endedAt IS NOT NULL',
      whereArgs: [activityId],
      orderBy: 'startedAt DESC',
    );
    return rows.map((r) => Session.fromMap(r)).toList();
  }

  /// Daily totals for one activity, between [from] (inclusive) and
  /// [to] (exclusive). Returns a map keyed by local midnight of each day.
  /// Only completed sessions are counted.
  static Future<Map<DateTime, Duration>> getDailyTotalsFor(
    int activityId,
    DateTime from,
    DateTime to,
  ) async {
    final db = await instance;
    final rows = await db.rawQuery(
      '''
      SELECT startedAt, endedAt
      FROM sessions
      WHERE activityId = ?
        AND endedAt IS NOT NULL
        AND startedAt >= ?
        AND startedAt < ?
    ''',
      [activityId, from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
    );

    final result = <DateTime, Duration>{};
    for (final row in rows) {
      final startedMs = row['startedAt'] as int;
      final endedMs = row['endedAt'] as int;
      // Attribute the whole session to the day it started.
      final started = DateTime.fromMillisecondsSinceEpoch(startedMs);
      final day = DateTime(started.year, started.month, started.day);
      final dur = Duration(milliseconds: endedMs - startedMs);
      result[day] = (result[day] ?? Duration.zero) + dur;
    }
    return result;
  }
}
