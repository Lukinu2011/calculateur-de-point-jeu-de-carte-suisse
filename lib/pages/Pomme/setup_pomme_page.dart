import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
// Imports des utilitaires et modèles du fichier principal (remonte de deux niveaux)
import '../../main.dart';
// Imports des pages Pomme
import 'game_pomme_page.dart';
import 'load_game_pomme_page.dart';

// --- PAGE 2 : Configuration "Pomme" ---
class SetupPommePage extends StatefulWidget {
  const SetupPommePage({super.key}); // <-- Déjà const, OK
  @override
  State<SetupPommePage> createState() => _SetupPommePageState();
}

class _SetupPommePageState extends State<SetupPommePage> {
  // <-- Le constructeur de l'ÉTAT n'est pas const// ...
  final List<Player> _players = [];
  final TextEditingController _scoreController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

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

  void _startGame() {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final int targetScore = int.tryParse(_scoreController.text) ?? 7;

    if (_players.length < 2) {
      soundManager.playError(settings.volume);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez ajouter au moins deux joueurs !'),
        ),
      );
      return;
    }

    soundManager.playClick(settings.volume);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            GamePommePage(players: _players, targetScore: targetScore),
      ),
    );
  }

  void _loadGame() async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    soundManager.playClick(settings.volume);

    final GameData? loadedData = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoadGamePommePage()),
    );

    if (loadedData != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GamePommePage(
            players: loadedData.players,
            targetScore: loadedData.targetScore,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _scoreController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuration Pomme'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _scoreController,
              decoration: const InputDecoration(
                labelText: 'Score à atteindre',
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
                minimumSize: const Size(double.infinity, 40),
              ),
            ),
            const SizedBox(height: 10),

            ElevatedButton.icon(
              icon: const Icon(Icons.folder_open),
              label: const Text('Charger une partie'),
              onPressed: _loadGame,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 40),
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
