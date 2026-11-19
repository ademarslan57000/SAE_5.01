import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'navigation.dart';
import '../modele/utilisateur.dart';
import '../service/auth_service.dart';

class AccueilScreen extends StatefulWidget {
  const AccueilScreen({super.key});

  @override
  State<AccueilScreen> createState() => _AccueilScreenState();
}

class _AccueilScreenState extends State<AccueilScreen> {
  bool _modeInscription = false;

  List<Utilisateur> _comptes = [];
  Utilisateur? _compteSelectionne;
  final TextEditingController _pinLoginController = TextEditingController();
  String? _errorLogin;
  bool _isLoading = true;

  final _formInscriptionKey = GlobalKey<FormState>();
  final TextEditingController _nomController = TextEditingController();
  final TextEditingController _prenomController = TextEditingController();
  final TextEditingController _pinRegisterController = TextEditingController();
  String _roleSelectionne = 'ouvrier';

  @override
  void initState() {
    super.initState();
    _chargerComptesRobustes();
  }

  // MÉTHODE ROBUSTE ANTI-BLOCAGE
  Future<void> _chargerComptesRobustes() async {
    setState(() => _isLoading = true);

    try {
      if (kIsWeb) {
        // En mode web, SQLite peut bloquer. On utilise des comptes en dur.
        _comptes = [
          Utilisateur(
            id: 1,
            nom: 'Admin',
            prenom: 'Super (Web)',
            role: 'admin',
            pin: '1234',
          ),
          Utilisateur(
            id: 2,
            nom: 'Dupont',
            prenom: 'Jean (Web)',
            role: 'ouvrier',
            pin: '0000',
          ),
        ];
      } else {
        // On met un délai maximum de 2 secondes pour ne pas bloquer l'app
        final comptes = await AuthService.getComptes().timeout(
          const Duration(seconds: 2),
          onTimeout: () {
            debugPrint("Timeout de la base de données");
            return [
              Utilisateur(
                id: 1,
                nom: 'Admin',
                prenom: 'Mode Secours',
                role: 'admin',
                pin: '1234',
              ),
            ];
          },
        );
        _comptes = comptes;
      }
    } catch (e) {
      debugPrint("Erreur BDD au démarrage : $e");
      _comptes = [
        Utilisateur(
          id: 1,
          nom: 'Admin',
          prenom: 'Erreur BDD',
          role: 'admin',
          pin: '1234',
        ),
      ];
    } finally {
      // Ce bloc FINALLY garantit que le chargement s'arrête TOUJOURS
      if (mounted) {
        setState(() {
          if (_comptes.isNotEmpty) _compteSelectionne = _comptes.first;
          _isLoading = false;
        });
      }
    }
  }

  void _seConnecter() {
    if (_compteSelectionne == null) return;

    if (_pinLoginController.text == _compteSelectionne!.pin) {
      AuthService.utilisateurCourant = _compteSelectionne;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const NavigationScreen()),
      );
    } else {
      setState(() => _errorLogin = "Code PIN incorrect.");
    }
  }

  Future<void> _sInscrire() async {
    if (_formInscriptionKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        if (!kIsWeb) {
          await AuthService.inscrireUtilisateur(
            nom: _nomController.text,
            prenom: _prenomController.text,
            role: _roleSelectionne,
            pin: _pinRegisterController.text,
          );
        }

        _nomController.clear();
        _prenomController.clear();
        _pinRegisterController.clear();
        await _chargerComptesRobustes();

        setState(() {
          _modeInscription = false;
          _errorLogin = null;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Compte créé !'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        debugPrint("Erreur inscription : $e");
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildFormulaireConnexion() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Connexion',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),

        DropdownButtonFormField<Utilisateur>(
          decoration: InputDecoration(
            labelText: 'Sélectionner votre profil',
            prefixIcon: const Icon(Icons.person),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          value: _compteSelectionne,
          items: _comptes.map((Utilisateur u) {
            return DropdownMenuItem<Utilisateur>(
              value: u,
              child: Text('${u.nomComplet} (${u.role})'),
            );
          }).toList(),
          onChanged: (Utilisateur? nvCompte) {
            setState(() {
              _compteSelectionne = nvCompte;
              _errorLogin = null;
            });
          },
        ),
        const SizedBox(height: 16),

        TextField(
          controller: _pinLoginController,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 4,
          decoration: InputDecoration(
            labelText: 'Code PIN à 4 chiffres',
            prefixIcon: const Icon(Icons.lock),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            errorText: _errorLogin,
            counterText: "",
          ),
        ),
        const SizedBox(height: 24),

        SizedBox(
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _seConnecter,
            icon: const Icon(Icons.login),
            label: const Text(
              'Se connecter',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        TextButton(
          onPressed: () => setState(() => _modeInscription = true),
          child: const Text("Pas encore de compte ? S'inscrire"),
        ),
      ],
    );
  }

  Widget _buildFormulaireInscription() {
    return Form(
      key: _formInscriptionKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Créer un compte',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _prenomController,
                  decoration: InputDecoration(
                    labelText: 'Prénom',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (val) =>
                      val == null || val.isEmpty ? 'Requis' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _nomController,
                  decoration: InputDecoration(
                    labelText: 'Nom',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (val) =>
                      val == null || val.isEmpty ? 'Requis' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: 'Rôle',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            value: _roleSelectionne,
            items: const [
              DropdownMenuItem(value: 'ouvrier', child: Text('Ouvrier')),
              DropdownMenuItem(
                value: 'admin',
                child: Text('Administrateur / Chef'),
              ),
            ],
            onChanged: (val) => setState(() => _roleSelectionne = val!),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _pinRegisterController,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 4,
            decoration: InputDecoration(
              labelText: 'Créer un code PIN (4 chiffres)',
              prefixIcon: const Icon(Icons.password),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              counterText: "",
            ),
            validator: (val) =>
                val == null || val.length != 4 ? '4 chiffres requis' : null,
          ),
          const SizedBox(height: 24),

          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _sInscrire,
              icon: const Icon(Icons.person_add),
              label: const Text(
                'S\'inscrire',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          TextButton(
            onPressed: () => setState(() => _modeInscription = false),
            child: const Text("Annuler et retourner à la connexion"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
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
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: _isLoading
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      : (_modeInscription
                            ? _buildFormulaireInscription()
                            : _buildFormulaireConnexion()),
                ),
              ),

              const SizedBox(height: 20),
              Text(
                'Modèle v2 (TFLite) intégré',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
