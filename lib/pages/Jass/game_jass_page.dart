// lib/pages/Jass/game_jass_page.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import '../../main.dart';
import '../Parametrage/home_page.dart';
import 'load_game_jass_page.dart';

// Constantes Jass
const int JASS_MAX_POINTS_IN_ROUND = 157;
const int JASS_MAX_POINTS_WITH_100 = 257;
const List<int> JASS_ANNOUNCES = [20, 50, 100, 150, 200];

// --- Modèle pour une entrée de score dans l'historique ---
class JassScoreEntry {
  final int points;
  final String label;

  JassScoreEntry({required this.points, required this.label});

  Map<String, dynamic> toJson() => {'points': points, 'label': label};

  factory JassScoreEntry.fromJson(Map<String, dynamic> json) {
    return JassScoreEntry(
      points: json['points'] as int,
      label: json['label'] as String,
    );
  }
}

// --- Modèle pour sauvegarder/charger une partie de Jass ---
class JassGameData {
  final String saveName;
  final String team1Name;
  final String team2Name;
  final List<String> team1Players;
  final List<String> team2Players;
  final int targetScore1;
  final int targetScore2;
  final bool isPiqueDouble;
  final int team1Score;
  final int team2Score;
  final List<JassScoreEntry> history1;
  final List<JassScoreEntry> history2;
  final String autoSaveKey;
  final String? lastSaveTime;

  JassGameData({
    required this.saveName,
    required this.team1Name,
    required this.team2Name,
    required this.team1Players,
    required this.team2Players,
    required this.targetScore1,
    required this.targetScore2,
    required this.isPiqueDouble,
    required this.team1Score,
    required this.team2Score,
    required this.history1,
    required this.history2,
    required this.autoSaveKey,
    this.lastSaveTime,
  });

  Map<String, dynamic> toJson() => {
    'saveName': saveName,
    'team1Name': team1Name,
    'team2Name': team2Name,
    'team1Players': team1Players,
    'team2Players': team2Players,
    'targetScore1': targetScore1,
    'targetScore2': targetScore2,
    'isPiqueDouble': isPiqueDouble,
    'team1Score': team1Score,
    'team2Score': team2Score,
    'history1': history1.map((e) => e.toJson()).toList(),
    'history2': history2.map((e) => e.toJson()).toList(),
    'autoSaveKey': autoSaveKey,
    'lastSaveTime': lastSaveTime,
  };

  factory JassGameData.fromJson(Map<String, dynamic> json) {
    return JassGameData(
      saveName: json['saveName'] ?? 'Partie de Jass',
      team1Name: json['team1Name'] ?? 'Équipe 1',
      team2Name: json['team2Name'] ?? 'Équipe 2',
      team1Players: List<String>.from(json['team1Players'] ?? []),
      team2Players: List<String>.from(json['team2Players'] ?? []),
      targetScore1: json['targetScore1'] as int? ?? 1000,
      targetScore2: json['targetScore2'] as int? ?? 1000,
      isPiqueDouble: json['isPiqueDouble'] as bool? ?? false,
      team1Score: json['team1Score'] as int? ?? 0,
      team2Score: json['team2Score'] as int? ?? 0,
      history1:
          (json['history1'] as List<dynamic>?)
              ?.map((e) => JassScoreEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      history2:
          (json['history2'] as List<dynamic>?)
              ?.map((e) => JassScoreEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      autoSaveKey: json['autoSaveKey'] as String? ?? jassAutoSavePrefix,
      lastSaveTime: json['lastSaveTime'] as String?,
    );
  }

  JassGameData copyWith({
    int? team1Score,
    int? team2Score,
    List<JassScoreEntry>? history1,
    List<JassScoreEntry>? history2,
  }) {
    return JassGameData(
      saveName: saveName,
      team1Name: team1Name,
      team2Name: team2Name,
      team1Players: team1Players,
      team2Players: team2Players,
      targetScore1: targetScore1,
      targetScore2: targetScore2,
      isPiqueDouble: isPiqueDouble,
      team1Score: team1Score ?? this.team1Score,
      team2Score: team2Score ?? this.team2Score,
      history1: history1 ?? this.history1,
      history2: history2 ?? this.history2,
      autoSaveKey: autoSaveKey,
      lastSaveTime: lastSaveTime,
    );
  }
}

class GameJassPage extends StatefulWidget {
  final JassGameData loadedData;
  const GameJassPage({super.key, required this.loadedData});

  @override
  State<GameJassPage> createState() => _GameJassPageState();
}

class _GameJassPageState extends State<GameJassPage> {
  late JassGameData _gameData;
  // Deux contrôleurs pour le score de la manche
  late TextEditingController _roundScore1Controller;
  late TextEditingController _roundScore2Controller;

  // Pour stocker le score entré par l'utilisateur (le dernier modifié)
  int _lastModifiedTeam = 0; // 1 ou 2

  // Historique d'annulation
  late List<JassGameData> _history;
  String? _winner;

  @override
  void initState() {
    super.initState();
    _gameData = widget.loadedData;
    _roundScore1Controller = TextEditingController();
    _roundScore2Controller = TextEditingController();

    _history = [];
    _saveStateForUndo();

    _checkWinnerOnLoad();
  }

  @override
  void dispose() {
    _roundScore1Controller.dispose();
    _roundScore2Controller.dispose();
    super.dispose();
  }

  // --- LOGIQUE DE JEU ET SAUVEGARDE ---

  // Fonction de validation pour un score entré dans un champ.
  // Retourne vrai si le score est un nombre valide pour une manche.
  bool _isInputValid(int enteredScore) {
    if (enteredScore < 0) return false;
    // La seule valeur au-dessus de 157 autorisée est 257.
    if (enteredScore > JASS_MAX_POINTS_IN_ROUND &&
        enteredScore != JASS_MAX_POINTS_WITH_100) {
      return false;
    }
    return true;
  }

  // Fonction principale pour calculer le score croisé.
  // Si teamIndex=1 est modifié, il calcule le score de l'équipe 2.
  int _calculateCrossScore(int enteredScore) {
    if (enteredScore == JASS_MAX_POINTS_WITH_100) {
      return 0; // Si 257 (Match), l'autre équipe a 0.
    }
    // Sinon, l'autre équipe a le reste des points
    int calculated = JASS_MAX_POINTS_IN_ROUND - enteredScore;

    // S'assurer que le résultat n'est pas négatif (ce qui est le cas si enteredScore > 157 et != 257)
    return calculated < 0 ? -1 : calculated;
  }

  // Gère la mise à jour automatique des champs croisés
  void _onScoreChanged(String text, int teamIndex) {
    if (text.isEmpty) {
      // Si le champ est vidé, effacer l'autre et ne rien calculer
      setState(() {
        if (teamIndex == 1) {
          _roundScore2Controller.clear();
        } else {
          _roundScore1Controller.clear();
        }
        _lastModifiedTeam =
            teamIndex; // Garder la trace de la dernière modification
      });
      return;
    }

    final int? enteredScore = int.tryParse(text);
    if (enteredScore == null)
      return; // Devrait être géré par FilteringTextInputFormatter

    _lastModifiedTeam = teamIndex;

    if (!_isInputValid(enteredScore)) {
      // La validation finale sera faite lors de l'ajout
      setState(() {}); // Pour mettre à jour la couleur d'erreur
      return;
    }

    // Calcul du score croisé
    final int crossScore = _calculateCrossScore(enteredScore);

    // Mise à jour de l'autre champ
    if (crossScore >= 0) {
      final String newText = crossScore.toString();
      final TextEditingController controllerToUpdate = (teamIndex == 1)
          ? _roundScore2Controller
          : _roundScore1Controller;

      // Évite la boucle infinie et les mises à jour non désirées
      if (controllerToUpdate.text != newText) {
        // Utilisation de setState pour la mise à jour de l'UI
        setState(() {
          controllerToUpdate.text = newText;
        });
      }
    } else {
      // Score croisé négatif (ex: 157 - 160 = -3), ce qui est invalide
      setState(() {}); // Mettre à jour la couleur d'erreur
    }
  }

  // Ajout du score pour la manche (ajoute les scores aux deux équipes)
  void _addScore() {
    if (_winner != null) return;

    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final soundManager = SoundManager();

    final int? team1RoundScore = int.tryParse(_roundScore1Controller.text);
    final int? team2RoundScore = int.tryParse(_roundScore2Controller.text);

    // Vérification de base (les deux doivent être des entiers)
    if (team1RoundScore == null || team2RoundScore == null) {
      soundManager.playError(settings.volume);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Les deux scores de manche doivent être des nombres entiers.",
          ),
        ),
      );
      return;
    }

    // Vérification du total et des règles de Jass
    final int totalRoundScore = team1RoundScore + team2RoundScore;
    final bool isScoreValid =
        totalRoundScore == JASS_MAX_POINTS_IN_ROUND ||
        (team1RoundScore == JASS_MAX_POINTS_WITH_100 && team2RoundScore == 0) ||
        (team2RoundScore == JASS_MAX_POINTS_WITH_100 && team1RoundScore == 0);

    if (!isScoreValid) {
      soundManager.playError(settings.volume);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Le total des scores est invalide. (Doit faire 157, ou un Match à 257/0).",
          ),
        ),
      );
      return;
    }

    // Si le score est 0/0, ce n'est pas une manche valide à ajouter
    if (team1RoundScore == 0 && team2RoundScore == 0) {
      soundManager.playError(settings.volume);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez entrer au moins un score positif."),
        ),
      );
      return;
    }

    _saveStateForUndo();
    soundManager.playClick(settings.volume);

    final roundNumber = _gameData.history1.length / 2 + 1; // Estimation
    final team1Entry = JassScoreEntry(
      points: team1RoundScore,
      label: 'Manche ${roundNumber.toInt()}',
    );
    final team2Entry = JassScoreEntry(
      points: team2RoundScore,
      label: 'Manche ${roundNumber.toInt()}',
    );

    // Mise à jour de l'état du jeu
    setState(() {
      _gameData = _gameData.copyWith(
        team1Score: _gameData.team1Score + team1RoundScore,
        team2Score: _gameData.team2Score + team2RoundScore,
        history1: [..._gameData.history1, team1Entry],
        history2: [..._gameData.history2, team2Entry],
      );

      // Effacer les champs
      _roundScore1Controller.clear();
      _roundScore2Controller.clear();
    });

    _autoSaveGame();
    _checkWinner();
  }

  // Ajout des annonces (reste la même logique)
  void _onAnnoncePressed(int points, int teamIndex) {
    if (_winner != null) return;

    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final soundManager = SoundManager();

    _saveStateForUndo();
    soundManager.playClick(settings.volume);

    setState(() {
      final teamName = teamIndex == 1
          ? _gameData.team1Name
          : _gameData.team2Name;
      final newEntry = JassScoreEntry(
        points: points,
        label: 'Annonce $points (${teamName})',
      );
      // L'autre équipe reçoit une entrée à 0 pour l'historique apparié
      final otherEntry = JassScoreEntry(
        points: 0,
        label: 'Annonce $points (${teamName})',
      );

      if (teamIndex == 1) {
        _gameData = _gameData.copyWith(
          team1Score: _gameData.team1Score + points,
          history1: [..._gameData.history1, newEntry],
          history2: [..._gameData.history2, otherEntry],
        );
      } else {
        _gameData = _gameData.copyWith(
          team2Score: _gameData.team2Score + points,
          history2: [..._gameData.history2, newEntry],
          history1: [..._gameData.history1, otherEntry],
        );
      }
    });

    _autoSaveGame();
    _checkWinner();
  }

  // --- Fonctions de base (Sauvegarde, Annulation, Victoire) ---

  void _saveStateForUndo() {
    _history.add(
      _gameData.copyWith(
        history1: List.of(_gameData.history1),
        history2: List.of(_gameData.history2),
      ),
    );
  }

  void _undoLastAction() {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final soundManager = SoundManager();

    if (_history.length > 1) {
      soundManager.playClick(settings.volume);
      _history.removeLast();
      final JassGameData previousState = _history.last;
      setState(() {
        _gameData = previousState;
        _winner = null;
        _roundScore1Controller.clear();
        _roundScore2Controller.clear();
      });
      _autoSaveGame();
    } else {
      soundManager.playError(settings.volume);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Impossible d'annuler. État initial atteint."),
        ),
      );
    }
  }

  void _checkWinner() {
    if (_winner != null) return;
    String? currentWinner;

    if (_gameData.team1Score >= _gameData.targetScore1) {
      currentWinner = _gameData.team1Name;
    } else if (_gameData.team2Score >= _gameData.targetScore2) {
      currentWinner = _gameData.team2Name;
    }

    if (currentWinner != null) {
      setState(() {
        _winner = currentWinner;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showWinnerDialog(currentWinner!);
      });
    }
  }

  void _checkWinnerOnLoad() {
    if (_gameData.team1Score >= _gameData.targetScore1) {
      _winner = _gameData.team1Name;
    } else if (_gameData.team2Score >= _gameData.targetScore2) {
      _winner = _gameData.team2Name;
    }
  }

  Future<void> _autoSaveGame() async {
    final prefs = await SharedPreferences.getInstance();
    final String timestamp = DateFormat(
      'yyyy-MM-dd_HH-mm-ss',
    ).format(DateTime.now());

    _gameData = JassGameData(
      saveName: _gameData.saveName,
      team1Name: _gameData.team1Name,
      team2Name: _gameData.team2Name,
      team1Players: _gameData.team1Players,
      team2Players: _gameData.team2Players,
      targetScore1: _gameData.targetScore1,
      targetScore2: _gameData.targetScore2,
      isPiqueDouble: _gameData.isPiqueDouble,
      team1Score: _gameData.team1Score,
      team2Score: _gameData.team2Score,
      history1: _gameData.history1,
      history2: _gameData.history2,
      autoSaveKey: _gameData.autoSaveKey,
      lastSaveTime: timestamp,
    );

    String saveString = jsonEncode(_gameData.toJson());
    await prefs.setString(_gameData.autoSaveKey, saveString);

    List<String> saveKeys = prefs.getStringList('jass_save_keys') ?? [];
    if (!saveKeys.contains(_gameData.autoSaveKey)) {
      saveKeys.add(_gameData.autoSaveKey);
      await prefs.setStringList('jass_save_keys', saveKeys);
    }
  }

  void _showSaveDialog() {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final soundManager = SoundManager();

    final String timestamp = DateFormat(
      'yyyy-MM-dd_HH-mm',
    ).format(DateTime.now());
    final TextEditingController saveNameController = TextEditingController(
      text: '${_gameData.saveName}_$timestamp',
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Sauvegarder manuellement'),
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
    final soundManager = SoundManager();

    final String saveKey = '$jassSavePrefix$saveName';
    final String timestamp = DateFormat(
      'yyyy-MM-dd_HH-mm-ss',
    ).format(DateTime.now());

    final JassGameData finalSaveData = JassGameData(
      saveName: _gameData.saveName,
      team1Name: _gameData.team1Name,
      team2Name: _gameData.team2Name,
      team1Players: _gameData.team1Players,
      team2Players: _gameData.team2Players,
      targetScore1: _gameData.targetScore1,
      targetScore2: _gameData.targetScore2,
      isPiqueDouble: _gameData.isPiqueDouble,
      team1Score: _gameData.team1Score,
      team2Score: _gameData.team2Score,
      history1: _gameData.history1,
      history2: _gameData.history2,
      autoSaveKey: _gameData.autoSaveKey,
      lastSaveTime: timestamp,
    );

    String saveString = jsonEncode(finalSaveData.toJson());
    await prefs.setString(saveKey, saveString);

    List<String> saveKeys = prefs.getStringList('jass_save_keys') ?? [];
    if (!saveKeys.contains(saveKey)) {
      saveKeys.add(saveKey);
      await prefs.setStringList('jass_save_keys', saveKeys);
    }

    if (mounted) {
      soundManager.playClick(settings.volume);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Partie "$saveName" sauvegardée !')),
      );
    }
  }

  void _returnToHomeKeepSave() {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final soundManager = SoundManager();

    _autoSaveGame();
    soundManager.playClick(settings.volume);

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const HomePage()),
        (Route<dynamic> route) => false,
      );
    }
  }

  Future<void> _returnToHomeAndClear() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_gameData.autoSaveKey);

    List<String> saveKeys = prefs.getStringList('jass_save_keys') ?? [];
    if (saveKeys.contains(_gameData.autoSaveKey)) {
      saveKeys.remove(_gameData.autoSaveKey);
      await prefs.setStringList('jass_save_keys', saveKeys);
    }

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const HomePage()),
        (Route<dynamic> route) => false,
      );
    }
  }

  void _confirmReturnHomeAndClear() {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final soundManager = SoundManager();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Quitter et Supprimer'),
          content: const Text(
            'Voulez-vous vraiment retourner à l\'accueil et supprimer cette partie en cours ? (La sauvegarde automatique sera effacée).',
          ),
          actions: [
            TextButton(
              child: const Text('Annuler'),
              onPressed: () {
                soundManager.playClick(settings.volume);
                Navigator.pop(context);
              },
            ),
            TextButton(
              child: const Text(
                'Supprimer et Quitter',
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () {
                soundManager.playClick(settings.volume);
                Navigator.pop(context);
                _returnToHomeAndClear();
              },
            ),
          ],
        );
      },
    );
  }

  void _loadGame() async {
    final JassGameData? loadedData = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoadGameJassPage()),
    );

    if (loadedData != null && mounted) {
      setState(() {
        _gameData = loadedData;
        _history = [];
        _saveStateForUndo();
        _roundScore1Controller.clear();
        _roundScore2Controller.clear();
      });
      _checkWinnerOnLoad();
    }
  }

  // NOUVEAU : Affichage du résumé
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
            child: _buildHistoryRecap(inDialog: true),
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

  // MODIFIÉ : Ajout des boutons de fin de partie
  void _showWinnerDialog(String winnerName) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final soundManager = SoundManager();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Partie Terminée! 🎉'),
          content: Text(
            'Félicitations ! $winnerName a atteint le score objectif !',
          ),
          actions: [
            // Bouton 1 : Annuler/Supprimer
            TextButton(
              onPressed: () {
                soundManager.playClick(settings.volume);
                Navigator.of(context).pop(); // Ferme le dialogue
                _confirmReturnHomeAndClear(); // Lance la confirmation de suppression
              },
              child: const Text(
                'Annuler la partie',
                style: TextStyle(color: Colors.red),
              ),
            ),
            // Bouton 2 : Voir le Résumé
            TextButton(
              onPressed: () {
                soundManager.playClick(settings.volume);
                _showSummaryDialog();
              },
              child: const Text('Voir le Résumé'),
            ),
          ],
        );
      },
    );
  }

  // --- WIDGETS DE L'UI ---

  Widget _buildMenuButton() {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final soundManager = SoundManager();

    return PopupMenuButton<String>(
      icon: const Icon(Icons.menu),
      tooltip: 'Menu',
      onSelected: (value) {
        soundManager.playClick(settings.volume);
        switch (value) {
          case 'save_manual':
            _showSaveDialog();
            break;
          case 'load':
            _loadGame();
            break;
          case 'undo':
            _undoLastAction();
            break;
          case 'home_keep':
            _returnToHomeKeepSave();
            break;
          case 'home_clear':
            _confirmReturnHomeAndClear();
            break;
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(
          value: 'save_manual',
          child: ListTile(
            leading: Icon(Icons.save),
            title: Text('Sauvegarder manuellement'),
          ),
        ),
        const PopupMenuItem<String>(
          value: 'load',
          child: ListTile(
            leading: Icon(Icons.folder_open),
            title: Text('Charger une partie'),
          ),
        ),
        PopupMenuItem<String>(
          value: 'undo',
          enabled: _history.length > 1,
          child: const ListTile(
            leading: Icon(Icons.undo),
            title: Text('Annuler la dernière action'),
          ),
        ),
        const PopupMenuItem<String>(
          value: 'home_keep',
          child: ListTile(
            leading: Icon(Icons.home),
            title: Text('Retour Accueil (Conserver la sauvegarde)'),
          ),
        ),
        const PopupMenuItem<String>(
          value: 'home_clear',
          child: ListTile(
            leading: Icon(Icons.exit_to_app, color: Colors.red),
            title: Text('Retour Accueil (Supprimer la sauvegarde)'),
          ),
        ),
      ],
    );
  }

  Widget _buildAnnonceButton(int points, int teamIndex) {
    return ElevatedButton(
      onPressed: _winner == null
          ? () => _onAnnoncePressed(points, teamIndex)
          : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        minimumSize: const Size(60, 50),
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
      child: Text(
        '+$points',
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  // Affiche le score total de l'équipe
  Widget _buildTotalScoreDisplay(
    String teamName,
    int score,
    int target,
    int teamIndex,
  ) {
    final bool isWinner = score >= target;

    return Column(
      children: [
        Text(
          teamName,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isWinner ? Colors.green : null,
          ),
        ),
        Text(
          '$score',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: isWinner ? Colors.green : null,
          ),
        ),
        Text('Objectif: $target', style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  // Section Annonces (Haut : Gauche/Droite)
  Widget _buildAnnouncements() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Équipe 1 (Gauche)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Annonces ${_gameData.team1Name}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 5),
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: _buildAnnonceButtonsGrouped(1),
              ),
            ],
          ),
          // Équipe 2 (Droite)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Annonces ${_gameData.team2Name}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 5),
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                alignment: WrapAlignment.end,
                children: _buildAnnonceButtonsGrouped(2),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildAnnonceButtonsGrouped(int teamIndex) {
    final List<Widget> buttons = [];
    for (int i = 0; i < JASS_ANNOUNCES.length; i += 2) {
      buttons.add(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildAnnonceButton(JASS_ANNOUNCES[i], teamIndex),
            if (i + 1 < JASS_ANNOUNCES.length) ...[
              const SizedBox(height: 8),
              _buildAnnonceButton(JASS_ANNOUNCES[i + 1], teamIndex),
            ],
          ],
        ),
      );
    }
    return buttons;
  }

  // Section centrale d'entrée de score avec deux champs et calcul croisé
  Widget _buildCentralScoring() {
    final int? score1 = int.tryParse(_roundScore1Controller.text);
    final int? score2 = int.tryParse(_roundScore2Controller.text);

    // Vérification de la validité pour l'affichage en rouge
    bool isInvalid1 =
        score1 != null &&
        (score1 < 0 ||
            !_isInputValid(score1) ||
            (_lastModifiedTeam == 1 &&
                _calculateCrossScore(score1) < 0 &&
                score2 != null));
    bool isInvalid2 =
        score2 != null &&
        (score2 < 0 ||
            !_isInputValid(score2) ||
            (_lastModifiedTeam == 2 &&
                _calculateCrossScore(score2) < 0 &&
                score1 != null));

    // Total check for button
    final int total = (score1 ?? 0) + (score2 ?? 0);
    final bool canAddScore =
        _winner == null &&
        score1 != null &&
        score2 != null &&
        (total == JASS_MAX_POINTS_IN_ROUND ||
            (score1 == JASS_MAX_POINTS_WITH_100 && score2 == 0) ||
            (score2 == JASS_MAX_POINTS_WITH_100 && score1 == 0)) &&
        total > 0;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // 1. Entrées de score croisées
          Row(
            children: [
              // Score Équipe 1
              Expanded(
                child: TextField(
                  controller: _roundScore1Controller,
                  decoration: InputDecoration(
                    labelText: _gameData.team1Name,
                    border: const OutlineInputBorder(),
                    suffixText: 'pts',
                    errorText: isInvalid1 ? 'Score invalide/négatif' : null,
                    labelStyle: TextStyle(
                      color: isInvalid1 ? Colors.red : null,
                    ),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: false,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  style: TextStyle(
                    color: isInvalid1 ? Colors.red : null,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                  onChanged: (text) => _onScoreChanged(text, 1),
                ),
              ),

              const SizedBox(width: 15),

              // Score Équipe 2
              Expanded(
                child: TextField(
                  controller: _roundScore2Controller,
                  decoration: InputDecoration(
                    labelText: _gameData.team2Name,
                    border: const OutlineInputBorder(),
                    suffixText: 'pts',
                    errorText: isInvalid2 ? 'Score invalide/négatif' : null,
                    labelStyle: TextStyle(
                      color: isInvalid2 ? Colors.red : null,
                    ),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: false,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  style: TextStyle(
                    color: isInvalid2 ? Colors.red : null,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                  onChanged: (text) => _onScoreChanged(text, 2),
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          // 2. Bouton Ajouter Score (unique)
          ElevatedButton.icon(
            onPressed: canAddScore ? _addScore : null,
            icon: const Icon(Icons.add_circle),
            label: Text(
              canAddScore
                  ? 'Ajouter Score de Manche'
                  : 'Total Invalide / Entrez les scores',
            ),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),

          const SizedBox(height: 15),
          const Divider(),

          // 3. Affichage des Scores Totaux (sous le bouton)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildTotalScoreDisplay(
                _gameData.team1Name,
                _gameData.team1Score,
                _gameData.targetScore1,
                1,
              ),
              _buildTotalScoreDisplay(
                _gameData.team2Name,
                _gameData.team2Score,
                _gameData.targetScore2,
                2,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Menu déroulant Récapitulatif
  Widget _buildHistoryRecap({bool inDialog = false}) {
    final int historyLength = _gameData.history1.length;
    final List<Widget> fullHistory = [];

    for (int i = historyLength - 1; i >= 0; i--) {
      final entry1 = _gameData.history1[i];
      final entry2 = _gameData.history2[i];

      // Affiche l'entrée de l'équipe qui a marqué des points
      final bool isRound = entry1.label.startsWith('Manche');

      fullHistory.add(
        ListTile(
          dense: true,
          title: Text(
            entry1.label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          subtitle: isRound
              ? Text(
                  '${_gameData.team1Name}: ${entry1.points} pts / ${_gameData.team2Name}: ${entry2.points} pts',
                )
              : Text(
                  entry1.points > 0
                      ? '${_gameData.team1Name} a marqué ${entry1.points} pts (Annonce)'
                      : '${_gameData.team2Name} a marqué ${entry2.points} pts (Annonce)',
                ),
          trailing: Text(
            'Total: ${entry1.points + entry2.points}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    final Widget historyContent = fullHistory.isEmpty
        ? const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('Aucun point enregistré.'),
          )
        : Column(children: fullHistory);

    if (inDialog) {
      return SingleChildScrollView(child: historyContent);
    }

    return Container(
      color: Theme.of(context).cardColor,
      child: ExpansionTile(
        title: const Text('Historique et Récapitulatif'),
        leading: const Icon(Icons.history),
        children: [historyContent],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool team1Won = _gameData.team1Score >= _gameData.targetScore1;
    final bool team2Won = _gameData.team2Score >= _gameData.targetScore2;
    final Color winnerColor = team1Won || team2Won
        ? Theme.of(context).brightness == Brightness.dark
              ? Colors.green.shade800
              : Colors.green.shade200
        : Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: winnerColor,
      appBar: AppBar(
        title: Text(_gameData.saveName),
        actions: [_buildMenuButton()],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Annonces (Haut)
            _buildAnnouncements(),

            const Divider(height: 20, indent: 16, endIndent: 16),

            // 2. Entrée de Score, Bouton, et Scores Totaux (Milieu)
            Expanded(
              child: SingleChildScrollView(child: _buildCentralScoring()),
            ),

            // 3. Menu Déroulant Récapitulatif (Bas)
            _buildHistoryRecap(),
          ],
        ),
      ),
    );
  }
}
