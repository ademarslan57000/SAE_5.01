import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../../modele/equipement.dart';
import '../../modele/detection.dart';
import '../../service/decision_service.dart';
import '../../service/historique_service.dart';
import '../../service/auth_service.dart';
import '../../service/tflite_service.dart';
import '../accueil.dart';
import '../historique/historique.dart';
import 'detection_overlay.dart';
import 'resultat_scan.dart';

class ScanScreen extends StatefulWidget {
  final List<CameraDescription>? cameras;
  final List<Equipement> equipementsRequis;

  const ScanScreen({super.key, this.cameras, required this.equipementsRequis});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _camIndex = 0;
  bool _isReady = false;
  bool _isSaving = false;
  String? _error;

  final TfliteService _tfliteService = TfliteService();
  bool _isDetecting = false;
  double _realFps = 0.0;

  List<Detection> _detections = [];
  bool _simulerCasque = false;
  bool _simulerGilet = false;

  final _stabilisateur = StabilisateurDecision(maxFrames: 5, minConfirmations: 3);

  @override
  void initState() {
    super.initState();
    _initTout();
  }

  Future<void> _initTout() async {
    await _tfliteService.chargerModele();
    await _initCamera();
  }

  Future<void> _initCamera() async {
    if (kIsWeb) return setState(() => _isReady = true);

    try {
      if (_cameras.isEmpty) {
        _cameras = (widget.cameras != null && widget.cameras!.isNotEmpty)
            ? widget.cameras!
            : await availableCameras();
      }
      if (_cameras.isEmpty) {
        return setState(() => _error = "Aucune caméra détectée.");
      }

      if (_controller != null) {
        if (_controller!.value.isStreamingImages) {
          await _controller!.stopImageStream();
        }
        await _controller!.dispose();
      }

      _controller = CameraController(
        _cameras[_camIndex],
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _controller!.initialize();
      try {
        await _controller!.setFlashMode(FlashMode.off);
      } catch (_) {}

      if (mounted) {
        setState(() {
          _isReady = true;
          _error = null;
        });
        _demarrerFluxIA();
      }
    } on CameraException catch (e) {
      if (mounted) setState(() => _error = "Erreur caméra : ${e.description}");
    }
  }

  void _demarrerFluxIA() {
    if (kIsWeb || !_tfliteService.isLoaded || _controller == null) return;
    if (_controller!.value.isStreamingImages) return;

    final cam = _cameras[_camIndex];
    final bool isFront = cam.lensDirection == CameraLensDirection.front;

    _controller!.startImageStream((CameraImage image) {
      if (_isDetecting || _isSaving || !mounted) return;
      _isDetecting = true;

      final sw = Stopwatch()..start();
      final resultats = _tfliteService.detecterSurFrame(
        image,
        sensorOrientation: cam.sensorOrientation,
        isFrontCamera: isFront,
        seuilConfiance: seuilConfiance,
      );
      sw.stop();

      if (mounted) {
        final double fps = sw.elapsedMilliseconds > 0
            ? (1000.0 / sw.elapsedMilliseconds).clamp(1.0, 60.0)
            : 30.0;
        setState(() {
          _detections = resultats;
          _realFps = fps;
        });
      }

      _isDetecting = false;
    });
  }

  void _switchCamera() {
    if (_cameras.length < 2) return;

    final currentDirection = _cameras[_camIndex].lensDirection;
    final targetDirection = currentDirection == CameraLensDirection.back
        ? CameraLensDirection.front
        : CameraLensDirection.back;

    final newIndex = _cameras.indexWhere((c) => c.lensDirection == targetDirection);

    setState(() {
      _isReady = false;
      _camIndex = newIndex != -1 ? newIndex : (_camIndex + 1) % _cameras.length;
    });

    _initCamera();
  }

  void _updateSimulations() {
    setState(() {
      _detections = [
        if (_simulerCasque)
          Detection(
            idEquipement: 'helmet',
            label: 'Casque',
            confidence: 0.94,
            boundingBox: const Rect.fromLTWH(0.32, 0.16, 0.36, 0.18),
          ),
        if (_simulerGilet)
          Detection(
            idEquipement: 'vest',
            label: 'Gilet HV',
            confidence: 0.91,
            boundingBox: const Rect.fromLTWH(0.26, 0.38, 0.48, 0.32),
          ),
      ];

      for (int i = 0; i < 3; i++) {
        _stabilisateur.deciderStable(_detections, widget.equipementsRequis);
      }
    });
  }

  @override
  void dispose() {
    if (_controller != null && _controller!.value.isStreamingImages) {
      _controller!.stopImageStream();
    }
    _controller?.dispose();
    _tfliteService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: Text(_error!, style: const TextStyle(color: Colors.white))),
      );
    }
    if (!_isReady) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final resultat = _stabilisateur.deciderStable(_detections, widget.equipementsRequis);
    final bool conforme = widget.equipementsRequis.isNotEmpty && resultat.accesAutorise;
    bool isDetectedStable(Equipement eq) => resultat.detectes.containsKey(eq.id);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_controller?.value.isInitialized ?? false)
            CameraPreview(_controller!)
          else
            const ColoredBox(color: Colors.black),

          if (_detections.isNotEmpty)
            IgnorePointer(
              child: DetectionOverlay(
                detections: _detections,
                idsRequis: widget.equipementsRequis.map((e) => e.id.toLowerCase()).toSet(),
              ),
            ),

          Center(
            child: IgnorePointer(
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.75,
                height: MediaQuery.of(context).size.height * 0.55,
                child: CustomPaint(
                  painter: _ViseurPainter(conforme ? Colors.greenAccent : Colors.white38),
                ),
              ),
            ),
          ),

          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _RoundButton(
                  icon: Icons.arrow_back,
                  onTap: () {
                    AuthService.utilisateurCourant = null;
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const AccueilScreen()),
                      (Route<dynamic> route) => false,
                    );
                  },
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (_tfliteService.isLoaded ? Colors.greenAccent : Colors.orangeAccent)
                          .withValues(alpha: 0.7),
                    ),
                  ),
                  child: Text(
                    _tfliteService.isLoaded
                        ? 'IA v2 • ${_realFps.toStringAsFixed(1)} FPS'
                        : 'MODE SECOURS (sans .tflite)',
                    style: TextStyle(
                      color: _tfliteService.isLoaded ? Colors.greenAccent : Colors.orangeAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Row(
                  children: [
                    _RoundButton(
                      icon: Icons.history,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen())),
                    ),
                    if (_cameras.length > 1) ...[
                      const SizedBox(width: 8),
                      _RoundButton(icon: Icons.flip_camera_ios, onTap: _switchCamera),
                    ],
                  ],
                ),
              ],
            ),
          ),

          Positioned(
            top: MediaQuery.of(context).padding.top + 65,
            left: 16,
            right: 16,
            child: _StatusCard(
              equipements: widget.equipementsRequis,
              isDetected: isDetectedStable,
              conforme: conforme,
            ),
          ),

          Positioned(
            bottom: 24,
            left: 20,
            right: 20,
            child: Column(
              children: [
                // Boutons de simulation affichés uniquement si le fichier .tflite n'est pas chargé
                if (!_tfliteService.isLoaded) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _TagButton(
                        label: 'Casque',
                        active: _simulerCasque,
                        onTap: () {
                          _simulerCasque = !_simulerCasque;
                          _updateSimulations();
                        },
                      ),
                      const SizedBox(width: 8),
                      _TagButton(
                        label: 'Gilet',
                        active: _simulerGilet,
                        onTap: () {
                          _simulerGilet = !_simulerGilet;
                          _updateSimulations();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: conforme ? Colors.green : Colors.red[700],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Icon(conforme ? Icons.check : Icons.lock_outline, color: Colors.white),
                    label: Text(
                      _isSaving ? 'Sauvegarde...' : (conforme ? 'Valider le passage' : 'Vérifier l\'accès'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    onPressed: _isSaving
                        ? null
                        : () async {
                            setState(() => _isSaving = true);
                            final detectionsSnapshot = List<Detection>.from(_detections);

                            try {
                              String? rawPath;

                              try {
                                if (!kIsWeb && _controller != null && _controller!.value.isInitialized) {
                                  if (_controller!.value.isStreamingImages) {
                                    await _controller!.stopImageStream();
                                  }
                                  final photo = await _controller!.takePicture().timeout(const Duration(milliseconds: 1000));
                                  rawPath = photo.path;
                                }
                              } catch (e) {
                                debugPrint("Caméra trop lente ou erreur ignorée : $e");
                              }

                              final idsRequis = widget.equipementsRequis.map((e) => e.id.toLowerCase()).toSet();

                              final savedImagePath = await HistoriqueService.sauvegarderImageAvecBoites(
                                rawImagePath: rawPath,
                                detections: detectionsSnapshot,
                                idsRequis: idsRequis,
                              );

                              await HistoriqueService.enregistrerPassage(
                                resultat,
                                widget.equipementsRequis,
                                1,
                                seuilConfiance,
                                'model-v2-tflite',
                                cheminImage: savedImagePath,
                                utilisateurId: AuthService.utilisateurCourant?.id,
                              );

                              if (mounted) {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ResultatScanScreen(
                                      equipementsRequis: widget.equipementsRequis,
                                      detections: detectionsSnapshot,
                                    ),
                                  ),
                                );
                                _demarrerFluxIA();
                              }
                            } catch (e) {
                              debugPrint("Erreur de sauvegarde : $e");
                            } finally {
                              if (mounted) setState(() => _isSaving = false);
                            }
                          },
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

class _StatusCard extends StatelessWidget {
  final List<Equipement> equipements;
  final bool Function(Equipement) isDetected;
  final bool conforme;

  const _StatusCard({required this.equipements, required this.isDetected, required this.conforme});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          color: Colors.black38,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'ÉQUIPEMENTS REQUIS',
                    style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    conforme ? 'CONFORME' : 'NON CONFORME',
                    style: TextStyle(
                      color: conforme ? Colors.greenAccent : Colors.orangeAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: equipements.map((eq) {
                  final active = isDetected(eq);
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: active ? Colors.green.withValues(alpha: 0.25) : Colors.red.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: active ? Colors.greenAccent : Colors.redAccent, width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(active ? Icons.check : Icons.close, size: 13, color: active ? Colors.greenAccent : Colors.redAccent),
                        const SizedBox(width: 4),
                        Text('${eq.icon} ${eq.nom}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
      child: IconButton(icon: Icon(icon, color: Colors.white, size: 20), onPressed: onTap),
    );
  }
}

class _TagButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TagButton({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      backgroundColor: active ? Colors.white24 : Colors.black45,
      side: BorderSide(color: active ? Colors.white : Colors.white24),
      label: Text(label, style: TextStyle(color: active ? Colors.white : Colors.white60, fontSize: 11)),
      onPressed: onTap,
    );
  }
}

class _ViseurPainter extends CustomPainter {
  final Color color;
  _ViseurPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    const l = 24.0;
    canvas.drawLine(Offset.zero, const Offset(l, 0), p);
    canvas.drawLine(Offset.zero, const Offset(0, l), p);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - l, 0), p);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, l), p);
    canvas.drawLine(Offset(0, size.height), Offset(l, size.height), p);
    canvas.drawLine(Offset(0, size.height), Offset(0, size.height - l), p);
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width - l, size.height), p);
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width, size.height - l), p);
  }

  @override
  bool shouldRepaint(covariant _ViseurPainter oldDelegate) => oldDelegate.color != color;
}