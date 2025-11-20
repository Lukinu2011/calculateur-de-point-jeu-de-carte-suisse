import 'package:flutter/material.dart';

class SetupJassPage extends StatelessWidget {
  const SetupJassPage({super.key}); // <-- AJOUTEZ CONST// ...
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuration Jass'), // Titre mis à jour
      ),
      body: const Center(child: Text('')),
    );
  }
}
