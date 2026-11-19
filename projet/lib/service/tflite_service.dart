import 'dart:math';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import '../modele/detection.dart';

class TfliteService {
  Interpreter? _interpreter;
  List<String> _labels = [];
  int _inputSize = 640;
  bool _isQuantized = false;
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;

  static const Map<String, String> _nomsAffichage = {
    'helmet': 'Casque',
    'vest': 'Gilet HV',
    'gloves': 'Gants',
    'boots': 'Chaussures',
    'goggles': 'Lunettes',
    'ears': 'Casque audio',
    'harness': 'Harnais',
    'mask': 'Masque',
    'person': 'Personne',
  };

  /// Charge le modèle TFLite v2 et les classes depuis assets/
  Future<bool> chargerModele({
    String modelAsset = 'assets/best.tflite',
    String labelsAsset = 'assets/labels.txt',
  }) async {
    try {
      final options = InterpreterOptions()..threads = 4;
      _interpreter = await Interpreter.fromAsset(modelAsset, options: options);

      final inputTensor = _interpreter!.getInputTensor(0);
      _inputSize = inputTensor.shape[1]; // ex: 640 ou 320
      _isQuantized = inputTensor.type == TensorType.uint8;

      final contenuLabels = await rootBundle.loadString(labelsAsset);
      _labels = contenuLabels
          .split('\n')
          .map((l) => l.trim().toLowerCase())
          .where((l) => l.isNotEmpty)
          .toList();

      _isLoaded = true;
      debugPrint(
        'Modèle TFLite v2 chargé (entrée: ${_inputSize}x$_inputSize, classes: $_labels)',
      );
      return true;
    } catch (e) {
      debugPrint('Impossible de charger le modèle TFLite : $e');
      _isLoaded = false;
      return false;
    }
  }

  /// Exécute la détection IA sur une frame de la caméra
  List<Detection> detecterSurFrame(
    CameraImage cameraImage, {
    int sensorOrientation = 90,
    bool isFrontCamera = false,
    double seuilConfiance = 0.50,
  }) {
    if (!_isLoaded || _interpreter == null || _labels.isEmpty) {
      return [];
    }

    // 1. Conversion CameraImage -> img.Image RGB
    img.Image? rgbImage = _convertirCameraImage(cameraImage);
    if (rgbImage == null) return [];

    // 2. Rotation selon l'orientation du capteur téléphone
    if (sensorOrientation != 0) {
      rgbImage = img.copyRotate(rgbImage, angle: sensorOrientation);
    }
    if (isFrontCamera) {
      rgbImage = img.flipHorizontal(rgbImage);
    }

    // 3. Redimensionnement à la taille attendue par le modèle (ex: 640x640)
    final resized = img.copyResize(
      rgbImage,
      width: _inputSize,
      height: _inputSize,
    );

    // 4. Construction du tenseur d'entrée [1, H, W, 3]
    final input = _creerTenseurEntree(resized);

    // 5. Préparation des tenseurs de sortie et inférence
    final outputTensors = _interpreter!.getOutputTensors();
    final List<Detection> brutes = [];

    if (outputTensors.length == 1) {
      // Format YOLO (v8 / v11) : [1, 4 + nbClasses, nbBoites] ou [1, nbBoites, 4 + nbClasses]
      final shape = outputTensors[0].shape;
      final output = List.generate(
        shape[0],
        (_) => List.generate(
          shape[1],
          (_) => List<double>.filled(shape[2], 0.0),
        ),
      );

      _interpreter!.run(input, output);
      brutes.addAll(_decoderSortieYolo(output[0], shape, seuilConfiance));
    } else if (outputTensors.length >= 3) {
      // Format SSD MobileNet : boxes [1, N, 4], classes [1, N], scores [1, N]
      final numDetections = outputTensors[1].shape[1];
      final boxes = List.generate(
        1,
        (_) => List.generate(numDetections, (_) => List<double>.filled(4, 0.0)),
      );
      final classes = List.generate(1, (_) => List<double>.filled(numDetections, 0.0));
      final scores = List.generate(1, (_) => List<double>.filled(numDetections, 0.0));
      final count = List<double>.filled(1, 0.0);

      final outputs = <int, Object>{
        0: boxes,
        1: classes,
        2: scores,
        if (outputTensors.length >= 4) 3: count,
      };

      _interpreter!.runForMultipleInputs([input], outputs);
      brutes.addAll(_decoderSortieSsd(boxes[0], classes[0], scores[0], seuilConfiance));
    }

    // 6. Suppression des boîtes superposées (Non-Maximum Suppression)
    return _appliquerNMS(brutes, iouThreshold: 0.45);
  }

  Object _creerTenseurEntree(img.Image image) {
    if (_isQuantized) {
      return [
        List.generate(
          _inputSize,
          (y) => List.generate(_inputSize, (x) {
            final p = image.getPixel(x, y);
            return [p.r.toInt(), p.g.toInt(), p.b.toInt()];
          }),
        ),
      ];
    } else {
      return [
        List.generate(
          _inputSize,
          (y) => List.generate(_inputSize, (x) {
            final p = image.getPixel(x, y);
            return [p.r / 255.0, p.g / 255.0, p.b / 255.0];
          }),
        ),
      ];
    }
  }

  List<Detection> _decoderSortieYolo(
    List<List<double>> matrice,
    List<int> shape,
    double seuil,
  ) {
    final List<Detection> detections = [];
    // YOLOv8/v11 exporte généralement [1, 4 + C, N] (ex: [1, 10, 8400])
    final bool transpose = shape[1] < shape[2];
    final int nbBoites = transpose ? shape[2] : shape[1];
    final int nbCanaux = transpose ? shape[1] : shape[2];
    final int nbClasses = min(_labels.length, nbCanaux - 4);

    if (nbClasses <= 0) return detections;

    for (int i = 0; i < nbBoites; i++) {
      double maxScore = 0.0;
      int bestClassIdx = 0;

      for (int c = 0; c < nbClasses; c++) {
        final double score = transpose ? matrice[4 + c][i] : matrice[i][4 + c];
        if (score > maxScore) {
          maxScore = score;
          bestClassIdx = c;
        }
      }

      if (maxScore < seuil) continue;

      double cx = transpose ? matrice[0][i] : matrice[i][0];
      double cy = transpose ? matrice[1][i] : matrice[i][1];
      double w = transpose ? matrice[2][i] : matrice[i][2];
      double h = transpose ? matrice[3][i] : matrice[i][3];

      // Si le modèle sort des pixels [0..640] au lieu de [0..1], on normalise
      if (w > 1.5 || h > 1.5) {
        cx /= _inputSize;
        cy /= _inputSize;
        w /= _inputSize;
        h /= _inputSize;
      }

      final double left = (cx - w / 2).clamp(0.0, 1.0);
      final double top = (cy - h / 2).clamp(0.0, 1.0);
      final double width = w.clamp(0.0, 1.0 - left);
      final double height = h.clamp(0.0, 1.0 - top);

      final String classId = _labels[bestClassIdx];
      detections.add(
        Detection(
          idEquipement: classId,
          label: _nomsAffichage[classId] ?? classId,
          confidence: maxScore,
          boundingBox: Rect.fromLTWH(left, top, width, height),
        ),
      );
    }

    return detections;
  }

  List<Detection> _decoderSortieSsd(
    List<List<double>> boxes,
    List<double> classes,
    List<double> scores,
    double seuil,
  ) {
    final List<Detection> detections = [];
    for (int i = 0; i < scores.length; i++) {
      if (scores[i] < seuil) continue;
      final int classIdx = classes[i].round();
      if (classIdx < 0 || classIdx >= _labels.length) continue;

      // SSD renvoie [ymin, xmin, ymax, xmax] normalisés
      final double top = boxes[i][0].clamp(0.0, 1.0);
      final double left = boxes[i][1].clamp(0.0, 1.0);
      final double bottom = boxes[i][2].clamp(0.0, 1.0);
      final double right = boxes[i][3].clamp(0.0, 1.0);

      final String classId = _labels[classIdx];
      detections.add(
        Detection(
          idEquipement: classId,
          label: _nomsAffichage[classId] ?? classId,
          confidence: scores[i],
          boundingBox: Rect.fromLTWH(
            left,
            top,
            (right - left).clamp(0.0, 1.0),
            (bottom - top).clamp(0.0, 1.0),
          ),
        ),
      );
    }
    return detections;
  }

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
      if (!chevauchement) {
        retenues.add(det);
      }
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

  img.Image? _convertirCameraImage(CameraImage image) {
    try {
      if (image.format.group == ImageFormatGroup.bgra8888) {
        final plane = image.planes[0];
        return img.Image.fromBytes(
          width: image.width,
          height: image.height,
          bytes: plane.bytes.buffer,
          order: img.ChannelOrder.bgra,
        );
      }

      if (image.format.group == ImageFormatGroup.yuv420) {
        final int width = image.width;
        final int height = image.height;
        final out = img.Image(width: width, height: height);

        final yPlane = image.planes[0].bytes;
        final uPlane = image.planes[1].bytes;
        final vPlane = image.planes[2].bytes;

        final int yRowStride = image.planes[0].bytesPerRow;
        final int uvRowStride = image.planes[1].bytesPerRow;
        final int uvPixelStride = image.planes[1].bytesPerPixel ?? 1;

        for (int y = 0; y < height; y++) {
          final int yRowOffset = y * yRowStride;
          final int uvRowOffset = (y >> 1) * uvRowStride;

          for (int x = 0; x < width; x++) {
            final int yVal = yPlane[yRowOffset + x];
            final int uvIndex = uvRowOffset + (x >> 1) * uvPixelStride;
            final int uVal = uPlane[uvIndex];
            final int vVal = vPlane[uvIndex];

            final int r = (yVal + 1.370705 * (vVal - 128)).round().clamp(0, 255);
            final int g = (yVal - 0.337633 * (uVal - 128) - 0.698001 * (vVal - 128)).round().clamp(0, 255);
            final int b = (yVal + 1.732446 * (uVal - 128)).round().clamp(0, 255);

            out.setPixelRgb(x, y, r, g, b);
          }
        }
        return out;
      }
    } catch (e) {
      debugPrint('Erreur conversion image caméra : $e');
    }
    return null;
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isLoaded = false;
  }
}