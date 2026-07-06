import 'package:flutter/material.dart';

import '../services/livability_service.dart';
import '../utils/responsive.dart';

/// "Yasam & Ulasim" sekmesi: gezilecek yerler, olanaklar ve toplu tasima.
/// Veri OpenStreetMap'ten CANLI cekilir (hex merkezi ~1.2 km).
class LivabilityPanel extends StatefulWidget {
  final double lat;
  final double lng;
  const LivabilityPanel({super.key, required this.lat, required this.lng});

  @override
  State<LivabilityPanel> createState() => _LivabilityPanelState();
}

class _LivabilityPanelState extends State<LivabilityPanel> {
  final _service = LivabilityService();
  LivabilityInfo? _info;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final info = await _service.fetch(widget.lat, widget.lng);
      if (mounted) setState(() => _info = info);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Olanak verisi şu an alınamadı (OpenStreetMap yoğun olabilir) — '
            'birkaç saniye sonra tekrar dene.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ff = formFactorOf(context);
    if (_error != null) {
      return Center(
          child: Padding(padding: const EdgeInsets.all(20), child: Text(_error!)));
    }
    final info = _info;
    if (info == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(padding: const EdgeInsets.all(16), children: [
      _scoreBar('Sosyal Yaşam', info.socialScore, Icons.local_activity, ff),
      const SizedBox(height: 10),
      _scoreBar('Toplu Taşıma Erişimi', info.transitScore, Icons.directions_bus, ff),
      const SizedBox(height: 18),
      Text('Bu bölgede (1 km çevrede)',
          style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 14 * ff.scale)),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        _chip(Icons.local_cafe, 'Kafe & Restoran', info.cafes, ff),
        _chip(Icons.shopping_cart, 'Market', info.markets, ff),
        _chip(Icons.park, 'Park & Spor', info.parks, ff),
        _chip(Icons.local_hospital, 'Sağlık', info.health, ff),
        _chip(Icons.school, 'Eğitim', info.schools, ff),
        _chip(Icons.directions_bus, 'Otobüs durağı', info.busStops, ff),
        _chip(Icons.tram, 'Raylı ulaşım', info.railStops, ff),
      ]),
      const SizedBox(height: 16),
      Text(
        'Veriler OpenStreetMap\'ten canlı alınır. Toplu taşıma oranı, durak '
        'yoğunluğundan türetilen yaklaşık bir göstergedir; yol-km bazlı kesin '
        'hesap yol haritasındadır.',
        style: TextStyle(fontSize: 11 * ff.scale, color: Colors.grey.shade600),
      ),
    ]);
  }

  Widget _scoreBar(String label, int score, IconData icon, FormFactor ff) {
    final color = score > 65
        ? Colors.green
        : (score > 35 ? Colors.orange : Colors.red);
    return Row(children: [
      Icon(icon, size: 22 * ff.scale, color: color),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$label  ·  $score/100',
              style: TextStyle(
                  fontSize: 13 * ff.scale, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: score / 100,
              minHeight: 8,
              color: color,
              backgroundColor: color.withOpacity(0.15),
            ),
          ),
        ]),
      ),
    ]);
  }

  Widget _chip(IconData icon, String label, int count, FormFactor ff) {
    return Chip(
      avatar: Icon(icon, size: 16 * ff.scale, color: const Color(0xFF1B5E20)),
      label: Text('$label: $count', style: TextStyle(fontSize: 12 * ff.scale)),
      visualDensity: VisualDensity.compact,
    );
  }
}
