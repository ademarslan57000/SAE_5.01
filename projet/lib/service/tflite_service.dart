// Service d'inférence TFLite : charge le modèle YOLO11n exporté par Ultralytics,
// prépare chaque image de la caméra (rotation, letterbox, normalisation) dans un
// tampon de nombres, lance le modèle et décode ses sorties en détections dont les
// coordonnées sont normalisées entre 0 et 1 par rapport à l'image redressée.

import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';
import '../modele/detection.dart';

/// Géométrie du letterbox appliqué à une image, pour remettre les boîtes
/// du modèle dans le repère de l'image d'origine.
class _Cadre {
  final double echelle; // facteur de redimensionnement image -> entrée du modèle
  final int padX; // bandes grises ajoutées à gauche (en pixels du modèle)
  final int padY; // bandes grises ajoutées en haut
  final int largeur; // dimensions de l'image redressée (après rotation)
  final int hauteur;

  const _Cadre(this.echelle, this.padX, this.padY, this.largeur, this.hauteur);
}

class TfliteService {
  Interpreter? _interpreter;
  List<String> _labels = [];

  int _inputSize = 640;
  bool _nchw = true; // [1, 3, 640, 640] (export Ultralytics) ou [1, 640, 640, 3]
  int _nbCanaux = 0; // 4 coordonnées + 1 score par classe (10 pour 6 classes)
  int _nbBoites = 0; // 8400 boîtes candidates pour une entrée 640x640
  bool _sortieTransposee = false; // [1, 8400, 10] au lieu de [1, 10, 8400]

  Float32List _entree = Float32List(0);
  Float32List _sortie = Float32List(0);
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;

  static const Map<String, String> _nomsAffichage = {
    'person': 'Personne',
    'helmet': 'Casque',
    'vest': 'Gilet HV',
    'gloves': 'Gants',
    'boots': 'Chaussures',
    'goggles': 'Lunettes',
  };

  /// Charge le modèle et la liste des classes.
  /// labels.txt doit contenir les classes DANS L'ORDRE DU MODÈLE, une par ligne
  /// (person, helmet, vest, gloves, boots, goggles pour le run 4).
  Future<bool> chargerModele({
    String modelAsset = 'assets/best.tflite',
    String labelsAsset = 'assets/labels.txt',
  }) async {
    try {
      final options = InterpreterOptions()..threads = 4;
      _interpreter = await Interpreter.fromAsset(modelAsset, options: options);

      // Forme de l'entrée : Ultralytics exporte en [1, 3, 640, 640] (couleurs d'abord).
      final inShape = _interpreter!.getInputTensor(0).shape;
      _nchw = inShape[1] == 3;
      _inputSize = _nchw ? inShape[2] : inShape[1];

      // Forme de la sortie : [1, 4 + nbClasses, 8400].
      final outShape = _interpreter!.getOutputTensor(0).shape;
      _sortieTransposee = outShape[1] > outShape[2];
      _nbCanaux = _sortieTransposee ? outShape[2] : outShape[1];
      _nbBoites = _sortieTransposee ? outShape[1] : outShape[2];

      _entree = Float32List(_inputSize * _inputSize * 3);
      _sortie = Float32List(_nbCanaux * _nbBoites);

      final contenuLabels = await rootBundle.loadString(labelsAsset);
      _labels = contenuLabels
          .split('\n')
          .map((l) => l.trim().toLowerCase())
          .where((l) => l.isNotEmpty)
          .toList();

      // Sécurité : si labels.txt ne correspond pas au modèle, chaque détection
      // porterait un faux nom. On refuse plutôt que d'afficher n'importe quoi.
      if (_labels.length != _nbCanaux - 4) {
        debugPrint(
          'ERREUR : labels.txt contient ${_labels.length} classes '
          'mais le modèle en sort ${_nbCanaux - 4}. Corriger labels.txt.',
        );
        _isLoaded = false;
        return false;
      }

      _isLoaded = true;
      debugPrint(
        'Modèle chargé : entrée $inShape (${_nchw ? "NCHW" : "NHWC"}), '
        'sortie $outShape, classes $_labels',
      );
      return true;
    } catch (e) {
      debugPrint('Impossible de charger le modèle TFLite : $e');
      _isLoaded = false;
      return false;
    }
  }

  /// Analyse une image de la caméra et renvoie les détections retenues.
  List<Detection> detecterSurFrame(
    CameraImage cameraImage, {
    int sensorOrientation = 90,
    bool isFrontCamera = false,
    double seuilConfiance = 0.50,
  }) {
    if (!_isLoaded || _interpreter == null) return [];

    try {
      // 1. Image caméra -> tampon d'entrée du modèle (rotation + letterbox + /255)
      final cadre = _preparerEntree(cameraImage, sensorOrientation, isFrontCamera);
      if (cadre == null) return [];

      // 2. Inférence : on copie le tampon dans le tenseur d'entrée, on lance le
      //    modèle, puis on relit les octets du tenseur de sortie.
      _interpreter!.getInputTensor(0).data = _entree.buffer.asUint8List();
      _interpreter!.invoke();
      final octets = _interpreter!.getOutputTensor(0).data;
      final lecture = ByteData.sublistView(octets);
      for (int i = 0; i < _sortie.length; i++) {
        _sortie[i] = lecture.getFloat32(i * 4, Endian.little);
      }

      // 3. Décodage des 8400 boîtes candidates, puis suppression des doublons
      final brutes = _decoder(cadre, seuilConfiance);
      return _appliquerNMS(brutes, iouThreshold: 0.45);
    } catch (e) {
      debugPrint('Erreur pendant la détection : $e');
      return [];
    }
  }

  /// Remplit [_entree] à partir de l'image caméra, en une seule passe :
  /// conversion YUV -> RGB, rotation selon le capteur, miroir éventuel,
  /// redimensionnement en gardant les proportions (letterbox, bandes grises
  /// 114 comme à l'entraînement) et normalisation entre 0 et 1.
  _Cadre? _preparerEntree(CameraImage image, int rotation, bool miroir) {
    final bool yuv = image.format.group == ImageFormatGroup.yuv420;
    final bool bgra = image.format.group == ImageFormatGroup.bgra8888;
    if (!yuv && !bgra) return null;

    final int w = image.width;
    final int h = image.height;
    final int rot = ((rotation % 360) + 360) % 360;
    final bool tourne = rot == 90 || rot == 270;
    final int rw = tourne ? h : w; // dimensions de l'image redressée
    final int rh = tourne ? w : h;

    final int s = _inputSize;
    final double echelle = min(s / rw, s / rh);
    final int nw = (rw * echelle).round();
    final int nh = (rh * echelle).round();
    final int padX = (s - nw) ~/ 2;
    final int padY = (s - nh) ~/ 2;

    _entree.fillRange(0, _entree.length, 114 / 255.0);

    final Uint8List p0 = image.planes[0].bytes;
    final int ligne0 = image.planes[0].bytesPerRow;
    Uint8List? pu;
    Uint8List? pv;
    int ligneUV = 0;
    int pasUV = 1;
    if (yuv) {
      pu = image.planes[1].bytes;
      pv = image.planes[2].bytes;
      ligneUV = image.planes[1].bytesPerRow;
      pasUV = image.planes[1].bytesPerPixel ?? 1;
    }

    final int plan = s * s;
    for (int oy = 0; oy < nh; oy++) {
      int ry = (oy / echelle).floor();
      if (ry >= rh) ry = rh - 1;
      for (int ox = 0; ox < nw; ox++) {
        int rx = (ox / echelle).floor();
        if (rx >= rw) rx = rw - 1;
        if (miroir) rx = rw - 1 - rx;

        // (rx, ry) dans l'image redressée -> (sx, sy) dans l'image du capteur
        int sx;
        int sy;
        switch (rot) {
          case 90:
            sx = ry;
            sy = h - 1 - rx;
            break;
          case 180:
            sx = w - 1 - rx;
            sy = h - 1 - ry;
            break;
          case 270:
            sx = w - 1 - ry;
            sy = rx;
            break;
          default:
            sx = rx;
            sy = ry;
        }

        double r;
        double g;
        double b;
        if (yuv) {
          final int yy = p0[sy * ligne0 + sx];
          final int iuv = (sy >> 1) * ligneUV + (sx >> 1) * pasUV;
          final int uu = pu![iuv] - 128;
          final int vv = pv![iuv] - 128;
          r = yy + 1.370705 * vv;
          g = yy - 0.337633 * uu - 0.698001 * vv;
          b = yy + 1.732446 * uu;
        } else {
          final int i = sy * ligne0 + sx * 4;
          b = p0[i].toDouble();
          g = p0[i + 1].toDouble();
          r = p0[i + 2].toDouble();
        }
        r = (r < 0 ? 0 : (r > 255 ? 255 : r)) / 255.0;
        g = (g < 0 ? 0 : (g > 255 ? 255 : g)) / 255.0;
        b = (b < 0 ? 0 : (b > 255 ? 255 : b)) / 255.0;

        final int px = padX + ox;
        final int py = padY + oy;
        if (_nchw) {
          final int k = py * s + px;
          _entree[k] = r;
          _entree[plan + k] = g;
          _entree[2 * plan + k] = b;
        } else {
          final int k = (py * s + px) * 3;
          _entree[k] = r;
          _entree[k + 1] = g;
          _entree[k + 2] = b;
        }
      }
    }
    return _Cadre(echelle, padX, padY, rw, rh);
  }

  /// Lit les 8400 boîtes candidates et garde celles dont la meilleure classe
  /// dépasse le seuil. Les coordonnées sont remises dans le repère de l'image
  /// redressée (sans les bandes grises), puis normalisées entre 0 et 1.
  List<Detection> _decoder(_Cadre c, double seuil) {
    final List<Detection> detections = [];
    final int nbClasses = _nbCanaux - 4;
    final double s = _inputSize.toDouble();

    double val(int canal, int i) => _sortieTransposee
        ? _sortie[i * _nbCanaux + canal]
        : _sortie[canal * _nbBoites + i];

    for (int i = 0; i < _nbBoites; i++) {
      double meilleur = 0.0;
      int classe = 0;
      for (int k = 0; k < nbClasses; k++) {
        final double score = val(4 + k, i);
        if (score > meilleur) {
          meilleur = score;
          classe = k;
        }
      }
      if (meilleur < seuil) continue;

      double cx = val(0, i);
      double cy = val(1, i);
      double bw = val(2, i);
      double bh = val(3, i);

      // Les exports récents sortent des coordonnées entre 0 et 1, les anciens
      // en pixels du modèle : on ramène tout en pixels du modèle.
      if (cx <= 1.5 && cy <= 1.5 && bw <= 1.5 && bh <= 1.5) {
        cx *= s;
        cy *= s;
        bw *= s;
        bh *= s;
      }

      // On retire les bandes grises et on revient à l'image redressée
      final double x1 = ((cx - bw / 2) - c.padX) / c.echelle / c.largeur;
      final double y1 = ((cy - bh / 2) - c.padY) / c.echelle / c.hauteur;
      final double x2 = ((cx + bw / 2) - c.padX) / c.echelle / c.largeur;
      final double y2 = ((cy + bh / 2) - c.padY) / c.echelle / c.hauteur;

      final double left = x1.clamp(0.0, 1.0);
      final double top = y1.clamp(0.0, 1.0);
      final double right = x2.clamp(0.0, 1.0);
      final double bottom = y2.clamp(0.0, 1.0);
      if (right <= left || bottom <= top) continue;

      final String id = _labels[classe];
      detections.add(
        Detection(
          idEquipement: id,
          label: _nomsAffichage[id] ?? id,
          confidence: meilleur,
          boundingBox: Rect.fromLTRB(left, top, right, bottom),
        ),
      );
    }
    return detections;
  }

  /// Supprime les boîtes en double : pour une même classe, on garde la plus sûre
  /// et on retire celles qui la recouvrent à plus de [iouThreshold].
  List<Detection> _appliquerNMS(List<Detection> detections, {double iouThreshold = 0.45}) {
    detections.sort((a, b) => b.confidence.compareTo(a.confidence));
    final List<Detection> retenues = [];
    for (final det in detections) {
      bool chevauchement = false;
      for (final gardee in retenues) {
        if (det.idEquipement == gardee.idEquipement &&
            _calculerIoU(det.boundingBox, gardee.boundingBox) > iouThreshold) {
          chevauchement = true;
          break;
        }
      }
      if (!chevauchement) retenues.add(det);
    }
    return retenues;
  }

  double _calculerIoU(Rect a, Rect b) {
    final inter = a.intersect(b);
    if (inter.width <= 0 || inter.height <= 0) return 0.0;
    final interArea = inter.width * inter.height;
    final unionArea = (a.width * a.height) + (b.width * b.height) - interArea;
    return unionArea <= 0 ? 0.0 : interArea / unionArea;
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isLoaded = false;
  }
}
