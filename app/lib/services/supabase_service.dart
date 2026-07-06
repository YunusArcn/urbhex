import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/hex_score.dart';
import '../models/incident.dart';

/// Tum Supabase okuma islemleri tek serviste (Single Responsibility).
class SupabaseService {
  final _client = Supabase.instance.client;

  /// Bounding Box kurali: sadece ekranda gorunen alanin hex'leri cekilir.
  Future<List<HexScore>> hexesInBbox({
    required double minLat,
    required double minLng,
    required double maxLat,
    required double maxLng,
  }) async {
    final rows = await _client.rpc('hexes_in_bbox', params: {
      'min_lat': minLat,
      'min_lng': minLng,
      'max_lat': maxLat,
      'max_lng': maxLng,
    });
    return (rows as List).map((r) => HexScore.fromJson(r)).toList();
  }

  /// Tarama istegini kuyruga yazar (migration_v4: scan_requests).
  /// Bot bu kuyruktaki bolgeleri onceliklendirerek kalici veri uretir.
  Future<void> requestScan({
    required double minLat,
    required double minLng,
    required double maxLat,
    required double maxLng,
  }) async {
    await _client.from('scan_requests').insert({
      'min_lat': minLat,
      'min_lng': minLng,
      'max_lat': maxLat,
      'max_lng': maxLng,
    });
  }

  /// Zaman cizelgesi: sonsuz kaydirma icin sayfali olay listesi.
  Future<List<Incident>> incidentsInHex(String h3Res9, {int page = 0, int pageSize = 20}) async {
    final rows = await _client.rpc('incidents_in_hex', params: {
      'hex': h3Res9,
      'page_size': pageSize,
      'page_offset': page * pageSize,
    });
    return (rows as List).map((r) => Incident.fromJson(r)).toList();
  }
}
