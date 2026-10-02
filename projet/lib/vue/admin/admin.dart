import 'package:flutter/material.dart';
import '../../modele/equipement.dart';

class AdminConfigScreen extends StatefulWidget {
  const AdminConfigScreen({super.key});

  @override
  State<AdminConfigScreen> createState() => _AdminConfigScreenState();
}

class _AdminConfigScreenState extends State<AdminConfigScreen> {
  final List<Equipement> _items = [
    Equipement(id: 'helmet', nom: 'Casque de chantier', icon: '🪖', isRequired: true),
    Equipement(id: 'vest', nom: 'Gilet haute visibilité', icon: '🦺', isRequired: true),
    Equipement(id: 'gloves', nom: 'Gants de protection', icon: '🧤', isRequired: false),
    Equipement(id: 'boots', nom: 'Chaussures de sécurité', icon: '🥾', isRequired: true),
    Equipement(id: 'goggles', nom: 'Lunettes de protection', icon: '🥽', isRequired: false),
    Equipement(id: 'ears', nom: 'Protection auditive', icon: '🎧', isRequired: false),
    Equipement(id: 'harness', nom: 'Harnais de sécurité', icon: '🧗', isRequired: false),
    Equipement(id: 'mask', nom: 'Masque respiratoire', icon: '😷', isRequired: false),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuration du Site'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Sélectionnez les EPI obligatoires pour autoriser l\'accès :',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ..._items.map((item) {
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: SwitchListTile(
                secondary: Text(item.icon, style: const TextStyle(fontSize: 24)),
                title: Text(item.nom),
                subtitle: Text(item.isRequired ? 'Obligatoire' : 'Facultatif'),
                value: item.isRequired,
                onChanged: (val) {
                  setState(() {
                    item.isRequired = val;
                  });
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}