// lib/pages/Pomme/load_game_pomme_page.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart'; // Nécessaire pour formater lastSaveTime
import 'package:provider/provider.dart';

import '../../main.dart'; // Pour PommeGameData, soundManager et SettingsProvider
import 'setup_pomme_page.dart'; // Pour les préfixes

class LoadGamePommePage extends StatefulWidget {
  const LoadGamePommePage({super.key});

  @override
  State<LoadGamePommePage> createState() => _LoadGamePommePageState();
}

class _LoadGamePommePageState extends State<LoadGamePommePage> {
  // Liste pour stocker les clés de sauvegarde des parties
  List<String> _saveKeys = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSaveKeys();
  }

  // Charge les clés des parties sauvegardées
  Future<void> _loadSaveKeys() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys();
    setState(() {
      // Filtre toutes les clés qui commencent par nos préfixes
      _saveKeys = allKeys
          .where(
            (key) =>
                key.startsWith(pommeSavePrefix) ||
                key.startsWith(pommeAutoSavePrefix),
          )
          .toList();
      _isLoading = false;
    });
  }

  // Charge une partie et navigue vers la page de jeu
  void _loadGame(String key) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? saveString = prefs.getString(key);

    if (saveString != null) {
      final gameData = PommeGameData.fromJson(
        jsonDecode(saveString) as Map<String, dynamic>,
      );
      if (mounted) {
        Navigator.pop(context, gameData); // Retourne les données
      }
    } else {
      // Gère le cas où la clé existe mais le contenu a disparu (rare)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur: Fichier de sauvegarde non trouvé.'),
        ),
      );
    }
  }

  // Supprime une partie
  void _deleteGame(String key) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final settings = Provider.of<SettingsProvider>(context, listen: false);

    soundManager.playClick(settings.volume);
    await prefs.remove(key);

    _loadSaveKeys(); // Rafraîchit la liste
  }

  // Fonction pour charger toutes les données de sauvegarde pour l'affichage
  Future<List<PommeGameData>> _loadAllSaveData() async {
    final prefs = await SharedPreferences.getInstance();
    List<PommeGameData> allData = [];
    for (var key in _saveKeys) {
      final String? saveString = prefs.getString(key);
      if (saveString != null) {
        try {
          final data = PommeGameData.fromJson(
            jsonDecode(saveString) as Map<String, dynamic>,
          );
          allData.add(data);
        } catch (e) {
          // Ignore les fichiers corrompus et passe au suivant
        }
      }
    }
    return allData;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Charger une partie de Pomme')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _saveKeys.isEmpty
          ? const Center(child: Text('Aucune partie sauvegardée trouvée.'))
          : FutureBuilder<List<PommeGameData>>(
              // Charge les données de toutes les sauvegardes pour l'affichage
              future: _loadAllSaveData(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text('Aucune partie sauvegardée trouvée.'),
                  );
                }

                final allSaves = snapshot.data!;

                // Trie par date de dernière sauvegarde (plus récente d'abord)
                allSaves.sort((a, b) {
                  final timeA =
                      DateTime.tryParse(a.lastSaveTime ?? '') ?? DateTime(2000);
                  final timeB =
                      DateTime.tryParse(b.lastSaveTime ?? '') ?? DateTime(2000);
                  return timeB.compareTo(
                    timeA,
                  ); // Du plus récent au plus ancien
                });

                return ListView.builder(
                  itemCount: allSaves.length,
                  itemBuilder: (context, index) {
                    final gameData = allSaves[index];
                    // Retrouve la clé originale dans _saveKeys pour le chargement/suppression
                    final key = _saveKeys.firstWhere(
                      (k) =>
                          k == gameData.autoSaveKey ||
                          k == '$pommeSavePrefix${gameData.saveName}',
                      orElse: () =>
                          '', // Clé introuvable, ne devrait pas arriver
                    );

                    String displayName = gameData.saveName;
                    String subtitleText =
                        'Joueurs: ${gameData.players.length} | Objectif: ${gameData.targetScore}';

                    // Détermine si c'est une autosauvegarde
                    final isAutoSave = key.startsWith(pommeAutoSavePrefix);
                    if (isAutoSave) {
                      displayName = 'Sauvegarde Auto: ${gameData.saveName}';
                    }

                    if (gameData.lastSaveTime != null) {
                      final saveTime =
                          DateTime.tryParse(gameData.lastSaveTime!) ??
                          DateTime.now();
                      subtitleText +=
                          ' | Dernière Save: ${DateFormat('dd/MM/yyyy HH:mm').format(saveTime)}';
                    }

                    return ListTile(
                      title: Text(
                        displayName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(subtitleText),
                      leading: Icon(isAutoSave ? Icons.autorenew : Icons.save),
                      onTap: () => _loadGame(key),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteGame(key),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
