import 'package:flutter/material.dart';

class PublishScreen extends StatelessWidget {
  const PublishScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar Negocio o Servicio')),
      body: const Center(
        child: Text('Formulario para publicar un negocio'),
      ),
    );
  }
}