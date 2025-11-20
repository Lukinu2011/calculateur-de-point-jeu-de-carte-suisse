import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../main.dart'; // Importe soundManager et SettingsProvider

// --- PAGE 5 : Page de Paramètres ---
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        return Scaffold(
          appBar: AppBar(title: const Text('Paramètres')),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- 1. Thème Dark ---
                SwitchListTile(
                  title: const Text('Mode Sombre'),
                  secondary: Icon(
                    settings.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                  ),
                  value: settings.isDarkMode,
                  onChanged: (bool newValue) {
                    soundManager.playClick(settings.volume);
                    settings.toggleTheme(newValue);
                  },
                ),

                const Divider(),
                const SizedBox(height: 20),

                // --- 2. Jauge de Volume ---
                const Text('Volume des sons', style: TextStyle(fontSize: 18)),

                Slider(
                  value: settings.volume,
                  min: 0.0,
                  max: 1.0,
                  divisions: 100,
                  label: '${(settings.volume * 100).round()}%',
                  onChanged: (double newValue) {
                    settings.setVolume(newValue);
                  },
                  onChangeEnd: (double newValue) {
                    soundManager.playClick(newValue);
                  },
                ),

                Center(
                  child: Text(
                    '${(settings.volume * 100).round()}%',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
