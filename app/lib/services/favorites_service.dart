import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/hex_score.dart';

/// Favori bolge islemleri (uyelik gerektirir; RLS kullanici bazli korur).
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

  /// Ekli ise cikarir, degilse ekler. Yeni durumu dondurur.
  Future<bool> toggle(HexScore hex, {String? label}) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('login_required');

    if (await isFavorite(hex.h3Res9)) {
      await _client
          .from('favorites')
          .delete()
          .eq('user_id', user.id)
          .eq('h3_res9', hex.h3Res9);
      return false;
    }
    await _client.from('favorites').insert({
      'user_id': user.id,
      'h3_res9': hex.h3Res9,
      'label': label ?? 'Favori bölgem',
      'lat': hex.lat,
      'lng': hex.lng,
    });
    return true;
  }

  Future<void> remove(String id) async {
    await _client.from('favorites').delete().eq('id', id);
  }
}
