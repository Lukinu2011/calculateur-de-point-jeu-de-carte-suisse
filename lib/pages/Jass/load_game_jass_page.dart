// lib/pages/Jass/load_game_jass_page.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart'; // NÉCESSAIRE pour formater la date
import 'game_jass_page.dart'; // Pour JassGameData et GameJassPage

// Préfixes de sauvegarde pour Jass
// Ces constantes doivent être définies dans setup_jass_page.dart ou un fichier de constantes
const String jassSavePrefix = 'jass_save_';
const String jassAutoSavePrefix = 'jass_autosave_';

// Modèle pour gérer l'affichage des sauvegardes
class SaveEntry {
  final String key;
  final String saveName;
  final DateTime lastSaveTime;
  final bool isAutoSave;

  SaveEntry({
    required this.key,
    required this.saveName,
    required this.lastSaveTime,
    required this.isAutoSave,
  });
}

class LoadGameJassPage extends StatefulWidget {
  const LoadGameJassPage({super.key});

  @override
  State<LoadGameJassPage> createState() => _LoadGameJassPageState();
}

class _LoadGameJassPageState extends State<LoadGameJassPage> {
  List<SaveEntry> _saveEntries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSaveEntries();
  }

  // Charge les données de chaque partie pour l'affichage et le tri
  Future<void> _loadSaveEntries() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    // Utilise une liste unique pour stocker toutes les clés (manuelles et auto)
    List<String> saveKeys = prefs.getStringList('jass_save_keys') ?? [];

    List<SaveEntry> loadedEntries = [];

    for (String key in saveKeys) {
      final String? jsonString = prefs.getString(key);
      if (jsonString != null) {
        try {
          final gameData = JassGameData.fromJson(jsonDecode(jsonString));
          final bool isAutoSave = key.startsWith(jassAutoSavePrefix);

          final String displayName;
          if (isAutoSave) {
            displayName = 'Sauvegarde Auto: ${gameData.saveName}';
          } else {
            // Affiche la clé sans le préfixe 'jass_save_' (le nom donné par l'utilisateur)
            displayName = key.substring(jassSavePrefix.length);
          }

          loadedEntries.add(
            SaveEntry(
              key: key,
              saveName: displayName,
              // lastSaveTime est un String formatable en Date
              lastSaveTime:
                  DateTime.tryParse(gameData.lastSaveTime ?? '') ??
                  DateTime.now(),
              isAutoSave: isAutoSave,
            ),
          );
        } catch (e) {
          debugPrint("Erreur lors du chargement de la clé $key: $e");
        }
      }
    }

    // Tri des sauvegardes par date décroissante
    loadedEntries.sort((a, b) => b.lastSaveTime.compareTo(a.lastSaveTime));

    setState(() {
      _saveEntries = loadedEntries;
      _isLoading = false;
    });
  }

  // Charge une partie et navigue vers la page de jeu
  void _loadGame(String key) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? saveString = prefs.getString(key);

    if (saveString != null) {
      final gameData = JassGameData.fromJson(jsonDecode(saveString));

      // Navigue vers la page de jeu avec les données chargées (renvoyé à setup_jass_page.dart)
      if (mounted) {
        Navigator.pop(context, gameData);
      }
    }
  }

  // Supprime une partie
  void _deleteGame(String key) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);

    // Met à jour la liste des clés de sauvegarde brutes
    List<String> saveKeys = prefs.getStringList('jass_save_keys') ?? [];
    saveKeys.remove(key);
    await prefs.setStringList('jass_save_keys', saveKeys);

    _loadSaveEntries(); // Rafraîchit la liste des entrées de sauvegarde
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Charger une partie de Jass')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _saveEntries.isEmpty
          ? const Center(child: Text('Aucune partie sauvegardée trouvée.'))
          : ListView.builder(
              itemCount: _saveEntries.length,
              itemBuilder: (context, index) {
                final entry = _saveEntries[index];
                return ListTile(
                  leading: entry.isAutoSave
                      ? const Icon(Icons.sync, color: Colors.blue)
                      : const Icon(Icons.save),
                  title: Text(entry.saveName),
                  subtitle: Text(
                    'Sauvegardé le: ${DateFormat('dd/MM/yyyy HH:mm').format(entry.lastSaveTime)}',
                  ),
                  onTap: () => _loadGame(entry.key),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteGame(entry.key),
                  ),
                );
              },
            ),
    );
  }
}
