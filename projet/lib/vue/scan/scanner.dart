// Vue centrale du portique affichant le flux vidéo de la caméra en temps réel,
// superposant le calque graphique des détections et déclenchant le passage vers l'écran de résultat.

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import '../../modele/equipement.dart';
import '../../modele/detection.dart';
import 'detection_overlay.dart';
import 'resultat_scan.dart';

class ScanScreen extends StatefulWidget {
  final List<CameraDescription>? cameras;
  final List<Equipement> equipementsRequis;

  const ScanScreen({
    super.key,
    this.cameras,
    required this.equipementsRequis,
  });

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  CameraController? _controller;
  final ImagePicker _picker = ImagePicker();
  int _selectedCameraIndex = 0;
  bool _isCameraReady = false;
  String? _errorMessage;

  List<Detection> _detectionsActives = [];
  bool _simulationActive = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    setState(() => _isCameraReady = false);

    // 1. Récupère les caméras passées en paramètre, ou interroge directement l'appareil
    List<CameraDescription> list = widget.cameras ?? [];
    if (list.isEmpty) {
      try {
        list = await availableCameras();
      } catch (e) {
        if (!mounted) return;
        setState(() => _errorMessage = "Erreur d'accès aux capteurs : $e");
        return;
      }
    }

    if (list.isEmpty) {
      if (!mounted) return;
      setState(() => _errorMessage = "Aucune caméra détectée sur cet appareil.");
      return;
    }

    await _controller?.dispose();

    // 2. Initialisation du capteur sélectionné
    _controller = CameraController(
      list[_selectedCameraIndex],
      ResolutionPreset.medium,
      enableAudio: false,
    );

    try {
      await _controller!.initialize();
      if (!mounted) return;
      setState(() {
        _isCameraReady = true;
        _errorMessage = null;
      });
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = "Erreur caméra : ${e.description}");
    }
  }

  void _switchCamera() {
    final list = widget.cameras;
    if (list == null || list.length < 2) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % list.length;
    _initCamera();
  }

  // Active ou désactive les détections simulées en s'adaptant aux EPI requis
  void _toggleSimulationDetections() {
    setState(() {
      _simulationActive = !_simulationActive;
      if (_simulationActive) {
        double topOffset = 0.18;
        _detectionsActives = widget.equipementsRequis.map((equip) {
          final det = Detection(
            idEquipement: equip.id.toLowerCase(),
            label: equip.nom,
            confidence: 0.93,
            boundingBox: Rect.fromLTWH(0.28, topOffset, 0.44, 0.18),
          );
          topOffset = (topOffset + 0.22).clamp(0.15, 0.75);
          return det;
        }).toList();

        // Si aucun équipement n'est encore coché, détections par défaut
        if (_detectionsActives.isEmpty) {
          _detectionsActives = [
            Detection(
              idEquipement: 'helmet',
              label: 'Casque',
              confidence: 0.95,
              boundingBox: const Rect.fromLTWH(0.32, 0.18, 0.36, 0.16),
            ),
            Detection(
              idEquipement: 'vest',
              label: 'Gilet HV',
              confidence: 0.91,
              boundingBox: const Rect.fromLTWH(0.24, 0.38, 0.52, 0.30),
            ),
            Detection(
              idEquipement: 'boots',
              label: 'Chaussures',
              confidence: 0.87,
              boundingBox: const Rect.fromLTWH(0.28, 0.72, 0.44, 0.12),
            ),
          ];
        }
      } else {
        _detectionsActives = [];
      }
    });
  }

  void _ouvrirResultatControle() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ResultatScanScreen(
          equipementsRequis: widget.equipementsRequis,
          detections: _detectionsActives,
        ),
      ),
    );
  }

  Future<void> _pickImageFromGallery() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image sélectionnée : ${image.name}')),
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Portique de Détection EPI')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent, fontSize: 16),
            ),
          ),
        ),
      );
    }

    if (!_isCameraReady || _controller == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final Set<String> idsRequis =
        widget.equipementsRequis.map((e) => e.id.toLowerCase()).toSet();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Portique de Détection EPI'),
        actions: [
          if ((widget.cameras?.length ?? 0) > 1)
            IconButton(
              icon: const Icon(Icons.flip_camera_ios),
              tooltip: 'Changer de caméra',
              onPressed: _switchCamera,
            ),
          IconButton(
            icon: const Icon(Icons.photo_library),
            tooltip: 'Ouvrir la galerie',
            onPressed: _pickImageFromGallery,
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Flux vidéo caméra Flutter
          CameraPreview(_controller!),

          // 2. Cadre repère visuel
          Center(
            child: IgnorePointer(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.8,
                height: MediaQuery.of(context).size.height * 0.6,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white54, width: 2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      'Placez la personne dans le cadre',
                      style: TextStyle(
                        color: Colors.white,
                        backgroundColor: Colors.black54,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 3. Calque de dessin des boîtes (vert si requis, bleu si facultatif)
          if (_detectionsActives.isNotEmpty)
            IgnorePointer(
              child: DetectionOverlay(
                detections: _detectionsActives,
                idsRequis: idsRequis,
              ),
            ),

          // 4. Bandeau des EPI obligatoires requis
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                widget.equipementsRequis.isEmpty
                    ? "Aucun EPI obligatoire configuré."
                    : "Requis : ${widget.equipementsRequis.map((e) => "${e.icon} ${e.nom}").join(" • ")}",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ),

          // 5. Boutons de simulation et de verdict
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      backgroundColor:
                          _simulationActive ? Colors.amber : Colors.black87,
                      foregroundColor:
                          _simulationActive ? Colors.black : Colors.white,
                      side: const BorderSide(color: Colors.amber),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: Icon(
                      _simulationActive
                          ? Icons.visibility_off
                          : Icons.center_focus_strong,
                    ),
                    label: Text(
                      _simulationActive ? 'Masquer IA' : 'Simuler IA',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: _toggleSimulationDetections,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.verified_user),
                    label: const Text(
                      'Vérifier l\'accès',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: _ouvrirResultatControle,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}