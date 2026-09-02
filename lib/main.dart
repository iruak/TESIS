import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/historial_screen.dart';
import 'screens/agregar_vaca_screen.dart';
import 'screens/ordeno_screen.dart';
import 'screens/historial_vaca_screen.dart';
import 'screens/control_remoto_screen.dart';

import 'screens/bienvenida_screen.dart';

void main() {
  runApp(const SistemaOrdenoApp());
}

class SistemaOrdenoApp extends StatelessWidget {
  const SistemaOrdenoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sistema Ordeño',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32), // Verde rural
          primary: const Color(0xFF2E7D32),
          secondary: const Color(0xFF795548), // Tono tierra
          surface: const Color(0xFFF1F8E9), // Fondo claro verdoso
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const BienvenidaScreen(),
        '/home': (context) => const HomeScreen(),
        '/historial': (context) => const HistorialScreen(),
        '/agregar_vaca': (context) => const AgregarVacaScreen(),
        '/ordeno': (context) => const OrdenoScreen(),
        '/historial_vaca': (context) => const HistorialVacaScreen(),
        '/control_remoto': (context) => const ControlRemotoScreen(),
      },
    );
  }
}
