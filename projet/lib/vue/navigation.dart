// Contrôleur de navigation globale chargeant les classes d'EPI depuis labels.txt
// et synchronisant la liste des équipements entre l'administration et le scanner.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../modele/equipement.dart';
import '../service/auth_service.dart';
import 'scan/scanner.dart';
import 'admin/admin.dart';
import 'historique/historique.dart';

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  int _currentIndex = 0;
  List<Equipement> _equipements = [];
  bool _isLoading = true;

  static const Map<String, (String, String)> _labelsMetadonnees = {
    'helmet': ('Casque de chantier', '🪖'),
    'vest': ('Gilet haute visibilité', '🦺'),
    'gloves': ('Gants de protection', '🧤'),
    'boots': ('Chaussures de sécurité', '🥾'),
    'goggles': ('Lunettes de protection', '𥽌'),
    'ears': ('Protection auditive', '🎧'),
    'harness': ('Harnais de sécurité', '🧗'),
    'mask': ('Masque respiratoire', '😷'),
  };

  @override
  void initState() {
    super.initState();
    _chargerLabels();
  }

  Future<void> _chargerLabels() async {
    try {
      final String contenu = await rootBundle.loadString('assets/labels.txt');
      final List<String> lignes = contenu
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      setState(() {
        _equipements = lignes.map((label) {
          final meta = _labelsMetadonnees[label];
          return Equipement(
            id: label,
            nom: meta?.$1 ?? label,
            icon: meta?.$2 ?? '🛡️',
            isRequired: label == 'helmet' || label == 'vest' || label == 'boots',
          );
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Erreur lors du chargement de labels.txt : $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final scan = ScanScreen(
      equipementsRequis: _equipements.where((e) => e.isRequired).toList(),
    );

    // Ouvrier : uniquement le scan, sans barre de navigation ni config/historique.
    if (AuthService.utilisateurCourant?.role != 'admin') {
      return Scaffold(body: scan);
    }

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          scan,
          AdminConfigScreen(
            equipements: _equipements,
            onChanged: (updatedList) {
              setState(() {});
            },
          ),
          const HistoryScreen(),
        ],
      ),
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