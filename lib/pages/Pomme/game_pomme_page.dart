import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
// Imports des utilitaires et modèles du fichier principal
import '../../main.dart';
// Imports des pages Pomme
import 'load_game_pomme_page.dart';

// --- PAGE 3 : Page de Jeu "Pomme" ---
class GamePommePage extends StatefulWidget {
  final List<Player> players;
  final int targetScore;
  const GamePommePage({
    super.key,
    required this.players,
    required this.targetScore,
  });
  @override
  State<GamePommePage> createState() => _GamePommePageState();
}

class _GamePommePageState extends State<GamePommePage> {
  String? _winner;
  final TextEditingController _saveNameController = TextEditingController();

  @override
  void dispose() {
    _saveNameController.dispose();
    super.dispose();
  }

  void _updateScore(int playerIndex, {bool addPoint = true}) {
    if (_winner != null) return;

    final settings = Provider.of<SettingsProvider>(context, listen: false);
    soundManager.playClick(settings.volume);

    setState(() {
      if (addPoint) {
        widget.players[playerIndex].points++;
      } else {
        widget.players[playerIndex].pommes++;
      }
      _checkWinner(widget.players[playerIndex]);
    });
  }

  void _checkWinner(Player player) {
    if (player.score >= widget.targetScore) {
      setState(() {
        _winner = player.name;
      });
      _showWinnerDialog(player.name);
    }
  }

  void _showWinnerDialog(String winnerName) {
    final int finalScore = widget.players
        .firstWhere((p) => p.name == _winner)
        .score;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Partie terminée !'),
          content: Text(
            '$winnerName a gagné la partie avec un score de $finalScore !',
          ),
          actions: [
            TextButton(
              child: const Text("Retour à l'accueil"),
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
          ],
        );
      },
    );
  }

  void _showReturnHomeDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Quitter la partie ?"),
          content: const Text(
            "Voulez-vous vraiment retourner à l'accueil ? Toute la progression non sauvegardée sera perdue.",
          ),
          actions: [
            TextButton(
              child: const Text("Annuler"),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: const Text("Quitter"),
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
          ],
        );
      },
    );
  }

  void _showSaveDialog() {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    _saveNameController.clear();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Sauvegarder la partie'),
          content: TextField(
            controller: _saveNameController,
            decoration: const InputDecoration(hintText: "Nom de la sauvegarde"),
            autofocus: true,
          ),
          actions: [
            TextButton(
              child: const Text('Annuler'),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: const Text('Sauvegarder'),
              onPressed: () {
                if (_saveNameController.text.isNotEmpty) {
                  soundManager.playClick(settings.volume);
                  _saveGame(_saveNameController.text);
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

  Future<void> _saveGame(String saveName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<Map<String, dynamic>> playersJson = widget.players
          .map((player) => player.toJson())
          .toList();
      Map<String, dynamic> saveObject = {
        'targetScore': widget.targetScore,
        'players': playersJson,
      };
      String saveString = jsonEncode(saveObject);
      await prefs.setString('game_save_$saveName', saveString);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Partie "$saveName" sauvegardée !')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur de sauvegarde : $e')));
      }
    }
  }

  void _loadGame() async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    soundManager.playClick(settings.volume);

    final GameData? loadedData = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoadGamePommePage()),
    );

    if (loadedData != null && mounted) {
      Navigator.pushReplacement(
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

  void _onHomeMenuSelected(String value) {
    switch (value) {
      case 'home':
        _showReturnHomeDialog();
        break;
      case 'save':
        _showSaveDialog();
        break;
      case 'load':
        _loadGame();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Score à atteindre : ${widget.targetScore}'),
        automaticallyImplyLeading: false,
        actions: [
          PopupMenuButton<String>(
            onSelected: _onHomeMenuSelected,
            icon: const Icon(Icons.home),
            itemBuilder: (BuildContext) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'home',
                child: ListTile(
                  leading: Icon(Icons.home_work),
                  title: Text("Retour à l'accueil"),
                ),
              ),
              const PopupMenuItem<String>(
                value: 'save',
                child: ListTile(
                  leading: Icon(Icons.save),
                  title: Text('Sauvegarder'),
                ),
              ),
              const PopupMenuItem<String>(
                value: 'load',
                child: ListTile(
                  leading: Icon(Icons.folder_open),
                  title: Text('Charger une sauvegarde'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: widget.players.length,
            itemBuilder: (context, index) {
              final player = widget.players[index];
              final isWinner = _winner == player.name;

              return Card(
                color: isWinner ? const Color.fromARGB(255, 40, 150, 40) : null,
                elevation: 4,
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        player.name,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isWinner ? Colors.white : null,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Score : ${player.score}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        ' (Points : ${player.points}, Pommes : ${player.pommes})',
                      ),
                      const SizedBox(height: 10),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text('Point'),
                            style: ElevatedButton.styleFrom(
                              iconColor: Colors.white,
                              backgroundColor: const Color.fromARGB(
                                255,
                                40,
                                150,
                                40,
                              ),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () =>
                                _updateScore(index, addPoint: true),
                          ),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text('Pomme'),
                            style: ElevatedButton.styleFrom(
                              iconColor: Colors.white,
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),

                            onPressed: () =>
                                _updateScore(index, addPoint: false),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
