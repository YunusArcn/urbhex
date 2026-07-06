import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/hex_score.dart';
import '../models/incident.dart';

/// Tum Supabase okuma islemleri tek serviste (Single Responsibility).
class SupabaseService {
  final _client = Supabase.instance.client;

  /// Bounding Box + tarih filtresi: sadece gorunen alan, secilen donem.
  Future<List<HexScore>> hexesInBbox({
    required double minLat,
    required double minLng,
    required double maxLat,
    required double maxLng,
    int sinceDays = 36500,
  }) async {
    final rows = await _client.rpc('hexes_in_bbox_since', params: {
      'min_lat': minLat,
      'min_lng': minLng,
      'max_lat': maxLat,
      'max_lng': maxLng,
      'since_days': sinceDays,
    });
    return (rows as List).map((r) => HexScore.fromJson(r)).toList();
  }

  /// Sol panel: gorunen alandaki olaylar (en yeniden eskiye).
  Future<List<Incident>> incidentsInBbox({
    required double minLat,
    required double minLng,
    required double maxLat,
    required double maxLng,
    int sinceDays = 36500,
    int maxRows = 50,
  }) async {
    final rows = await _client.rpc('incidents_in_bbox', params: {
      'min_lat': minLat,
      'min_lng': minLng,
      'max_lat': maxLat,
      'max_lng': maxLng,
      'since_days': sinceDays,
      'max_rows': maxRows,
    });
    return (rows as List).map((r) => Incident.fromJson(r)).toList();
  }

  /// Tarama istegini kuyruga yazar; olusan kaydin id'sini dondurur.
  Future<String> requestScan({
    required double minLat,
    required double minLng,
    required double maxLat,
    required double maxLng,
  }) async {
    final row = await _client
        .from('scan_requests')
        .insert({
          'min_lat': minLat,
          'min_lng': minLng,
          'max_lat': maxLat,
          'max_lng': maxLng,
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  /// Tarama isteginin durumunu sorgular (pending/processing/done/failed).
  Future<Map<String, dynamic>?> scanStatus(String id) =>
      _client.from('scan_requests').select().eq('id', id).maybeSingle();

  /// Hex zaman cizelgesi (tarih filtresine uyar).
  Future<List<Incident>> incidentsInHex(
    String h3Res9, {
    int sinceDays = 36500,
    int page = 0,
    int pageSize = 200,
  }) async {
    final rows = await _client.rpc('incidents_in_hex_since', params: {
      'hex': h3Res9,
      'since_days': sinceDays,
      'page_size': pageSize,
      'page_offset': page * pageSize,
    });
    return (rows as List).map((r) => Incident.fromJson(r)).toList();
  }
}
