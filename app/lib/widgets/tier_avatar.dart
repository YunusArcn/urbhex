import 'package:flutter/material.dart';

/// Uyelik kademesine gore halkali profil avatari.
/// avatarValue: "preset:N" (hazir avatar) veya http URL (eski kayitlar) veya null.
/// tier: 'bronz' | 'gumus' | 'altin' — halka rengini belirler.
class TierAvatar extends StatelessWidget {
  final String? avatarValue;
  final String fallbackInitial;
  final String tier;
  final double radius;

  const TierAvatar({
    super.key,
    required this.avatarValue,
    required this.fallbackInitial,
    required this.tier,
    required this.radius,
  });

  /// Hazir avatar paleti: (arka plan, ikon). URL yok → guvenlik riski yok.
  static const presets = <(Color, IconData)>[
    (Color(0xFF1B5E20), Icons.person),
    (Color(0xFF00695C), Icons.rocket_launch),
    (Color(0xFF283593), Icons.sailing),
    (Color(0xFF6A1B9A), Icons.music_note),
    (Color(0xFFAD1457), Icons.favorite),
    (Color(0xFFBF360C), Icons.local_fire_department),
    (Color(0xFF4E342E), Icons.coffee),
    (Color(0xFF37474F), Icons.sports_esports),
    (Color(0xFF2E7D32), Icons.hiking),
    (Color(0xFF0277BD), Icons.pets),
    (Color(0xFFF9A825), Icons.bolt),
    (Color(0xFF5D4037), Icons.brush),
  ];

  static Color tierColor(String tier) => switch (tier) {
        'altin' => const Color(0xFFFFC107),
        'gumus' => const Color(0xFF90A4AE),
        _ => const Color(0xFFCD7F32), // bronz
      };

  static String tierLabel(String tier) => switch (tier) {
        'altin' => 'Altın Üye',
        'gumus' => 'Gümüş Üye',
        _ => 'Bronz Üye',
      };

  @override
  Widget build(BuildContext context) {
    final ring = tierColor(tier);
    final value = avatarValue ?? '';

    Widget inner;
    if (value.startsWith('preset:')) {
      final i = (int.tryParse(value.substring(7)) ?? 0) % presets.length;
      inner = CircleAvatar(
        radius: radius,
        backgroundColor: presets[i].$1,
        child: Icon(presets[i].$2, color: Colors.white, size: radius * 1.05),
      );
    } else if (value.startsWith('http')) {
      inner = CircleAvatar(radius: radius, backgroundImage: NetworkImage(value));
    } else {
      inner = CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFF1B5E20),
        child: Text(fallbackInitial.toUpperCase(),
            style: TextStyle(color: Colors.white, fontSize: radius * 0.85)),
      );
    }

    // Kademeli halka: ic ince beyaz cizgi + dis renkli cember (oranli).
    return Container(
      padding: EdgeInsets.all(radius * 0.12),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ring, ring.withOpacity(0.55)],
        ),
      ),
      child: Container(
        padding: EdgeInsets.all(radius * 0.07),
        decoration: const BoxDecoration(
            shape: BoxShape.circle, color: Colors.white),
        child: inner,
      ),
    );
  }
}
