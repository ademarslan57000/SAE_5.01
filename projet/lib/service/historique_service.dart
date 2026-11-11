import 'dart:core';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'base_donnees.dart';
import '../modele/decision.dart';
import '../modele/detection.dart';
import '../modele/equipement.dart';

class HistoriqueService {
  static final ValueNotifier<int> refreshNotifier = ValueNotifier<int>(0);

  static Future<String> sauvegarderImageAvecBoites({
    required String? rawImagePath,
    required List<Detection> detections,
    required Set<String> idsRequis,
  }) async {
    final recorder = ui.PictureRecorder();
    double width = 360;
    double height = 480;
    ui.Image? baseImage;

    try {
      if (rawImagePath != null && File(rawImagePath).existsSync()) {
        final bytes = await File(rawImagePath).readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes, targetWidth: 360);
        final frame = await codec.getNextFrame();
        baseImage = frame.image;
        width = baseImage.width.toDouble();
        height = baseImage.height.toDouble();
      }
    } catch (_) {}

    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));

    if (baseImage != null) {
      canvas.drawImage(baseImage, Offset.zero, Paint());
    } else {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, width, height),
        Paint()..color = const Color(0xFF1E1E1E),
      );
    }

    for (final det in detections) {
      final bool estRequis = idsRequis.contains(det.idEquipement.toLowerCase());
      final Color boxColor = estRequis ? Colors.greenAccent : Colors.lightBlueAccent;

      final rect = Rect.fromLTWH(
        det.boundingBox.left * width,
        det.boundingBox.top * height,
        det.boundingBox.width * width,
        det.boundingBox.height * height,
      );

      final boxPaint = Paint()
        ..color = boxColor
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;

      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6)), boxPaint);

      final textSpan = TextSpan(
        text: ' ${det.label} ${(det.confidence * 100).round()}% ',
        style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold),
      );
      final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
      final labelRect = Rect.fromLTWH(
        rect.left,
        (rect.top - tp.height - 2).clamp(0.0, height),
        tp.width + 4,
        tp.height + 2,
      );

      canvas.drawRRect(RRect.fromRectAndRadius(labelRect, const Radius.circular(4)), Paint()..color = boxColor);
      tp.paint(canvas, Offset(labelRect.left + 2, labelRect.top + 1));
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());
    final pngBytes = await img.toByteData(format: ui.ImageByteFormat.png);

    final file = File('${Directory.systemTemp.path}/scan_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(pngBytes!.buffer.asUint8List());
    return file.path;
  }

  static Future<void> enregistrerPassage(
    ResultatDecision resultat, 
    List<Equipement> equipementsRequis,
    int chantierId,
    double seuilConfiance,
    String versionModele,
    {String? cheminImage, int? utilisateurId}
  ) async {
    final db = await BaseDonnees.instance;

    await db.transaction((txn) async {
      final scanId = await txn.insert('scan', {
        'date_heure': DateTime.now().toIso8601String(),
        'chantier_id': chantierId,
        'utilisateur_id': utilisateurId, 
        'autorise': resultat.accesAutorise ? 1 : 0,
        'image_chemin': cheminImage,
        'seuil': seuilConfiance,
        'version_modele': versionModele,
      });

      for (final e in equipementsRequis) {
        final detection = resultat.detectes[e.id];
        
        await txn.insert('scan_equipement', {
          'scan_id': scanId,
          'equipement_id': e.idBase ?? 1, 
          'detecte': detection != null ? 1 : 0,
          'confiance': detection?.confidence,
        });
      }
    });
    refreshNotifier.value++;
  }

  static Future<List> listerPassages() async {
    final db = await BaseDonnees.instance;

    final resultats = await db.rawQuery('''
      SELECT s.id, s.date_heure, s.autorise, s.image_chemin, s.seuil, s.version_modele,
      COALESCE(u.prenom || ' ' || u.nom, 'Visiteur') AS personne,
      eq.nom AS equipe,
      COUNT(se.equipement_id) AS total_requis,
      SUM(CASE WHEN se.detecte = 1 THEN 1 ELSE 0 END) AS total_detectes,
      GROUP_CONCAT(CASE WHEN se.detecte = 0 THEN e.nom_affiche END, ', ') AS manquants
      FROM scan s
      LEFT JOIN utilisateur u ON u.id = s.utilisateur_id
      LEFT JOIN equipe eq ON eq.id = u.equipe_id
      LEFT JOIN scan_equipement se ON se.scan_id = s.id
      LEFT JOIN equipement e ON e.id = se.equipement_id
      GROUP BY s.id
      ORDER BY s.date_heure DESC
      LIMIT 50;
    ''');

    return resultats;
  }

  static Future<List> obtenirEquipementsPassage(int scanId) async {
    final db = await BaseDonnees.instance;
    return await db.rawQuery('''
      SELECT e.code_classe, e.nom_affiche, e.icone, se.detecte, se.confiance
      FROM scan_equipement se
      INNER JOIN equipement e ON e.id = se.equipement_id
      WHERE se.scan_id = ?
      ORDER BY e.id ASC
    ''', [scanId]);
  }

  static Future<void> viderHistorique() async {
    final db = await BaseDonnees.instance;
    await db.delete('scan');
    refreshNotifier.value++;
  }
}