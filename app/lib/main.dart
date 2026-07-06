import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/map_screen.dart';
import 'screens/onboarding_screen.dart';

// Frontend'e SADECE anon key konur (RLS herkese okuma izni verir).
// Derleme: flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  final prefs = await SharedPreferences.getInstance();
  runApp(HabitexApp(
    onboarded: prefs.getBool('onboarded') ?? false,
    purpose: prefs.getString('purpose') ?? 'kesif',
  ));
}

class HabitexApp extends StatelessWidget {
  final bool onboarded;
  final String purpose;
  const HabitexApp({super.key, required this.onboarded, required this.purpose});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Urbhex',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1B5E20),
        useMaterial3: true,
      ),
      // Ilk ziyaret: amac secimi. Sonraki ziyaretler: dogrudan harita
      // (logo animasyonu yok — sinematik yaklasma karsilar).
      home: onboarded
          ? MapScreen(
              startDetailed: purpose == 'tasinma',
              startPanelOpen: purpose != 'kesif',
            )
          : const OnboardingScreen(),
    );
  }
}
