import 'package:flutter/material.dart';

import 'screens/costs_screen.dart';
import 'screens/garage_screen.dart';
import 'screens/reminders_screen.dart';
import 'services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Notifier.init();
  runApp(const VehnexisApp());
}

class VehnexisApp extends StatelessWidget {
  const VehnexisApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF0F766E); // deep teal
    ThemeData theme(Brightness b) => ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: b),
          inputDecorationTheme: const InputDecorationTheme(isDense: true),
        );
    return MaterialApp(
      title: 'Vehnexis',
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  // Bumped whenever data changes so every tab reloads.
  int _version = 0;

  void _changed() {
    setState(() => _version++);
    Notifier.rescheduleAll();
  }

  @override
  void initState() {
    super.initState();
    Notifier.requestPermission().then((_) => Notifier.rescheduleAll());
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      GarageScreen(key: ValueKey('g$_version'), onChanged: _changed),
      RemindersScreen(key: ValueKey('r$_version'), onChanged: _changed),
      CostsScreen(key: ValueKey('c$_version')),
    ];
    return Scaffold(
      body: pages[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() {
          _tab = i;
          _version++;
        }),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.garage_outlined), selectedIcon: Icon(Icons.garage), label: 'Garage'),
          NavigationDestination(icon: Icon(Icons.notifications_none), selectedIcon: Icon(Icons.notifications), label: 'Reminders'),
          NavigationDestination(icon: Icon(Icons.pie_chart_outline), selectedIcon: Icon(Icons.pie_chart), label: 'Costs'),
        ],
      ),
    );
  }
}
