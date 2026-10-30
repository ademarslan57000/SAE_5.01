// Point d'entrée de l'application : initialise le moteur Flutter
// et configure le thème visuel sombre avant d'instancier l'écran de navigation principal.

import 'package:flutter/material.dart';
import 'vue/navigation.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
      home: const NavigationScreen(),
    );
  }
}