// lib/pages/Pomme/setup_pomme_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart'; // Pour la date et l'heure
import '../../main.dart';
import 'game_pomme_page.dart';
import 'load_game_pomme_page.dart';

// Préfixes de sauvegarde pour Pomme
const String pommeSavePrefix = 'pomme_save_';
const String pommeAutoSavePrefix = 'pomme_autosave_';

class SetupPommePage extends StatefulWidget {
  const SetupPommePage({super.key});
  @override
  State<SetupPommePage> createState() => _SetupPommePageState();
}

class _SetupPommePageState extends State<SetupPommePage> {
  final List<Player> _players = [];
  final TextEditingController _scoreController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  // NOUVEAU
  final TextEditingController _matchNameController = TextEditingController();

  @override
  void dispose() {
    _scoreController.dispose();
    _nameController.dispose();
    _matchNameController.dispose(); // NOUVEAU
    super.dispose();
  }

  void _addPlayerDialog() {
    final settings = Provider.of<SettingsProvider>(context, listen: false);

    _nameController.clear();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Ajouter un joueur'),
          content: TextField(
            controller: _nameController,
            decoration: const InputDecoration(hintText: "Nom du joueur"),
            autofocus: true,
          ),
          actions: [
            TextButton(
              child: const Text('Annuler'),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: const Text('Ajouter'),
              onPressed: () {
                if (_nameController.text.isNotEmpty) {
                  soundManager.playClick(settings.volume);
                  setState(() {
                    _players.add(Player(name: _nameController.text));
                  });
                  Navigator.pop(context);
                } else {
                  soundManager.playError(settings.volume);
                }
              },
            ),
          ],
        );
      },
    );
  }

  // --- MODIFIÉ ---
  void _startGame() {
    final settings = Provider.of<SettingsProvider>(context, listen: false);

    if (_players.length < 2) {
      soundManager.playError(settings.volume);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez ajouter au moins deux joueurs !'),
        ),
      );
      return;
    }

    final int targetScore = int.tryParse(_scoreController.text) ?? 7;

    // --- LOGIQUE DE SAUVEGARDE ---
    final String matchName = _matchNameController.text.isEmpty
        ? 'Match'
        : _matchNameController.text;
    final String timestamp = DateFormat(
      'yyyy-MM-dd_HH-mm-ss',
    ).format(DateTime.now());
    final String newAutoSaveKey = '$pommeAutoSavePrefix${matchName}_$timestamp';
    final String currentTime = DateFormat(
      'yyyy-MM-dd HH:mm:ss',
    ).format(DateTime.now()); // Date de création

    // Appel du constructeur PommeGameData corrigé
    final PommeGameData gameData = PommeGameData(
      saveName: matchName,
      autoSaveKey: newAutoSaveKey,
      players: _players,
      targetScore: targetScore,
      lastSaveTime:
          currentTime, // Ajout de la date de création/première sauvegarde
    );
    // --- FIN LOGIQUE ---

    soundManager.playClick(settings.volume);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GamePommePage(loadedData: gameData),
      ),
    );
  }

  // --- MODIFIÉ ---
  void _loadGame() async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    soundManager.playClick(settings.volume);

    final PommeGameData? loadedData = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoadGamePommePage()),
    );

    if (loadedData != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GamePommePage(loadedData: loadedData),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Configuration Pomme')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // --- NOUVEAU CHAMP ---
            TextField(
              controller: _matchNameController,
              decoration: const InputDecoration(
                labelText: 'Nom de la Partie',
                hintText: 'Nouvelle Partie',
                prefixIcon: Icon(Icons.label),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _scoreController,
              decoration: const InputDecoration(
                labelText: 'Score à atteindre',
                hintText: '7',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 20),

            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un joueur'),
              onPressed: () {
                soundManager.playClick(settings.volume);
                _addPlayerDialog();
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.blueGrey,
                foregroundColor: Colors.white,
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 10),

            ElevatedButton.icon(
              icon: const Icon(Icons.folder_open),
              label: const Text('Charger une partie'),
              onPressed: _loadGame,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.blueGrey,
                foregroundColor: Colors.white,
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),

            const SizedBox(height: 10),
            const Text(
              'Joueurs :',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _players.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    leading: CircleAvatar(child: Text('${index + 1}')),
                    title: Text(_players[index].name),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        soundManager.playClick(settings.volume);
                        setState(() {
                          _players.removeAt(index);
                        });
                      },
                    ),
                  );
                },
              ),
            ),

            Center(
              child: ElevatedButton(
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
            ),
          ],
        ),
      ),
    );
  }
}
