import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'router.dart';

class MidasApp extends ConsumerWidget {
  const MidasApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'MIDAS-Bénin',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF006B3F),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF006B3F),
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
