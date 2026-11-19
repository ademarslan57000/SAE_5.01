// Écran d'accueil : choix Ouvrier / Admin, puis saisie du code PIN.
// Le PIN doit correspondre à un utilisateur de la base ayant le rôle choisi.
// Ouvrier -> interface de scan uniquement ; Admin -> interface complète (scan, config, historique).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'navigation.dart';
import '../service/auth_service.dart';

class AccueilScreen extends StatefulWidget {
  const AccueilScreen({super.key});

  @override
  State<AccueilScreen> createState() => _AccueilScreenState();
}

class _AccueilScreenState extends State<AccueilScreen> {
  String? _role; // null = écran de choix, sinon 'ouvrier' ou 'admin'
  final TextEditingController _prenomController = TextEditingController();
  final TextEditingController _nomController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  String? _erreur;
  bool _verification = false;

  @override
  void dispose() {
    _prenomController.dispose();
    _nomController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _choisirRole(String role) {
    setState(() {
      _role = role;
      _erreur = null;
      _prenomController.clear();
      _nomController.clear();
      _pinController.clear();
    });
  }

  Future<void> _seConnecter() async {
    final prenom = _prenomController.text.trim();
    final nom = _nomController.text.trim();
    final pin = _pinController.text;
    if (prenom.isEmpty || nom.isEmpty) {
      setState(() => _erreur = 'Saisissez votre prénom et votre nom.');
      return;
    }
    if (pin.length < 4) {
      setState(() => _erreur = 'Le PIN doit contenir au moins 4 chiffres.');
      return;
    }

    setState(() {
      _verification = true;
      _erreur = null;
    });

    final utilisateur = await AuthService.connecterParIdentite(
      prenom: prenom,
      nom: nom,
      pin: pin,
      role: _role!,
    );
    if (!mounted) return;

    if (utilisateur == null) {
      _pinController.clear();
      setState(() {
        _verification = false;
        _erreur = 'Identifiants incorrects.';
      });
      return;
    }

    AuthService.utilisateurCourant = utilisateur;
    setState(() => _verification = false);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const NavigationScreen()),
    );
  }

  Widget _buildChoix() {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 120,
          child: ElevatedButton.icon(
            onPressed: () => _choisirRole('ouvrier'),
            icon: const Icon(Icons.construction, size: 40),
            label: const Text(
              'Ouvrier',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 120,
          child: ElevatedButton.icon(
            onPressed: () => _choisirRole('admin'),
            icon: const Icon(Icons.admin_panel_settings, size: 40),
            label: const Text(
              'Admin',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.surfaceContainerHighest,
              foregroundColor: cs.onSurface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaisiePin() {
    final estAdmin = _role == 'admin';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          estAdmin ? 'Espace Admin' : 'Espace Ouvrier',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _prenomController,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: 'Prénom',
            prefixIcon: const Icon(Icons.person),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _nomController,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: 'Nom',
            prefixIcon: const Icon(Icons.badge),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _pinController,
          obscureText: true,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(fontSize: 22, letterSpacing: 6),
          decoration: InputDecoration(
            labelText: 'Code PIN',
            prefixIcon: const Icon(Icons.lock),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            errorText: _erreur,
            counterText: '',
          ),
          onSubmitted: (_) => _seConnecter(),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _verification ? null : _seConnecter,
            icon: _verification
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.login),
            label: const Text(
              'Valider',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => setState(() => _role = null),
          child: const Text('Retour'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.security,
                  size: 70,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Portique de Sécurité EPI',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                _role == null ? _buildChoix() : _buildSaisiePin(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
