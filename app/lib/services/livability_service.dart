import 'dart:convert';

import 'package:http/http.dart' as http;

/// Yasam & Ulasim verisi: OpenStreetMap/Overpass'tan CANLI cekilir
/// (ucretsiz, anahtarsiz). Kapsam: hex merkezinin ~1.2 km cevresi.
class LivabilityInfo {
  final int cafes; // kafe/restoran
  final int markets; // market/supermarket
  final int parks; // park/spor alani
  final int health; // saglik (hastane/eczane)
  final int schools; // okul/universite
  final int busStops; // otobus duragi
  final int railStops; // tramvay/tren istasyonu

  const LivabilityInfo({
    required this.cafes,
    required this.markets,
    required this.parks,
    required this.health,
    required this.schools,
    required this.busStops,
    required this.railStops,
  });

  /// Sosyal yasam skoru 0-100 (olanak yogunlugundan turetilir).
  int get socialScore =>
      ((cafes * 3 + markets * 4 + parks * 5 + health * 4 + schools * 3))
          .clamp(0, 100);

  /// Toplu tasima erisim orani 0-100 (durak yogunlugu yaklasimi).
  /// Not: "yol km'sinin yuzde kacinda hat geciyor" hesabi agir bir sunucu
  /// isidir (V2); bu oran durak yogunlugundan turetilen yaklasik gostergedir.
  int get transitScore => (busStops * 7 + railStops * 20).clamp(0, 100);
}

class LivabilityService {
  static const _radius = 1200; // metre

  Future<LivabilityInfo> fetch(double lat, double lng) async {
    final query = '''
[out:json][timeout:20];
(
  node(around:$_radius,$lat,$lng)[amenity~"^(cafe|restaurant|fast_food)\$"];
  node(around:$_radius,$lat,$lng)[shop~"^(supermarket|convenience|mall)\$"];
  node(around:$_radius,$lat,$lng)[leisure~"^(park|playground|fitness_centre|sports_centre)\$"];
  way(around:$_radius,$lat,$lng)[leisure=park];
  node(around:$_radius,$lat,$lng)[amenity~"^(hospital|clinic|pharmacy)\$"];
  node(around:$_radius,$lat,$lng)[amenity~"^(school|university|college)\$"];
  node(around:$_radius,$lat,$lng)[highway=bus_stop];
  node(around:$_radius,$lat,$lng)[railway~"^(tram_stop|station|halt)\$"];
);
out tags center 400;''';

    final resp = await http
        .post(Uri.parse('https://overpass-api.de/api/interpreter'),
            body: {'data': query})
        .timeout(const Duration(seconds: 25));
    if (resp.statusCode != 200) {
      throw Exception('Overpass yanit vermedi (${resp.statusCode})');
    }

    var cafes = 0, markets = 0, parks = 0, health = 0, schools = 0;
    var bus = 0, rail = 0;
    final elements =
        (jsonDecode(resp.body) as Map<String, dynamic>)['elements'] as List? ?? [];
    for (final e in elements) {
      final tags = e['tags'] as Map<String, dynamic>? ?? {};
      final amenity = tags['amenity'] as String? ?? '';
      if (tags['highway'] == 'bus_stop') {
        bus++;
      } else if (tags.containsKey('railway')) {
        rail++;
      } else if (['cafe', 'restaurant', 'fast_food'].contains(amenity)) {
        cafes++;
      } else if (tags.containsKey('shop')) {
        markets++;
      } else if (tags.containsKey('leisure')) {
        parks++;
      } else if (['hospital', 'clinic', 'pharmacy'].contains(amenity)) {
        health++;
      } else if (['school', 'university', 'college'].contains(amenity)) {
        schools++;
      }
    }
    return LivabilityInfo(
      cafes: cafes,
      markets: markets,
      parks: parks,
      health: health,
      schools: schools,
      busStops: bus,
      railStops: rail,
    );
  }
}
