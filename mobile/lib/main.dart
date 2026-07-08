/// Point d'entrée de l'application mobile MIDAS-Bénin.
///
/// Initialise Flutter et enveloppe l'application dans un ProviderScope
/// (Riverpod) pour la gestion d'état globale.
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: MidasApp()));
}
