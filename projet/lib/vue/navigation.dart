import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

import 'scan/scanner.dart';
import 'admin/admin.dart';
import 'historique/historique.dart';

class NavigationScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const NavigationScreen({super.key, required this.cameras});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      ScanScreen(cameras: widget.cameras),
      const AdminConfigScreen(),
      const HistoryScreen(),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.camera_alt_outlined),
            selectedIcon: Icon(Icons.camera_alt),
            label: 'Scan',
          ),
          NavigationDestination(
            icon: Icon(Icons.admin_panel_settings_outlined),
            selectedIcon: Icon(Icons.admin_panel_settings),
            label: 'Config Admin',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Historique',
          ),
        ],
      ),
    );
  }
}
