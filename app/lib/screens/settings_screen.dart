import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/favorites_service.dart';
import '../services/notifications_service.dart';
import '../widgets/tier_avatar.dart';

/// Ayarlar: profil, kayitli konumlar (Ev/Is + Guvenlik Alarmi) ve bildirimler.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _auth = AuthService();
  final _favorites = FavoritesService();
  final _notifications = NotificationsService();
  final _nameController = TextEditingController();
  String _avatarValue = ''; // "preset:N"
  String _tier = 'bronz';
  List<Map<String, dynamic>> _favs = [];
  List<Map<String, dynamic>> _notifs = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await _auth.getProfile();
    final favs = await _favorites.list();
    final notifs = await _notifications.list(limit: 10);
    if (!mounted) return;
    setState(() {
      _nameController.text = profile?['display_name'] ?? '';
      _avatarValue = profile?['avatar_url'] ?? '';
      _tier = profile?['tier'] ?? 'bronz';
      _favs = favs;
      _notifs = notifs;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await _auth.updateProfile(
      displayName: _nameController.text.trim(),
      avatarUrl: _avatarValue,
    );
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Profil kaydedildi')));
    }
  }

  IconData _kindIcon(String? kind) => switch (kind) {
        'ev' => Icons.home,
        'is' => Icons.work,
        _ => Icons.place,
      };

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: user == null
          ? const Center(child: Text('Önce giriş yapmalısın.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: TierAvatar(
                    avatarValue: _avatarValue,
                    fallbackInitial: (_nameController.text.isNotEmpty
                        ? _nameController.text[0]
                        : (user.email ?? 'U')[0]),
                    tier: _tier,
                    radius: 40,
                  ),
                ),
                const SizedBox(height: 8),
                Center(child: Text(user.email ?? '')),
                const SizedBox(height: 6),
                Center(
                  child: Chip(
                    avatar: Icon(Icons.workspace_premium,
                        size: 16, color: TierAvatar.tierColor(_tier)),
                    label: Text(
                      '${TierAvatar.tierLabel(_tier)} — lansmanda tüm özellikler açık',
                      style: const TextStyle(fontSize: 12),
                    ),
                    side: BorderSide(color: TierAvatar.tierColor(_tier)),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                      labelText: 'Görünen ad', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                const Text('Profil görseli seç',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                // Hazir avatar paleti — URL girisi kaldirildi (guvenlik).
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (var i = 0; i < TierAvatar.presets.length; i++)
                      GestureDetector(
                        onTap: () =>
                            setState(() => _avatarValue = 'preset:$i'),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              width: 2.5,
                              color: _avatarValue == 'preset:$i'
                                  ? TierAvatar.tierColor(_tier)
                                  : Colors.transparent,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 22,
                            backgroundColor: TierAvatar.presets[i].$1,
                            child: Icon(TierAvatar.presets[i].$2,
                                color: Colors.white, size: 22),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: const Text('Profili kaydet'),
                ),

                const Divider(height: 40),
                Text('Kayıtlı Konumlarım',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),

                // Premium bilgilendirmesi (lansman: ucretsiz deneme)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(children: [
                    Icon(Icons.workspace_premium, color: Colors.amber.shade800),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Güvenlik Alarmı — Premium özellik, lansman süresince '
                        'ÜCRETSİZ. Açık olduğunda konumunun 2 km çevresindeki '
                        'her yeni olayda bildirim + e-posta alırsın.',
                        style: TextStyle(fontSize: 12.5),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 8),

                if (_favs.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('Henüz kayıtlı konumun yok. Haritada bir '
                        'altıgene dokunup kalp simgesine bas; Ev veya İş '
                        'olarak kaydet.'),
                  ),
                for (final fav in _favs)
                  Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: Icon(_kindIcon(fav['kind'] as String?),
                          color: const Color(0xFF1B5E20)),
                      title: Text(fav['label'] ?? 'Konumum'),
                      subtitle: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Text('Alarm', style: TextStyle(fontSize: 12)),
                        Switch(
                          value: fav['alert_enabled'] == true,
                          onChanged: (v) async {
                            await _favorites.setAlert(fav['id'], v);
                            _load();
                          },
                        ),
                      ]),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          await _favorites.remove(fav['id']);
                          _load();
                        },
                      ),
                      onTap: () => Navigator.pop(
                          context, (fav['lat'] as num, fav['lng'] as num)),
                    ),
                  ),

                const Divider(height: 40),
                Text('Son Bildirimlerim',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (_notifs.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('Henüz bildirim yok.'),
                  ),
                for (final n in _notifs)
                  ListTile(
                    dense: true,
                    leading: Icon(
                      n['read'] == true
                          ? Icons.notifications_none
                          : Icons.notifications_active,
                      color: n['read'] == true ? null : Colors.red,
                    ),
                    title: Text(n['title'] ?? '',
                        style: const TextStyle(fontSize: 13)),
                    subtitle: Text(n['body'] ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12)),
                  ),

                const Divider(height: 40),
                OutlinedButton.icon(
                  icon: const Icon(Icons.logout),
                  label: const Text('Çıkış yap'),
                  onPressed: () async {
                    await _auth.signOut();
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
              ],
            ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}
