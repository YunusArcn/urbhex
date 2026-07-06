import 'dart:convert';

import 'package:http/http.dart' as http;

/// "Bu bolgeyi tara": ekrandaki alan icin GDELT GEO 2.0'dan son 7 gunun
/// asayis haberlerini ANLIK ceker (ucretsiz, anahtarsiz, dunya geneli).
/// Sonuclar gecici katmandir — veritabanina yazilmaz; kalici kayit botun isi.
class ScanResult {
  final double lat;
  final double lng;
  final String name;
  final int count;
  final List<String> urls;

  const ScanResult({
    required this.lat,
    required this.lng,
    required this.name,
    required this.count,
    required this.urls,
  });
}

class ScanService {
  static const _query =
      '(murder OR robbery OR assault OR theft OR shooting OR crime '
      'OR cinayet OR gasp OR "trafik kazası" OR hırsızlık)';

  Future<List<ScanResult>> scanBbox({
    required double minLat,
    required double minLng,
    required double maxLat,
    required double maxLng,
  }) async {
    final uri = Uri.parse(
      'https://api.gdeltproject.org/api/v2/geo/geo'
      '?query=${Uri.encodeComponent(_query)}&format=GeoJSON&timespan=7d',
    );
    final resp = await http.get(uri).timeout(const Duration(seconds: 20));
    if (resp.statusCode != 200) {
      throw Exception('GDELT yanit vermedi (${resp.statusCode})');
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final results = <ScanResult>[];
    for (final f in (data['features'] as List? ?? [])) {
      final coords = f['geometry']?['coordinates'];
      if (coords is! List || coords.length < 2) continue;
      final lng = (coords[0] as num).toDouble();
      final lat = (coords[1] as num).toDouble();
      if (lat < minLat || lat > maxLat || lng < minLng || lng > maxLng) {
        continue; // sadece ekranda gorunen alan
      }
      final props = f['properties'] as Map<String, dynamic>? ?? {};
      final html = props['html'] as String? ?? '';
      final urls = RegExp(r'href="([^"]+)"')
          .allMatches(html)
          .map((m) => m.group(1)!)
          .where((u) => u.startsWith('http'))
          .take(5)
          .toList();
      results.add(ScanResult(
        lat: lat,
        lng: lng,
        name: props['name'] as String? ?? 'Bilinmeyen konum',
        count: (props['count'] as num?)?.toInt() ?? 1,
        urls: urls,
      ));
    }
    return results;
  }
}
