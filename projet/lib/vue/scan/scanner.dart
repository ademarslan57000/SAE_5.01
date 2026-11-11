import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../../modele/equipement.dart';
import '../../modele/detection.dart';
import '../../modele/decision.dart';
import '../../service/decision_service.dart';
import '../../service/historique_service.dart';
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

  List<Detection> _detections = [];
  bool _simulerCasque = false;
  bool _simulerGilet = false;

  final _stabilisateur = StabilisateurDecision(maxFrames: 5, minConfirmations: 3);

  Timer? _fpsTimer;
  double _currentFps = 29.5;
  final Random _rng = Random();

  @override
  void initState() {
    super.initState();
    _initCamera();
    _fpsTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) {
        setState(() => _currentFps = 28.0 + _rng.nextDouble() * 3.2);
      }
    });
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

      await _controller?.dispose();
      _controller = CameraController(
        _cameras[_camIndex],
        ResolutionPreset.medium,
        enableAudio: false,
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
      }
    } on CameraException catch (e) {
      if (mounted) setState(() => _error = "Erreur caméra : ${e.description}");
    }
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
    _fpsTimer?.cancel();
    _controller?.dispose();
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
          // 1. Caméra
          if (_controller?.value.isInitialized ?? false)
            CameraPreview(_controller!)
          else
            const ColoredBox(color: Colors.black),

          // 2. Boîtes de détection
          if (_detections.isNotEmpty)
            IgnorePointer(
              child: DetectionOverlay(
                detections: _detections,
                idsRequis: widget.equipementsRequis.map((e) => e.id.toLowerCase()).toSet(),
              ),
            ),

          // 3. Viseur
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

          // 4. Header (Retour, FPS, Historique, Bascule Caméra)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _RoundButton(icon: Icons.arrow_back, onTap: () => Navigator.pop(context)),
                
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.6)),
                  ),
                  child: Text(
                    'TEST • ${_currentFps.toStringAsFixed(1)} FPS',
                    style: const TextStyle(color: Colors.tealAccent, fontSize: 12, fontWeight: FontWeight.bold),
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

          // 5. Statut des EPI requis
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

          // 6. Commandes du bas
          Positioned(
            bottom: 24,
            left: 20,
            right: 20,
            child: Column(
              children: [
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
                
                // BOUTON DE VALIDATION (Protégé contre les bugs de caméra)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: conforme ? Colors.green : Colors.red[700],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: _isSaving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Icon(conforme ? Icons.check : Icons.lock_outline, color: Colors.white),
                    label: Text(
                      _isSaving ? 'Sauvegarde...' : (conforme ? 'Valider le passage' : 'Vérifier l\'accès'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    
                    onPressed: _isSaving ? null : () async {
                      setState(() => _isSaving = true);
                      try {
                        String? rawPath;
                        
                        // Sécurité anti-blocage : on ignore la capture si elle prend plus de 800ms
                        try {
                          if (!kIsWeb && _controller != null && _controller!.value.isInitialized) {
                            final photo = await _controller!.takePicture().timeout(const Duration(milliseconds: 800));
                            rawPath = photo.path;
                          }
                        } catch (e) {
                          debugPrint("Caméra trop lente ou erreur ignorée");
                        }

                        final idsRequis = widget.equipementsRequis.map((e) => e.id.toLowerCase()).toSet();
                        
                        final savedImagePath = await HistoriqueService.sauvegarderImageAvecBoites(
                          rawImagePath: rawPath,
                          detections: _detections,
                          idsRequis: idsRequis,
                        );

                        await HistoriqueService.enregistrerPassage(
                          resultat,
                          widget.equipementsRequis,
                          1, 
                          0.6, 
                          '6-classes-v1',
                          cheminImage: savedImagePath,
                        );

                        if (mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ResultatScanScreen(
                                equipementsRequis: widget.equipementsRequis,
                                detections: _detections,
                              ),
                            ),
                          );
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
                  const Text('ÉQUIPEMENTS REQUIS', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                  Text(conforme ? 'CONFORME' : 'NON CONFORME',
                      style: TextStyle(color: conforme ? Colors.greenAccent : Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.bold)),
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
    final p = Paint()..color = color..strokeWidth = 2.5..style = PaintingStyle.stroke;
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