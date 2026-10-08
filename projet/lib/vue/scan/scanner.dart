import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:projet/modele/equipement.dart';

class ScanScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final List<Equipement> equipementsRequis;
  
  const ScanScreen({
    super.key, 
    required this.cameras, 
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

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    if (widget.cameras.isEmpty){
      setState(() => _errorMessage = "Aucune caméra détectée sur cet appareil");
      return;
    }

    setState(() => _isCameraReady = false);
    await _controller?.dispose();

    _controller = CameraController(
      widget.cameras[_selectedCameraIndex],
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
      setState(() => _errorMessage = "Erreur caméra : ${e.description}");
    }
  }

  void _switchCamera() {
    if (widget.cameras.length < 2) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % widget.cameras.length;
    _initCamera();
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
        appBar: AppBar(title: const Text("Portique de Détection EPI")),
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

    if (!_isCameraReady || _controller == null){
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Portique de Détection EPI'),
        actions: [
          if (widget.cameras.length > 1)
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
          CameraPreview(_controller!),
          Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.8,
              height: MediaQuery.of(context).size.height * 0.6,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white70,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'Placez la personne dans le cadre',
                    style: TextStyle(color: Colors.white, 
                    backgroundColor: Colors.black54,
                    fontWeight: FontWeight.bold
                    ),
                  ),
                ),
              ),
            ),
          ),

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
                : "Requis : ${widget.equipementsRequis.map((e) => e.icon).join(" ")}",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}