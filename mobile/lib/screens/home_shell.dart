import 'package:flutter/material.dart';

import 'calendar_screen.dart';
import 'profile_screen.dart';
import 'today_screen.dart';
import 'wardrobe_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  // Bumped whenever data changes so every tab reloads.
  int _version = 0;

  void _changed() => setState(() => _version++);

  @override
  Widget build(BuildContext context) {
    final pages = [
      TodayScreen(key: ValueKey('t$_version'), onChanged: _changed, onOpenWardrobe: () => setState(() => _tab = 1)),
      WardrobeScreen(key: ValueKey('w$_version'), onChanged: _changed),
      CalendarScreen(key: ValueKey('c$_version'), onChanged: _changed),
      const ProfileScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.wb_sunny_outlined), selectedIcon: Icon(Icons.wb_sunny_rounded), label: 'Today'),
          NavigationDestination(
              icon: Icon(Icons.checkroom_outlined), selectedIcon: Icon(Icons.checkroom_rounded), label: 'Wardrobe'),
          NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month_rounded), label: 'Calendar'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}
