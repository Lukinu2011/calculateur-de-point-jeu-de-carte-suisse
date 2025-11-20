import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
// Imports des utilitaires et modèles du fichier principal
import '../../main.dart';

// --- PAGE 4 : Page de Chargement "Pomme" ---
class LoadGamePommePage extends StatefulWidget {
  const LoadGamePommePage({super.key});
  @override
  State<LoadGamePommePage> createState() => _LoadGamePommePageState();
}

class _LoadGamePommePageState extends State<LoadGamePommePage> {
  List<String> _saveNames = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSavedGames();
  }

  Future<void> _fetchSavedGames() async {
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys();
    setState(() {
      _saveNames = allKeys
          .where((key) => key.startsWith('game_save_'))
          .map((key) => key.substring('game_save_'.length))
          .toList();
      _isLoading = false;
    });
  }

  Future<void> _loadGame(String saveName) async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? saveString = prefs.getString('game_save_$saveName');
      if (saveString == null) {
        throw Exception("Sauvegarde non trouvée.");
      }

      final Map<String, dynamic> saveObject = jsonDecode(saveString);
      final int targetScore = saveObject['targetScore'];
      final List<dynamic> playersJson = saveObject['players'];
      final List<Player> players = playersJson
          .map((json) => Player.fromJson(json))
          .toList();
      final gameData = GameData(players: players, targetScore: targetScore);

      if (mounted) {
        soundManager.playClick(settings.volume);
        Navigator.pop(context, gameData);
      }
    } catch (e) {
      if (mounted) {
        soundManager.playError(settings.volume);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur de chargement : $e')));
      }
    }
  }

  Future<void> _deleteGame(String saveName) async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    soundManager.playClick(settings.volume);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('game_save_$saveName');
    _fetchSavedGames();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Charger une partie Pomme')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _saveNames.isEmpty
          ? const Center(
              child: Text(
                'Aucune sauvegarde trouvée.',
                style: TextStyle(fontSize: 18),
              ),
            )
          : ListView.builder(
              itemCount: _saveNames.length,
              itemBuilder: (context, index) {
                final saveName = _saveNames[index];
                return ListTile(
                  title: Text(saveName, style: const TextStyle(fontSize: 20)),
                  leading: const Icon(Icons.list_alt),
                  onTap: () => _loadGame(saveName),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _deleteGame(saveName),
                  ),
                );
              },
            ),
    );
  }
}
