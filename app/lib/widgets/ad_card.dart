import 'package:flutter/material.dart';

import '../screens/ad_pricing_screen.dart';

/// Haber akisina gomulu dogal reklam karti.
/// Sponsor yoksa "Burada reklam verin" cagrisi gosterir → fiyat sayfasina gider.
/// PDR kurali: reklam haber kartiyla ayni gorsel dilde olur ama "Sponsorlu"
/// etiketiyle acikca isaretlenir (kullanici aldatilmaz).
class AdCard extends StatelessWidget {
  const AdCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AdPricingScreen()),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B5E20).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.campaign_outlined,
                    color: Color(0xFF1B5E20)),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bu bölgenin sponsoru olun',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 2),
                    Text(
                      'İşletmenizi tam burada, bölgeyle ilgilenen kullanıcılara gösterin.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              Chip(
                label: const Text('Sponsorlu', style: TextStyle(fontSize: 10)),
                visualDensity: VisualDensity.compact,
                side: BorderSide(color: Colors.grey.shade400),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
