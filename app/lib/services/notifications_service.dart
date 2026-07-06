import 'package:supabase_flutter/supabase_flutter.dart';

/// Guvenlik Alarmi bildirimleri (bot yazar, kullanici okur — RLS korur).
class NotificationsService {
  final _client = Supabase.instance.client;

  bool get loggedIn => _client.auth.currentUser != null;

  /// Son bildirimler; olayin konumu da gelir (haritaya odaklanmak icin).
  Future<List<Map<String, dynamic>>> list({int limit = 30}) async {
    if (!loggedIn) return [];
    return List<Map<String, dynamic>>.from(
      await _client
          .from('notifications')
          .select('*, incidents(lat, lng)')
          .order('created_at', ascending: false)
          .limit(limit),
    );
  }

  Future<int> unreadCount() async {
    if (!loggedIn) return 0;
    final rows = await _client.from('notifications').select('id').eq('read', false);
    return (rows as List).length;
  }

  Future<void> markAllRead() async {
    if (!loggedIn) return;
    await _client.from('notifications').update({'read': true}).eq('read', false);
  }
}
