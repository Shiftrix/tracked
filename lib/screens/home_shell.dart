import 'package:flutter/material.dart';

import 'activity_list.dart';
import 'tasks_screen.dart';
import 'profile_screen.dart';

/// Container with bottom navigation between Timers, Tasks, and You.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  /// Key so we can call reload() on the profile screen when it becomes active.
  final _profileKey = GlobalKey<ProfileScreenState>();

  late final List<Widget> _screens = [
    const ActivityListScreen(),
    const TasksScreen(),
    ProfileScreen(key: _profileKey),
  ];

  void _onTabChanged(int newIndex) {
    setState(() => _index = newIndex);

    // When switching to the You tab, refresh XP and stats.
    if (newIndex == 2) {
      _profileKey.currentState?.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _onTabChanged,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.timer_outlined),
            selectedIcon: Icon(Icons.timer),
            label: 'Timers',
          ),
          NavigationDestination(
            icon: Icon(Icons.check_circle_outline),
            selectedIcon: Icon(Icons.check_circle),
            label: 'Tasks',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'You',
          ),
        ],
      ),
    );
  }
}
