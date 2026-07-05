import 'package:supabase_flutter/supabase_flutter.dart';

/// Kimlik islemleri: Google OAuth + e-posta/sifre (dogrulama mailli).
class AuthService {
  final _client = Supabase.instance.client;

  User? get currentUser => _client.auth.currentUser;
  bool get isLoggedIn => currentUser != null;
  Stream<AuthState> get onAuthChange => _client.auth.onAuthStateChange;

  /// Google ile giris — Supabase yonlendirmeli OAuth (web'de yeni sekme acilir).
  Future<void> signInWithGoogle() =>
      _client.auth.signInWithOAuth(OAuthProvider.google);

  /// Kayit: Supabase dogrulama e-postasi gonderir; kullanici onaylayana
  /// kadar oturum acilmaz (Dashboard'da "Confirm email" acik olmali).
  Future<void> signUp(String email, String password) =>
      _client.auth.signUp(email: email, password: password);

  Future<void> signIn(String email, String password) =>
      _client.auth.signInWithPassword(email: email, password: password);

  Future<void> signOut() => _client.auth.signOut();

  Future<Map<String, dynamic>?> getProfile() async {
    final user = currentUser;
    if (user == null) return null;
    return _client.from('profiles').select().eq('id', user.id).maybeSingle();
  }

  Future<void> updateProfile({String? displayName, String? avatarUrl}) async {
    final user = currentUser;
    if (user == null) return;
    await _client.from('profiles').update({
      if (displayName != null) 'display_name': displayName,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
    }).eq('id', user.id);
  }
}
