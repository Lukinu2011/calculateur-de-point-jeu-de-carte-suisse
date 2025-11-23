// lib/pages/Pomme/game_pomme_page.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart'; // Import pour DateFormat
import '../../main.dart'; // Pour PommeGameData, Player, SoundManager, SettingsProvider
import 'setup_pomme_page.dart'; // Pour les préfixes

class GamePommePage extends StatefulWidget {
  final PommeGameData loadedData;
  const GamePommePage({super.key, required this.loadedData});

  @override
  State<GamePommePage> createState() => _GamePommePageState();
}

class _GamePommePageState extends State<GamePommePage> {
  // État local du jeu
  late PommeGameData _gameData;
  late List<Player> _players;
  late int _targetScore;
  late String _autoSaveKey; // Clé unique pour l'autosave

  String? _winner;

  @override
  void initState() {
    super.initState();
    // Déballe les données chargées
    _gameData = widget.loadedData;
    _players = _gameData.players;
    _targetScore = _gameData.targetScore;
    _autoSaveKey = _gameData.autoSaveKey;

    _checkWinnerOnLoad(); // Vérifie si la partie chargée avait déjà un gagnant
  }

  void _updateScore(int playerIndex, {bool addPoint = true}) {
    if (_winner != null) return;

    final settings = Provider.of<SettingsProvider>(context, listen: false);
    soundManager.playClick(settings.volume);

    setState(() {
      if (addPoint) {
        _players[playerIndex].points++;
      } else {
        _players[playerIndex].pommes++;
      }
      _checkWinner(_players[playerIndex]);
    });
    _autoSaveGame(); // Sauvegarde auto à chaque clic
  }

  void _checkWinner(Player player) {
    if (player.score >= _targetScore) {
      setState(() {
        _winner = player.name;
      });
      _showWinnerDialog(player.name);
    }
  }

  void _checkWinnerOnLoad() {
    for (var player in _players) {
      if (player.score >= _targetScore) {
        setState(() {
          _winner = player.name;
        });
        break;
      }
    }
  }

  // --- Sauvegarde Automatique (MIS À JOUR) ---
  Future<void> _autoSaveGame() async {
    final prefs = await SharedPreferences.getInstance();
    final String timestamp = DateFormat(
      'yyyy-MM-dd HH:mm:ss',
    ).format(DateTime.now());

    // Met à jour l'objet _gameData avec l'état actuel et le timestamp
    _gameData = PommeGameData(
      saveName: _gameData.saveName,
      autoSaveKey: _autoSaveKey,
      players: _players,
      targetScore: _targetScore,
      lastSaveTime: timestamp, // AJOUTÉ
    );

    String saveString = jsonEncode(_gameData.toJson());
    await prefs.setString(_autoSaveKey, saveString);
  }

  // --- Sauvegarde Manuelle (MIS À JOUR) ---
  void _showSaveDialog() {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final String timestamp = DateFormat(
      'yyyy-MM-dd_HH-mm',
    ).format(DateTime.now());

    // Utilise _gameData.saveName pour pré-remplir
    final TextEditingController saveNameController = TextEditingController(
      text: '${_gameData.saveName}_$timestamp',
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Sauvegarder la partie'),
          content: TextField(
            controller: saveNameController,
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
                if (saveNameController.text.isNotEmpty) {
                  soundManager.playClick(settings.volume);
                  _manualSaveGame(saveNameController.text);
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

  Future<void> _manualSaveGame(String saveName) async {
    final prefs = await SharedPreferences.getInstance();
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final String timestamp = DateFormat(
      'yyyy-MM-dd HH:mm:ss',
    ).format(DateTime.now());

    final PommeGameData manualSaveData = PommeGameData(
      saveName: saveName,
      autoSaveKey: _autoSaveKey,
      players: _players,
      targetScore: _targetScore,
      lastSaveTime: timestamp, // AJOUTÉ
    );

    String saveString = jsonEncode(manualSaveData.toJson());
    await prefs.setString('$pommeSavePrefix$saveName', saveString);

    if (mounted) {
      soundManager.playClick(settings.volume);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Partie "$saveName" sauvegardée !')),
      );
    }
  }

  // --- Affichage du résumé (INCHANGÉ) ---
  void _showSummaryDialog() {
    // Ferme le dialogue de victoire s'il est ouvert
    if (_winner != null && mounted) {
      Navigator.of(context).pop();
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Résumé de la Partie'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _players.length,
              itemBuilder: (context, index) {
                final player = _players[index];
                return ListTile(
                  leading: CircleAvatar(child: Text('${index + 1}')),
                  title: Text(
                    player.name,
                    style: TextStyle(
                      fontWeight: player.score >= _targetScore
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  trailing: Text(
                    'Score Final: ${player.score}',
                    style: TextStyle(
                      fontWeight: player.score >= _targetScore
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: player.score >= _targetScore ? Colors.green : null,
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Fermer'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  // --- Gestion de fin de partie (INCHANGÉ) ---
  void _showWinnerDialog(String winnerName) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Partie terminée ! 🎉'),
          content: Text('$winnerName a gagné la partie !'),
          actions: [
            // Bouton 1 : Annuler la partie (Retour Accueil et Supprimer l'autosave)
            TextButton(
              child: const Text(
                "Annuler la partie (Retour Accueil & Supprimer)",
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () {
                soundManager.playClick(settings.volume);
                // Supprime l'autosave
                SharedPreferences.getInstance().then((prefs) {
                  prefs.remove(_autoSaveKey);
                });
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
            // Bouton 2 : Voir le Résumé
            TextButton(
              child: const Text("Voir le Résumé"),
              onPressed: () {
                soundManager.playClick(settings.volume);
                _showSummaryDialog();
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
            "La partie est sauvegardée automatiquement. Voulez-vous vraiment quitter ?",
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

  // --- WIDGET : Carte joueur stylisée comme le Jass (INCHANGÉ) ---
  Widget _buildPlayerCard(Player player, int index, bool isWinner) {
    return Card(
      color: isWinner
          ? Theme.of(context).brightness == Brightness.dark
                ? Colors.green.shade800
                : Colors.green.shade200
          : Theme.of(context).cardColor,
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Nom du joueur (style gras, grande taille)
            Text(
              player.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28, // Plus grand
                fontWeight: FontWeight.w900, // Extra gras
                color: isWinner
                    ? Colors.white
                    : Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),

            const SizedBox(height: 10),

            // Score total (style très grand)
            Text(
              '${player.score}',
              style: TextStyle(
                fontSize: 48, // Très grand
                fontWeight: FontWeight.w900,
                color: isWinner ? Colors.white : Colors.indigo.shade700,
              ),
            ),

            // Détails (Points et Pommes)
            Text(
              'Points : ${player.points}, Pommes : ${player.pommes}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isWinner ? Colors.white : Colors.grey.shade600,
              ),
            ),

            const SizedBox(height: 15),

            // Boutons d'ajout (style Jass)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Point'),
                    // Style Jass: Vert foncé
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(
                        double.infinity,
                        45,
                      ), // Plus large
                    ),
                    onPressed: _winner == null
                        ? () => _updateScore(index, addPoint: true)
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Pomme'),
                    // Style Jass: Rouge
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(
                        double.infinity,
                        45,
                      ), // Plus large
                    ),
                    onPressed: _winner == null
                        ? () => _updateScore(index, addPoint: false)
                        : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // CORRECTION : Utilise saveName pour le titre
        title: Text(
          '${_gameData.saveName} - Score Cible : $_targetScore',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        automaticallyImplyLeading: false,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              final settings = Provider.of<SettingsProvider>(
                context,
                listen: false,
              );
              soundManager.playClick(settings.volume);

              if (value == 'home') {
                _showReturnHomeDialog();
              } else if (value == 'save') {
                _showSaveDialog();
              }
            },
            icon: const Icon(
              Icons.menu,
            ), // Utilisation de l'icône menu pour la consistance
            itemBuilder: (BuildContext) => [
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
                  title: Text('Sauvegarder manuellement'),
                ),
              ),
            ],
          ),
        ],
      ),
      // --- LayoutBuilder ---
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Si Hauteur > Largeur (Portrait) = 1 colonne
          bool useHorizontalLayout =
              constraints.maxHeight > constraints.maxWidth;

          int crossAxisCount = useHorizontalLayout ? 1 : 2;
          if (!useHorizontalLayout && _players.length >= 5) crossAxisCount = 3;
          if (!useHorizontalLayout && _players.length >= 7) crossAxisCount = 4;

          return GridView.builder(
            padding: const EdgeInsets.all(12.0),
            // Utilise un GridView pour s'adapter
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: useHorizontalLayout ? 3.5 : 0.8, // Ratio ajusté
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemCount: _players.length,
            itemBuilder: (context, index) {
              final player = _players[index];
              final isWinner = _winner == player.name;

              return _buildPlayerCard(
                player,
                index,
                isWinner,
              ); // Utilisation du nouveau widget
            },
          );
        },
      ),
    );
  }
}
