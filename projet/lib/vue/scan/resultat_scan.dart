import 'package:flutter/material.dart';
import '../../modele/equipement.dart';
import '../../modele/detection.dart';

class ResultatScanScreen extends StatelessWidget {
  final List<Equipement> equipementsRequis;
  final List<Detection> detections;

  const ResultatScanScreen({
    super.key,
    required this.equipementsRequis,
    required this.detections,
  });

  @override
  Widget build(BuildContext context) {
    final Map<String, Detection> mapDetections = {
      for (var d in detections)
        if (d.confidence >= 0.5) d.idEquipement: d,
    };

    final List<Equipement> manquants = equipementsRequis
        .where((eq) => !mapDetections.containsKey(eq.id))
        .toList();

    final bool accesAutorise = manquants.isEmpty;
    final Color couleurStatut =
        accesAutorise ? Colors.green.shade700 : Colors.red.shade700;
    final Color couleurFondCarte = accesAutorise
        ? Colors.green.withValues(alpha: 0.15)
        : Colors.red.withValues(alpha: 0.15);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Résultat du Contrôle EPI'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: couleurFondCarte,
                border: Border.all(color: couleurStatut, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(
                    accesAutorise
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded,
                    color: accesAutorise ? Colors.greenAccent : Colors.redAccent,
                    size: 72,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    accesAutorise ? 'ACCÈS AUTORISÉ' : 'ACCÈS REFUSÉ',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color:
                          accesAutorise ? Colors.greenAccent : Colors.redAccent,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    accesAutorise
                        ? 'Tous les équipements obligatoires sont portés.'
                        : '${manquants.length} équipement(s) obligatoire(s) manquant(s).',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15, color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Détail de la vérification par équipement :',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: equipementsRequis.isEmpty
                  ? const Center(
                      child: Text(
                        'Aucun équipement obligatoire n\'était exigé pour ce contrôle.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: equipementsRequis.length,
                      itemBuilder: (context, index) {
                        final eq = equipementsRequis[index];
                        final Detection? det = mapDetections[eq.id];
                        final bool estPresent = det != null;
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            leading: Text(
                              eq.icon,
                              style: const TextStyle(fontSize: 28),
                            ),
                            title: Text(
                              eq.nom,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              estPresent
                                  ? 'Détecté (Confiance : ${(det.confidence * 100).round()}%)'
                                  : 'Non détecté — Obligatoire',
                              style: TextStyle(
                                color: estPresent
                                    ? Colors.greenAccent
                                    : Colors.redAccent,
                              ),
                            ),
                            trailing: Icon(
                              estPresent ? Icons.check_circle : Icons.error,
                              color: estPresent
                                  ? Colors.greenAccent
                                  : Colors.redAccent,
                              size: 28,
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text(
                'Nouveau scan',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}