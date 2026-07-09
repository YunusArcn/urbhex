import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/map_screen.dart';

// Frontend'e SADECE anon key konur (RLS herkese okuma izni verir).
// Derleme: flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  final prefs = await SharedPreferences.getInstance();
  runApp(UrbhexApp(
    onboarded: prefs.getBool('onboarded') ?? false,
    purpose: prefs.getString('purpose') ?? 'kesif',
  ));
}

class UrbhexApp extends StatelessWidget {
  final bool onboarded;
  final String purpose;
  const UrbhexApp({super.key, required this.onboarded, required this.purpose});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Urbhex',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1B5E20),
        useMaterial3: true,
      ),
      // Uygulama HER ZAMAN canli haritayla acilir; ilk ziyarette amac
      // kartlari haritanin USTUNDE yuzer (beyaz bekleme ekrani yok).
      home: MapScreen(
        startDetailed: onboarded && purpose == 'tasinma',
        startPanelOpen: onboarded ? purpose != 'kesif' : null,
        showOnboarding: !onboarded,
      ),
    );
  }
}
