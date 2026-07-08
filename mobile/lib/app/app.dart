/// Widget racine de l'application MIDASBJ.
///
/// Configure Material 3 avec un thème blanc, noir, rouge foncé,
/// support des modes clair/sombre, et le routeur GoRouter.
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'router.dart';

class MidasApp extends ConsumerWidget {
  const MidasApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    const darkRed = Color(0xFF8B1A1A);

    final lightScheme = ColorScheme.fromSeed(
      seedColor: darkRed,
      brightness: Brightness.light,
      surface: Colors.white,
    ).copyWith(
      surfaceContainerHighest: const Color(0xFFF0F0F0),
      surfaceContainerLow: const Color(0xFFF7F7F7),
      surfaceContainerHigh: const Color(0xFFE8E8E8),
      outline: const Color(0xFFB0B0B0),
      outlineVariant: const Color(0xFFD6D6D6),
      onSurface: const Color(0xFF1A1A1A),
      shadow: Colors.black.withValues(alpha: 0.08),
    );

    final darkScheme = ColorScheme.fromSeed(
      seedColor: darkRed,
      brightness: Brightness.dark,
    ).copyWith(
      onSurface: const Color(0xFFF0F0F0),
    );

    return MaterialApp.router(
      title: 'MIDASBJ',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: lightScheme,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 0.5,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
        ),
        navigationBarTheme: NavigationBarThemeData(
          elevation: 0,
          indicatorColor: darkRed.withValues(alpha: 0.1),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF8B1A1A),
              );
            }
            return TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF1A1A1A).withValues(alpha: 0.6),
            );
          }),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: darkRed,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF1A1A1A),
            side: BorderSide(color: darkRed.withValues(alpha: 0.3)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
        ),
        chipTheme: ChipThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          side: BorderSide.none,
        ),
        inputDecorationTheme: InputDecorationTheme(
          labelStyle: const TextStyle(color: Color(0xFF1A1A1A)),
          hintStyle: TextStyle(color: const Color(0xFF1A1A1A).withValues(alpha: 0.4)),
          prefixIconColor: const Color(0xFF1A1A1A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD6D6D6)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD6D6D6)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1A1A1A)),
          ),
          filled: true,
          fillColor: const Color(0xFFF5F5F5),
        ),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: Color(0xFF1A1A1A),
          selectionColor: Color(0xFF1A1A1A),
          selectionHandleColor: Color(0xFF1A1A1A),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: darkScheme,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 0.5,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
        ),
      ),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
