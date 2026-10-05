import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// A single row in the `activities` table.
/// e.g. "Gym", "Editing", "Music"
class Activity {
  final int? id;
  final String name;
  final int colorIndex;
  final int iconIndex;
  final double multiplier;

  Activity({
    this.id,
    required this.name,
    this.colorIndex = 0,
    this.iconIndex = 23,
    this.multiplier = 1.0,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'colorIndex': colorIndex,
    'iconIndex': iconIndex,
    'multiplier': multiplier,
  };

  factory Activity.fromMap(Map<String, dynamic> map) => Activity(
    id: map['id'] as int?,
    name: map['name'] as String,
    colorIndex: (map['colorIndex'] as int?) ?? 0,
    iconIndex: (map['iconIndex'] as int?) ?? 23,
    multiplier: (map['multiplier'] as num?)?.toDouble() ?? 1.0,
  );
}

/// A single row in the `sessions` table.
/// One row = one completed (or in-progress) stretch of time.
class Session {
  final int? id;
  final int activityId;
  final DateTime startedAt;
  final DateTime? endedAt; // null means "still running"
  final int xpEarned;

  Session({
    this.id,
    required this.activityId,
    required this.startedAt,
    this.endedAt,
    this.xpEarned = 0,
  });

  /// Duration of this session. If it's still running, returns null.
  Duration? get duration =>
      endedAt == null ? null : endedAt!.difference(startedAt);

  Map<String, dynamic> toMap() => {
    'id': id,
    'activityId': activityId,
    'startedAt': startedAt.millisecondsSinceEpoch,
    'endedAt': endedAt?.millisecondsSinceEpoch,
    'xpEarned': xpEarned,
  };

  factory Session.fromMap(Map<String, dynamic> map) => Session(
    id: map['id'] as int?,
    activityId: map['activityId'] as int,
    startedAt: DateTime.fromMillisecondsSinceEpoch(map['startedAt'] as int),
    endedAt: map['endedAt'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(map['endedAt'] as int),
    xpEarned: (map['xpEarned'] as int?) ?? 0,
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
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE activities (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            colorIndex INTEGER NOT NULL DEFAULT 0,
            iconIndex INTEGER NOT NULL DEFAULT 23,
            multiplier REAL NOT NULL DEFAULT 1.0
          )
        ''');

        await db.execute('''
          CREATE TABLE sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            activityId INTEGER NOT NULL,
            startedAt INTEGER NOT NULL,
            endedAt INTEGER,
            xpEarned INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY (activityId) REFERENCES activities (id)
          )
        ''');

        await db.insert('activities', {
          'name': 'Example',
          'colorIndex': 0,
          'iconIndex': 23,
          'multiplier': 1.0,
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
        // v2 → v3: added multiplier to activities, xpEarned to sessions.
        if (oldVersion < 3) {
          await db.execute(
            'ALTER TABLE activities ADD COLUMN multiplier REAL NOT NULL DEFAULT 1.0',
          );
          await db.execute(
            'ALTER TABLE sessions ADD COLUMN xpEarned INTEGER NOT NULL DEFAULT 0',
          );
          // Retroactively compute XP for every existing completed session.
          final sessions = await db.query(
            'sessions',
            where: 'endedAt IS NOT NULL',
          );
          for (final row in sessions) {
            final startedAt = row['startedAt'] as int;
            final endedAt = row['endedAt'] as int;
            final activityId = row['activityId'] as int;
            final durationMs = endedAt - startedAt;

            final actRows = await db.query(
              'activities',
              where: 'id = ?',
              whereArgs: [activityId],
              limit: 1,
            );
            final multiplier = actRows.isEmpty
                ? 1.0
                : (actRows.first['multiplier'] as num?)?.toDouble() ?? 1.0;

            final minutes = durationMs / 60000.0;
            final xp = (minutes * multiplier).floor();

            await db.update(
              'sessions',
              {'xpEarned': xp},
              where: 'id = ?',
              whereArgs: [row['id']],
            );
          }
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

  /// Mark a session as finished by writing its end time AND the XP earned.
  /// Returns the XP earned (0 if the session wasn't found).
  static Future<int> stopSession(int sessionId) async {
    final db = await instance;

    final rows = await db.query(
      'sessions',
      where: 'id = ?',
      whereArgs: [sessionId],
      limit: 1,
    );
    if (rows.isEmpty) return 0;

    final session = Session.fromMap(rows.first);
    final endedAt = DateTime.now();
    final durationMs = endedAt.difference(session.startedAt).inMilliseconds;

    final actRows = await db.query(
      'activities',
      where: 'id = ?',
      whereArgs: [session.activityId],
      limit: 1,
    );
    final multiplier = actRows.isEmpty
        ? 1.0
        : (actRows.first['multiplier'] as num?)?.toDouble() ?? 1.0;

    final xp = _xpForSession(durationMs, multiplier);

    await db.update(
      'sessions',
      {'endedAt': endedAt.millisecondsSinceEpoch, 'xpEarned': xp},
      where: 'id = ?',
      whereArgs: [sessionId],
    );

    return xp;
  }

  /// How many completed sessions started today (any activity)?
  static Future<int> sessionsStartedToday() async {
    final db = await instance;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM sessions '
      'WHERE endedAt IS NOT NULL '
      'AND startedAt >= ? AND startedAt < ?',
      [todayStart.millisecondsSinceEpoch, todayEnd.millisecondsSinceEpoch],
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  /// Compute XP for a session. Duplicated logic from lib/xp.dart to
  /// keep the database layer free of UI imports.
  static int _xpForSession(int durationMs, double multiplier) {
    final minutes = durationMs / 60000.0;
    return (minutes * multiplier).floor();
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
    double multiplier = 1.0,
  }) async {
    final db = await instance;
    return db.insert('activities', {
      'name': name.trim(),
      'colorIndex': colorIndex,
      'iconIndex': iconIndex,
      'multiplier': multiplier,
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

  /// Global XP earned across all sessions.
  static Future<int> totalXp() async {
    final db = await instance;
    final rows = await db.rawQuery(
      'SELECT SUM(xpEarned) AS total FROM sessions WHERE endedAt IS NOT NULL',
    );
    return (rows.first['total'] as int?) ?? 0;
  }

  /// Sum of every completed session's duration, across all activities.
  static Future<Duration> totalTimeAllActivities() async {
    final db = await instance;
    final rows = await db.rawQuery(
      'SELECT SUM(endedAt - startedAt) AS totalMs FROM sessions '
      'WHERE endedAt IS NOT NULL',
    );
    final totalMs = rows.first['totalMs'] as int?;
    if (totalMs == null) return Duration.zero;
    return Duration(milliseconds: totalMs);
  }

  /// Set of calendar days (midnight, local) that have at least one
  /// completed session. Used for streak calculations.
  static Future<Set<DateTime>> daysWithSessions() async {
    final db = await instance;
    final rows = await db.rawQuery(
      'SELECT DISTINCT startedAt FROM sessions WHERE endedAt IS NOT NULL',
    );
    final days = <DateTime>{};
    for (final row in rows) {
      final ms = row['startedAt'] as int;
      final dt = DateTime.fromMillisecondsSinceEpoch(ms);
      days.add(DateTime(dt.year, dt.month, dt.day));
    }
    return days;
  }

  /// Earliest year with any completed session. Null if none.
  /// If [activityId] is provided, restricted to that activity.
  static Future<int?> earliestSessionYear(int? activityId) async {
    final db = await instance;
    final query = activityId == null
        ? 'SELECT MIN(startedAt) AS first FROM sessions WHERE endedAt IS NOT NULL'
        : 'SELECT MIN(startedAt) AS first FROM sessions WHERE endedAt IS NOT NULL AND activityId = ?';
    final args = activityId == null ? <Object>[] : [activityId];
    final rows = await db.rawQuery(query, args);
    final first = rows.first['first'] as int?;
    if (first == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(first).year;
  }

  /// Current streak. Today counts only if there's a session today.
  /// Returns (currentStreak, doneToday).
  static Future<({int current, bool doneToday})> currentStreak() async {
    final days = await daysWithSessions();
    if (days.isEmpty) return (current: 0, doneToday: false);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final doneToday = days.contains(today);

    // Start from today if done, otherwise yesterday.
    DateTime cursor = doneToday ? today : yesterday;
    int streak = 0;
    while (days.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return (current: streak, doneToday: doneToday);
  }

  /// Longest streak ever.
  static Future<int> longestStreak() async {
    final days = await daysWithSessions();
    if (days.isEmpty) return 0;

    final sorted = days.toList()..sort();
    int longest = 1;
    int run = 1;
    for (int i = 1; i < sorted.length; i++) {
      final diff = sorted[i].difference(sorted[i - 1]).inDays;
      if (diff == 1) {
        run++;
        if (run > longest) longest = run;
      } else if (diff > 1) {
        run = 1;
      }
      // diff == 0 can't happen (set, dedupe)
    }
    return longest;
  }

  /// Total XP earned on a specific activity.
  static Future<int> xpForActivity(int activityId) async {
    final db = await instance;
    final rows = await db.rawQuery(
      'SELECT SUM(xpEarned) AS total FROM sessions '
      'WHERE activityId = ? AND endedAt IS NOT NULL',
      [activityId],
    );
    return (rows.first['total'] as int?) ?? 0;
  }

  /// Update an activity's XP multiplier.
  static Future<void> updateActivityMultiplier(
    int id,
    double multiplier,
  ) async {
    final db = await instance;
    await db.update(
      'activities',
      {'multiplier': multiplier},
      where: 'id = ?',
      whereArgs: [id],
    );
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

  /// Total XP earned on a specific calendar day for a specific activity.
  /// If [activityId] is null, aggregates all activities.
  static Future<int> xpForDay(int? activityId, DateTime day) async {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final db = await instance;

    final query = activityId == null
        ? 'SELECT SUM(xpEarned) AS total FROM sessions '
              'WHERE endedAt IS NOT NULL AND startedAt >= ? AND startedAt < ?'
        : 'SELECT SUM(xpEarned) AS total FROM sessions '
              'WHERE activityId = ? AND endedAt IS NOT NULL '
              'AND startedAt >= ? AND startedAt < ?';

    final args = activityId == null
        ? [dayStart.millisecondsSinceEpoch, dayEnd.millisecondsSinceEpoch]
        : [
            activityId,
            dayStart.millisecondsSinceEpoch,
            dayEnd.millisecondsSinceEpoch,
          ];

    final rows = await db.rawQuery(query, args);
    return (rows.first['total'] as int?) ?? 0;
  }

  /// Per-day XP for a month, for a specific activity.
  /// Per-day XP for a range of dates, for a specific activity.
  /// If [activityId] is null, aggregates all activities.
  static Future<Map<DateTime, int>> xpPerDayFor(
    int? activityId,
    DateTime from,
    DateTime to,
  ) async {
    final db = await instance;
    final query = activityId == null
        ? 'SELECT startedAt, xpEarned FROM sessions '
              'WHERE endedAt IS NOT NULL AND startedAt >= ? AND startedAt < ?'
        : 'SELECT startedAt, xpEarned FROM sessions '
              'WHERE activityId = ? AND endedAt IS NOT NULL '
              'AND startedAt >= ? AND startedAt < ?';

    final args = activityId == null
        ? [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch]
        : [activityId, from.millisecondsSinceEpoch, to.millisecondsSinceEpoch];

    final rows = await db.rawQuery(query, args);
    final result = <DateTime, int>{};
    for (final row in rows) {
      final ms = row['startedAt'] as int;
      final dt = DateTime.fromMillisecondsSinceEpoch(ms);
      final day = DateTime(dt.year, dt.month, dt.day);
      final xp = (row['xpEarned'] as int?) ?? 0;
      result[day] = (result[day] ?? 0) + xp;
    }
    return result;
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
    int? activityId,
    DateTime from,
    DateTime to,
  ) async {
    final db = await instance;

    // Null activityId = aggregate across all activities.
    final query = activityId == null
        ? '''
          SELECT startedAt, endedAt
          FROM sessions
          WHERE endedAt IS NOT NULL
            AND startedAt >= ?
            AND startedAt < ?
        '''
        : '''
          SELECT startedAt, endedAt
          FROM sessions
          WHERE activityId = ?
            AND endedAt IS NOT NULL
            AND startedAt >= ?
            AND startedAt < ?
        ''';

    final args = activityId == null
        ? [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch]
        : [activityId, from.millisecondsSinceEpoch, to.millisecondsSinceEpoch];

    final rows = await db.rawQuery(query, args);

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
