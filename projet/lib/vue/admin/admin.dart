// Interface d'administration permettant de configurer les règles du chantier en direct
// en définissant quels équipements de protection individuelle sont strictement obligatoires au portique.

import 'package:flutter/material.dart';
import '../../modele/equipement.dart';

class AdminConfigScreen extends StatefulWidget {
  final List<Equipement> equipements;
  final ValueChanged<List<Equipement>> onChanged;
  const AdminConfigScreen({
    super.key,
    required this.equipements,
    required this.onChanged,
    });

  @override
  State<AdminConfigScreen> createState() => _AdminConfigScreenState();
}

class _AdminConfigScreenState extends State<AdminConfigScreen> {
  void _toggleAll(bool value) {
    setState(() {
      for (var item in widget.equipements) {
        item.isRequired = value;
      }
    });
    widget.onChanged(widget.equipements);
  }  

  @override
  Widget build(BuildContext context) {
    final int requiredCount = widget.equipements.where((e) => e.isRequired).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuration du Site'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Actions rapides',
            onSelected: (val) {
              if (val == 'all') _toggleAll(true);
              if (val == 'none') _toggleAll(false);
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'all', child: Text('Tout cocher')),
              PopupMenuItem(value: 'none', child: Text('Tout décocher')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.amber),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '$requiredCount équipement(s) obligatoire(s) configuré(s).',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...widget.equipements.map((item) {
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: SwitchListTile(
                secondary:
                    Text(item.icon, style: const TextStyle(fontSize: 24)),
                title: Text(
                  item.nom,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  item.isRequired ? 'Obligatoire au portique' : 'Facultatif',
                  style: TextStyle(
                    color: item.isRequired ? Colors.amber : Colors.grey,
                  ),
                ),
                value: item.isRequired,
                onChanged: (val) {
                  setState(() {
                    item.isRequired = val;
                  });
                  widget.onChanged(widget.equipements);
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}