import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/favorites_service.dart';

/// Ayarlar: profil (isim + profil fotografi) ve favori bolgeler.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _auth = AuthService();
  final _favorites = FavoritesService();
  final _nameController = TextEditingController();
  final _avatarController = TextEditingController();
  List<Map<String, dynamic>> _favs = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await _auth.getProfile();
    final favs = await _favorites.list();
    if (!mounted) return;
    setState(() {
      _nameController.text = profile?['display_name'] ?? '';
      _avatarController.text = profile?['avatar_url'] ?? '';
      _favs = favs;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await _auth.updateProfile(
      displayName: _nameController.text.trim(),
      avatarUrl: _avatarController.text.trim(),
    );
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Profil kaydedildi')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final avatarUrl = _avatarController.text.trim();
    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: user == null
          ? const Center(child: Text('Önce giriş yapmalısın.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 40,
                    backgroundImage:
                        avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                    child: avatarUrl.isEmpty
                        ? Text(
                            (_nameController.text.isNotEmpty
                                    ? _nameController.text[0]
                                    : (user.email ?? 'U')[0])
                                .toUpperCase(),
                            style: const TextStyle(fontSize: 28))
                        : null,
                  ),
                ),
                const SizedBox(height: 8),
                Center(child: Text(user.email ?? '')),
                const SizedBox(height: 24),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                      labelText: 'Görünen ad', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _avatarController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Profil fotoğrafı (URL)',
                    hintText: 'https://... (boş bırakılırsa baş harfin gösterilir)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: const Text('Profili kaydet'),
                ),
                const Divider(height: 40),
                Text('Favori Bölgelerim',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (_favs.isEmpty)
                  const Text('Henüz favori bölgen yok. Haritada bir altıgene '
                      'dokunup kalp simgesine bas.'),
                for (final fav in _favs)
                  ListTile(
                    leading: const Icon(Icons.favorite, color: Colors.red),
                    title: Text(fav['label'] ?? 'Favori bölgem'),
                    subtitle: Text(
                        '(${(fav['lat'] as num).toStringAsFixed(4)}, ${(fav['lng'] as num).toStringAsFixed(4)})'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        await _favorites.remove(fav['id']);
                        _load();
                      },
                    ),
                    // Favoriye dokununca harita oraya odaklansin diye konum doner.
                    onTap: () => Navigator.pop(
                        context, (fav['lat'] as num, fav['lng'] as num)),
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
    _avatarController.dispose();
    super.dispose();
  }
}
