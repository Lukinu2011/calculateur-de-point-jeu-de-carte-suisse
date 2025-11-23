// lib/pages/Jass/setup_jass_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart'; // Pour la date et l'heure
import '../../main.dart'; // Importe SettingsProvider
import 'game_jass_page.dart'; // Importe JassGameData
import 'load_game_jass_page.dart'; // Pour préfixe et page

class SetupJassPage extends StatefulWidget {
  const SetupJassPage({super.key});

  @override
  State<SetupJassPage> createState() => _SetupJassPageState();
}

class _SetupJassPageState extends State<SetupJassPage> {
  final TextEditingController _team1NameController = TextEditingController(
    text: '',
  );
  final TextEditingController _team2NameController = TextEditingController(
    text: '',
  );
  final TextEditingController _score1Controller = TextEditingController(
    text: '',
  );
  final TextEditingController _score2Controller = TextEditingController(
    text: '',
  );
  final TextEditingController _matchNameController = TextEditingController(
    text: '',
  );

  // Le jeu ne requiert plus d'entrer les joueurs
  bool _piqueDouble = false;

  @override
  void dispose() {
    _team1NameController.dispose();
    _team2NameController.dispose();
    _score1Controller.dispose();
    _score2Controller.dispose();
    _matchNameController.dispose();
    super.dispose();
  }

  // Charge une partie de Jass et revient avec les données
  void _loadJassGame() async {
    final JassGameData? loadedData = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoadGameJassPage()),
    );

    if (loadedData != null && mounted) {
      // Si une partie est chargée, naviguer vers la page de jeu
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => GameJassPage(loadedData: loadedData),
        ),
      );
    }
  }

  void _startGame() {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final soundManager = SoundManager();
    soundManager.playClick(settings.volume);

    final matchName = _matchNameController.text.trim().isEmpty
        ? 'Nouvelle Partie'
        : _matchNameController.text.trim();
    final team1Name = _team1NameController.text.trim().isEmpty
        ? 'Équipe 1'
        : _team1NameController.text.trim();
    final team2Name = _team2NameController.text.trim().isEmpty
        ? 'Équipe 2'
        : _team2NameController.text.trim();

    final targetScore1 = int.tryParse(_score1Controller.text) ?? 1000;
    final targetScore2 = int.tryParse(_score2Controller.text) ?? 1000;

    // Génération de la clé de sauvegarde automatique unique
    final autoSaveKey =
        '${jassAutoSavePrefix}${DateTime.now().millisecondsSinceEpoch}';
    final timestamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());

    final newGameData = JassGameData(
      saveName: matchName,
      team1Name: team1Name,
      team2Name: team2Name,
      // Les listes de joueurs sont vides (selon la demande)
      team1Players: const [],
      team2Players: const [],
      targetScore1: targetScore1,
      targetScore2: targetScore2,
      isPiqueDouble: _piqueDouble,
      team1Score: 0,
      team2Score: 0,
      history1: const [],
      history2: const [],
      autoSaveKey: autoSaveKey,
      lastSaveTime: timestamp,
    );

    // Naviguer vers la page de jeu
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameJassPage(loadedData: newGameData),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final soundManager = SoundManager();

    return Scaffold(
      appBar: AppBar(title: const Text('Configuration Jass')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Nom de la partie
            TextField(
              controller: _matchNameController,
              decoration: const InputDecoration(
                labelText: 'Nom de la Partie',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.label),
                hintText: 'Nouvelle Partie',
              ),
            ),
            const SizedBox(height: 20),

            // Objectifs de Score
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _score1Controller,
                    decoration: InputDecoration(
                      labelText: 'Objectif (Équipe 1)',
                      hintText: "1000",
                      border: const OutlineInputBorder(),
                      suffixText: 'pts',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _score2Controller,
                    decoration: InputDecoration(
                      labelText: 'Objectif (Équipe 2)',
                      hintText: "1000",
                      border: const OutlineInputBorder(),
                      suffixText: 'pts',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Noms des Équipes
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _team1NameController,
                    decoration: const InputDecoration(
                      labelText: 'Nom Équipe 1',
                      hintText: "Équipe 1",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.group_add),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _team2NameController,
                    decoration: const InputDecoration(
                      labelText: 'Nom Équipe 2',
                      hintText: "Équipe 2",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.group_add),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Option Pique Double (si nécessaire)
            SwitchListTile(
              title: const Text('Variante Pique Double'),
              subtitle: const Text(
                'Variante où les points sont doublés pour les manches avec pique comme atout.',
              ),
              value: _piqueDouble,
              onChanged: (bool newValue) {
                soundManager.playClick(settings.volume);
                setState(() {
                  _piqueDouble = newValue;
                });
              },
            ),

            const SizedBox(height: 40),

            // Boutons d'action
            ElevatedButton.icon(
              icon: const Icon(Icons.folder_open),
              label: const Text('Charger une partie'),
              onPressed: _loadJassGame,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.blueGrey,
                foregroundColor: Colors.white,
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 50,
                  vertical: 15,
                ),
                textStyle: const TextStyle(fontSize: 20),
              ),
              onPressed: _startGame,
              child: const Text('Commencer'),
            ),
          ],
        ),
      ),
    );
  }
}
