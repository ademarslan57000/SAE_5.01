import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../modele/equipement.dart';
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

  final List<Equipement> _equipements =[
    Equipement(id: 'helmet', nom: "Casque de chantier", icon: "🪖", isRequired: false),
    Equipement(id: 'vest', nom: "Gilet haute visibilité", icon: "🦺", isRequired: false),
    Equipement(id: 'gloves', nom: "Gants de protection", icon: "🧤", isRequired: false),
    Equipement(id: 'boots', nom: "Chaussures de sécurité", icon: "🥾", isRequired: false),
    Equipement(id: 'goggles', nom: "Lunettes de protection", icon: "🥽", isRequired: false),
    Equipement(id: 'ears', nom: "Protection auditive", icon: "🎧", isRequired: false),
    Equipement(id: 'harness', nom: "Harnais de sécurité", icon: "🧗", isRequired: false),
    Equipement(id: 'mask', nom: "Masque respiratoire", icon: "😷", isRequired: false)
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          ScanScreen(
            cameras: widget.cameras,
            equipementsRequis: _equipements.where((e) => e.isRequired).toList(),
          ),
          AdminConfigScreen(
            equipements: _equipements,
            onChanged: (updatedList){
              setState(() {});
            },
          ),
          const HistoryScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index){
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
