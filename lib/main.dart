import 'package:flutter/material.dart';

import 'database.dart';

import 'screens/activity_list.dart';

import 'notifications.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppNotifications.init();
  runApp(const LifeTrackerApp());
}

class LifeTrackerApp extends StatelessWidget {
  const LifeTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Life Tracker',
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const ActivityListScreen(),
    );
  }
}

/// Temporary screen to prove the timer works end-to-end.
/// We'll replace this with the activity list later.
class TimerTestScreen extends StatefulWidget {
  const TimerTestScreen({super.key});

  @override
  State<TimerTestScreen> createState() => _TimerTestScreenState();
}

class _TimerTestScreenState extends State<TimerTestScreen> {
  int? _runningSessionId; // non-null while a session is active

  @override
  void initState() {
    super.initState();
    _checkForRunningSession();
  }

  /// If the app was killed mid-session, pick up where we left off.
  Future<void> _checkForRunningSession() async {
    final session = await AppDatabase.getRunningSession();
    if (session != null && mounted) {
      setState(() => _runningSessionId = session.id);
    }
  }

  Future<void> _start() async {
    final activities = await AppDatabase.getActivities();
    if (activities.isEmpty) return;

    // For now, always use the first activity ("Editing" - well, "Gym").
    final id = await AppDatabase.startSession(activities.first.id!);
    setState(() => _runningSessionId = id);
  }

  Future<void> _stop() async {
    if (_runningSessionId == null) return;
    await AppDatabase.stopSession(_runningSessionId!);
    setState(() => _runningSessionId = null);
  }

  @override
  Widget build(BuildContext context) {
    final running = _runningSessionId != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Timer Test')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              running ? Icons.timer : Icons.timer_off,
              size: 96,
              color: running ? Colors.green : Colors.grey,
            ),
            const SizedBox(height: 24),
            Text(
              running ? 'Session running' : 'No active session',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 48),
            FilledButton.icon(
              onPressed: running ? _stop : _start,
              icon: Icon(running ? Icons.stop : Icons.play_arrow),
              label: Text(running ? 'Stop' : 'Start'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: 20,
                ),
                textStyle: const TextStyle(fontSize: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
