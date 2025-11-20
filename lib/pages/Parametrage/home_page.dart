// lib/pages/Parametrage/home_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// Imports des utilitaires
import '../../main.dart';
// Imports des pages dans les autres dossiers
import '../Jass/setup_jass_page.dart';
import '../Mise/setup_mise_page.dart';
import '../Pomme/setup_pomme_page.dart';
import 'settings_page.dart';

// --- PAGE 1 : Accueil ---
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  // Fonction utilitaire pour créer les boutons avec la logique de navigation
  Widget _buildHomeButton(
    BuildContext context,
    SettingsProvider settings,
    String text,
    Widget page,
    Color color,
  ) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
        textStyle: const TextStyle(fontSize: 24),
        backgroundColor: color,
        foregroundColor: Colors.white,
      ),
      child: Text(text),
      onPressed: () {
        soundManager.playClick(settings.volume);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => page,
          ), // 'page' n'est pas const ici
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accueil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              soundManager.playClick(settings.volume);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // <-- L'erreur venait sûrement d'un oubli de 'children:'
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 30.0),
              child: Text(
                'Bienvenue sur votre Calculateur de Points',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 50, fontWeight: FontWeight.w300),
              ),
            ),

            const SizedBox(height: 50),

            // --- BOUTON JASS ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 100.0),
              child: _buildHomeButton(
                context,
                settings,
                'Jass',
                const SetupJassPage(), // <-- 'const' est OK ici
                const Color.fromARGB(0, 0, 0, 0),
              ),
            ),

            const SizedBox(height: 20),

            // --- BOUTON MISE ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 100.0),
              child: _buildHomeButton(
                context,
                settings,
                'Mise',
                const SetupMisePage(), // <-- 'const' est OK ici
                const Color.fromARGB(0, 0, 0, 0),
              ),
            ),

            const SizedBox(height: 20),

            // --- BOUTON POMME ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 100.0),
              child: _buildHomeButton(
                context,
                settings,
                'Pomme',
                const SetupPommePage(), // <-- 'const' est OK ici
                const Color.fromARGB(0, 0, 0, 0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
