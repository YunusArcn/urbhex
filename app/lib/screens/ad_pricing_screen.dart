import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// "Burada reklam verin" akisinin indigi fiyatlandirma sayfasi.
/// PDR gelir modeli 1: hiper-yerel sponsorluk (hex/bolge kiralama).
class AdPricingScreen extends StatelessWidget {
  const AdPricingScreen({super.key});

  static const _packages = [
    (
      'Semt Sponsoru',
      '500 TL/ay',
      'Seçtiğin 3 altıgen bölgede haber akışının üstünde işletme kartın gösterilir.',
      Icons.storefront,
    ),
    (
      'İlçe Sponsoru',
      '2.000 TL/ay',
      'İlçedeki tüm bölgelerde dönüşümlü doğal reklam kartı + logo.',
      Icons.location_city,
    ),
    (
      'Bölge Analiz Raporu',
      '1.500 TL/rapor',
      'Emlak profesyonelleri için PDF güvenlik ve yaşanabilirlik raporu.',
      Icons.description,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Urbhex\'te Reklam Verin')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'İşletmeni tam da müşterinin baktığı bölgede göster',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Urbhex kullanıcıları taşınacakları veya yatırım yapacakları '
                'bölgeyi incelerken senin kartını görür. Reklamlar haber '
                'akışına doğal biçimde yerleşir, rahatsız etmez.',
              ),
              const SizedBox(height: 20),
              for (final p in _packages)
                Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Icon(p.$4, size: 36, color: const Color(0xFF1B5E20)),
                    title: Text('${p.$1}  —  ${p.$2}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(p.$3),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              FilledButton.icon(
                icon: const Icon(Icons.mail_outline),
                label: const Text('İletişime geç: reklam@urbhex.com'),
                onPressed: () => launchUrl(
                  Uri.parse('mailto:reklam@urbhex.com?subject=Urbhex Reklam'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
