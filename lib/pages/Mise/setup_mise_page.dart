import 'package:flutter/material.dart';

// La classe est également renommée
class SetupMisePage extends StatelessWidget {
  const SetupMisePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuration Mise'), // Titre mis à jour
      ),
      body: const Center(child: Text('')),
    );
  }
}
