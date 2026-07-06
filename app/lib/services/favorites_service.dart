import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/hex_score.dart';

/// Kayitli konumlar: Ev / Is / Diger (uyelik gerektirir; RLS korur).
/// Guvenlik Alarmi (alert_enabled) premium ozelliktir — lansmanda ucretsiz.
class FavoritesService {
  final _client = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> list() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];
    return List<Map<String, dynamic>>.from(
      await _client
          .from('favorites')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false),
    );
  }

  Future<bool> isFavorite(String h3Res9) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    final row = await _client
        .from('favorites')
        .select('id')
        .eq('user_id', user.id)
        .eq('h3_res9', h3Res9)
        .maybeSingle();
    return row != null;
  }

  /// Konumu etiketiyle kaydeder: kind = 'ev' | 'is' | 'diger'.
  Future<void> add(HexScore hex, {required String label, required String kind}) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('login_required');
    await _client.from('favorites').upsert({
      'user_id': user.id,
      'h3_res9': hex.h3Res9,
      'label': label,
      'kind': kind,
      'lat': hex.lat,
      'lng': hex.lng,
      'alert_enabled': true, // lansman donemi: alarm herkese acik
    }, onConflict: 'user_id,h3_res9');
  }

  Future<void> removeByHex(String h3Res9) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    await _client
        .from('favorites')
        .delete()
        .eq('user_id', user.id)
        .eq('h3_res9', h3Res9);
  }

  Future<void> remove(String id) async {
    await _client.from('favorites').delete().eq('id', id);
  }

  /// Guvenlik Alarmi ac/kapa (premium bayragi).
  Future<void> setAlert(String id, bool enabled) async {
    await _client.from('favorites').update({'alert_enabled': enabled}).eq('id', id);
  }
}
