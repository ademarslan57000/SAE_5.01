import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'vue/navigation.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    debugPrint('Erreur lors de l\'initialisation des caméras : $e');
  }

  runApp(const EPISafetyApp());
}

class EPISafetyApp extends StatelessWidget {
  const EPISafetyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scan protection',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.amber, 
        brightness: Brightness.dark,
      ),
      home: NavigationScreen(cameras: cameras),
    );
  }
}