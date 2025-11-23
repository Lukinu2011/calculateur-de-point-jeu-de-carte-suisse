// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'pages/Parametrage/home_page.dart';

// --- GESTIONNAIRE DE SONS ---
class SoundManager {
  final AudioPlayer _clickPlayer = AudioPlayer();
  final AudioPlayer _errorPlayer = AudioPlayer();

  SoundManager() {
    _clickPlayer.setPlayerMode(PlayerMode.lowLatency);
    _errorPlayer.setPlayerMode(PlayerMode.lowLatency);
    // Assurez-vous que ces chemins d'accès aux assets sont corrects
    // _clickPlayer.setSource(AssetSource('audio/click.mp3'));
    // _errorPlayer.setSource(AssetSource('audio/error.mp3'));
  }

  void playClick(double volume) {
    _clickPlayer.play(AssetSource('audio/click.mp3'), volume: volume);
  }

  void playError(double volume) {
    _errorPlayer.play(AssetSource('audio/error.mp3'), volume: volume);
  }

  void dispose() {
    _clickPlayer.dispose();
    _errorPlayer.dispose();
  }
}

final soundManager = SoundManager();

// --- Fournisseur de Paramètres (State Management) ---
class SettingsProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  double _volume = 1.0;

  bool get isDarkMode => _isDarkMode;
  double get volume => _volume;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    _volume = prefs.getDouble('volume') ?? 1.0;
    notifyListeners();
  }

  void toggleTheme(bool isOn) async {
    _isDarkMode = isOn;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('isDarkMode', _isDarkMode);
  }

  void setVolume(double newVolume) async {
    _volume = newVolume;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.setDouble('volume', _volume);
  }
}

// --- MODIFIÉ : Modèle de données Pomme ---
class PommeGameData {
  final String saveName;
  final String autoSaveKey;
  final List<Player> players;
  final int targetScore;
  final String? lastSaveTime; // NOUVEAU: Date de dernière sauvegarde

  PommeGameData({
    required this.saveName,
    required this.autoSaveKey,
    required this.players,
    required this.targetScore,
    this.lastSaveTime,
  });

  Map<String, dynamic> toJson() => {
    'saveName': saveName,
    'autoSaveKey': autoSaveKey,
    'targetScore': targetScore,
    'players': players.map((player) => player.toJson()).toList(),
    'lastSaveTime': lastSaveTime,
  };

  factory PommeGameData.fromJson(Map<String, dynamic> json) {
    var playersJson = json['players'] as List;
    List<Player> players = playersJson
        .map((pJson) => Player.fromJson(pJson))
        .toList();

    return PommeGameData(
      saveName: json['saveName'] as String,
      autoSaveKey: json['autoSaveKey'] as String,
      players: players,
      targetScore: json['targetScore'] as int,
      lastSaveTime: json['lastSaveTime'] as String?,
    );
  }
}

class Player {
  String name;
  int points;
  int pommes;
  Player({required this.name, this.points = 0, this.pommes = 0});
  int get score => points - pommes;
  Map<String, dynamic> toJson() => {
    'name': name,
    'points': points,
    'pommes': pommes,
  };
  factory Player.fromJson(Map<String, dynamic> json) => Player(
    name: json['name'],
    points: json['points'],
    pommes: json['pommes'],
  );
}

// --- Fonction main() ---
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (context) => SettingsProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        return MaterialApp(
          title: 'Jeu de Pommes',
          debugShowCheckedModeBanner: false,
          themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          theme: ThemeData(
            primarySwatch: Colors.red,
            brightness: Brightness.light,
            visualDensity: VisualDensity.adaptivePlatformDensity,
          ),
          darkTheme: ThemeData(
            primarySwatch: Colors.red,
            brightness: Brightness.dark,
            visualDensity: VisualDensity.adaptivePlatformDensity,
          ),
          home: const HomePage(),
        );
      },
    );
  }
}
