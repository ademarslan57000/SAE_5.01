// Vue destinée à la consultation des contrôles antérieurs et à la consolidation
// des indicateurs statistiques de conformité du portique de sécurité.

import 'dart:io';
import 'package:flutter/material.dart';
import '../../service/historique_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List _passages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _chargerHistorique();
    HistoriqueService.refreshNotifier.addListener(_chargerHistorique);
  }

  @override
  void dispose() {
    HistoriqueService.refreshNotifier.removeListener(_chargerHistorique);
    super.dispose();
  }

  Future<void> _chargerHistorique() async {
    try {
      final data = await HistoriqueService.listerPassages();
      if (mounted) {
        setState(() {
          _passages = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDateIso(String? iso) {
    if (iso == null) return '';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${pad(d.day)}/${pad(d.month)}/${d.year} à ${pad(d.hour)}:${pad(d.minute)}:${pad(d.second)}';
  }

  @override
  Widget build(BuildContext context) {
    final total = _passages.length;
    final conformes = _passages.where((p) => (p['autorise'] as int? ?? 0) == 1).length;
    final taux = total > 0 ? ((conformes / total) * 100).round() : 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique & Statistiques'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
            onPressed: _chargerHistorique,
          ),
          if (_passages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Vider l\'historique',
              onPressed: () async {
                await HistoriqueService.viderHistorique();
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _passages.isEmpty
              ? const Center(
                  child: Text(
                    'Aucun passage enregistré en base.\nEffectuez un contrôle depuis le scanner.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : Column(
                  children: [
                    // Bandeau de statistiques de conformité
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                      child: Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _StatItem(label: 'Passages', value: '$total', color: Colors.amber),
                              _StatItem(label: 'Conformes', value: '$conformes', color: Colors.greenAccent),
                              _StatItem(label: 'Taux', value: '$taux%', color: Colors.tealAccent),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Liste des passages enregistrés dans SQLite
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _passages.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = _passages[index];
                          final bool conforme = (item['autorise'] as int? ?? 0) == 1;
                          final String? imgPath = item['image_chemin'] as String?;
                          final int nbDetectes = (item['total_detectes'] as int?) ?? 0;
                          final int nbRequis = (item['total_requis'] as int?) ?? 0;
                          final String? manquants = item['manquants'] as String?;

                          return Card(
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(10),
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: imgPath != null && File(imgPath).existsSync()
                                    ? Image.file(
                                        File(imgPath),
                                        width: 56,
                                        height: 56,
                                        fit: BoxFit.cover,
                                      )
                                    : Container(
                                        width: 56,
                                        height: 56,
                                        color: Colors.grey[850],
                                        child: Icon(
                                          conforme ? Icons.check_circle : Icons.cancel,
                                          color: conforme ? Colors.greenAccent : Colors.redAccent,
                                        ),
                                      ),
                              ),
                              title: Text(
                                conforme ? 'Passage Autorisé' : 'Passage Refusé',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: conforme ? Colors.greenAccent : Colors.redAccent,
                                ),
                              ),
                              subtitle: Text(
                                '${_formatDateIso(item['date_heure'] as String?)}\n'
                                '$nbDetectes/$nbRequis EPI détecté(s)'
                                '${!conforme && manquants != null && manquants.isNotEmpty ? ' • Manquant : $manquants' : ''}',
                              ),
                              isThreeLine: true,
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => DetailHistoriqueScreen(passage: item),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatItem({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}

/// Écran de détail d'un passage affichant l'image annotée avec ses boîtes et la liste des EPI
class DetailHistoriqueScreen extends StatefulWidget {
  final Map<String, dynamic> passage;

  const DetailHistoriqueScreen({super.key, required this.passage});

  @override
  State<DetailHistoriqueScreen> createState() => _DetailHistoriqueScreenState();
}

class _DetailHistoriqueScreenState extends State<DetailHistoriqueScreen> {
  List _equipements = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _chargerDetails();
  }

  Future<void> _chargerDetails() async {
    final scanId = widget.passage['id'] as int;
    final rows = await HistoriqueService.obtenirEquipementsPassage(scanId);
    if (mounted) {
      setState(() {
        _equipements = rows;
        _loading = false;
      });
    }
  }

  String _formatDateIso(String? iso) {
    if (iso == null) return '';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${pad(d.day)}/${pad(d.month)}/${d.year} à ${pad(d.hour)}:${pad(d.minute)}:${pad(d.second)}';
  }

  @override
  Widget build(BuildContext context) {
    final bool conforme = (widget.passage['autorise'] as int? ?? 0) == 1;
    final String? imgPath = widget.passage['image_chemin'] as String?;
    final String dateStr = _formatDateIso(widget.passage['date_heure'] as String?);
    final String modele = (widget.passage['version_modele'] as String?) ?? '6-classes-v1';

    return Scaffold(
      appBar: AppBar(title: Text('Contrôle #${widget.passage['id']}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image sauvegardée avec ses boîtes englobantes
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: imgPath != null && File(imgPath).existsSync()
                  ? Image.file(
                      File(imgPath),
                      height: 360,
                      fit: BoxFit.contain,
                    )
                  : Container(
                      height: 220,
                      color: Colors.grey[900],
                      child: const Center(
                        child: Text('Aperçu image indisponible', style: TextStyle(color: Colors.white54)),
                      ),
                    ),
            ),
            const SizedBox(height: 16),

            // Bandeau statut global
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: conforme
                    ? Colors.green.withValues(alpha: 0.15)
                    : Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: conforme ? Colors.greenAccent : Colors.redAccent,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        conforme ? Icons.check_circle : Icons.cancel,
                        color: conforme ? Colors.greenAccent : Colors.redAccent,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          conforme ? 'CONFORME — Accès autorisé' : 'NON CONFORME — Accès refusé',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Date : $dateStr  •  Modèle : $modele',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              'Détail par équipement obligatoire :',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),

            if (_loading)
              const Center(child: CircularProgressIndicator())
            else
              ..._equipements.map((eq) {
                final bool ok = (eq['detecte'] as int? ?? 0) == 1;
                final double? conf = eq['confiance'] as double?;
                final String icone = (eq['icone'] as String?) ?? '🛡️';
                final String nom = (eq['nom_affiche'] as String?) ?? '';

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: Text(icone, style: const TextStyle(fontSize: 24)),
                    title: Text(nom, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      ok
                          ? 'Détecté${conf != null ? ' (Confiance : ${(conf * 100).round()}%)' : ''}'
                          : 'Manquant — Obligatoire',
                      style: TextStyle(color: ok ? Colors.greenAccent : Colors.redAccent),
                    ),
                    trailing: Icon(
                      ok ? Icons.check_circle : Icons.cancel,
                      color: ok ? Colors.greenAccent : Colors.redAccent,
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}