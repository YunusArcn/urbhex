import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/analytics/analytics.dart';
import 'map_screen.dart';

/// Ilk ziyaret karsilamasi: kullanici amacini secer, deneyim ona gore kurulur.
///  - Tasinma / ev arama  → ayrintili harita + haber paneli
///  - Haber & asayis      → sade harita + olay akisi
///  - Kesif               → varsayilan sade gorunum
/// Kartlar sirayla kayarak belirir (modern, sakin animasyon).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100))
    ..forward();

  Future<void> _pick(String purpose) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarded', true);
    await prefs.setString('purpose', purpose);
    Analytics.capture('onboarding_purpose', {'purpose': purpose});
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => MapScreen(
        startDetailed: purpose == 'tasinma',
        startPanelOpen: purpose != 'kesif',
      ),
    ));
  }

  Widget _card({
    required int index,
    required IconData icon,
    required String title,
    required String subtitle,
    required String purpose,
    required Color color,
  }) {
    // Kartlar sirayla belirir: her karta kaydirilmis zaman araligi.
    final anim = CurvedAnimation(
      parent: _ctrl,
      curve: Interval(0.15 + index * 0.18, 0.6 + index * 0.18,
          curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: anim,
      builder: (context, child) => Opacity(
        opacity: anim.value,
        child: Transform.translate(
            offset: Offset(0, 28 * (1 - anim.value)), child: child),
      ),
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _pick(purpose),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 12.5, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final headerAnim =
        CurvedAnimation(parent: _ctrl, curve: const Interval(0, 0.35));
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF7),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              FadeTransition(
                opacity: headerAnim,
                child: Column(children: [
                  const Icon(Icons.hexagon,
                      size: 46, color: Color(0xFF1B5E20)),
                  const SizedBox(height: 8),
                  Text.rich(
                    const TextSpan(children: [
                      TextSpan(
                          text: 'urb',
                          style: TextStyle(fontWeight: FontWeight.w300)),
                      TextSpan(
                          text: 'hex',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1B5E20))),
                    ]),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 10),
                  const Text('Hoş geldin! Seni en doğru deneyime götürelim.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15)),
                  Text('Urbhex\'i ne için kullanacaksın?',
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey.shade600)),
                  const SizedBox(height: 20),
                ]),
              ),
              _card(
                index: 0,
                icon: Icons.home_work,
                color: const Color(0xFF1B5E20),
                title: 'Taşınma / ev arama',
                subtitle:
                    'Ayrıntılı harita, güvenlik skorları ve bölge olanaklarıyla başla',
                purpose: 'tasinma',
              ),
              _card(
                index: 1,
                icon: Icons.newspaper,
                color: const Color(0xFF283593),
                title: 'Haber & asayiş takibi',
                subtitle: 'Sade harita ve bölgendeki olay akışıyla başla',
                purpose: 'haber',
              ),
              _card(
                index: 2,
                icon: Icons.explore,
                color: const Color(0xFFBF360C),
                title: 'Sadece keşfediyorum',
                subtitle: 'Haritayı özgürce gez, gerisini sonra ayarlarsın',
                purpose: 'kesif',
              ),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
}
