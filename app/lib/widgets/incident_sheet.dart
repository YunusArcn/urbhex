import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/hex_score.dart';
import '../models/incident.dart';
import '../screens/auth_screen.dart';
import '../services/analytics/analytics.dart';
import '../services/favorites_service.dart';
import '../services/supabase_service.dart';
import '../utils/responsive.dart';
import 'ad_card.dart';

/// Bolge detay paneli:
///  - Guvenlik skoru + favori (kalp) butonu
///  - Olay TURLERI alt alta, tiklanabilir (ExpansionTile)
///  - Acilan turde olaylar ozetiyle okunur, orijinal kaynak linklerine gidilir
///  - Araya dogal reklam kartlari girer (2 tur grubunda bir)
class IncidentSheet extends StatefulWidget {
  final HexScore hex;
  final int sinceDays; // haritadaki tarih filtresine uyar
  const IncidentSheet({super.key, required this.hex, this.sinceDays = 36500});

  @override
  State<IncidentSheet> createState() => _IncidentSheetState();
}

class _IncidentSheetState extends State<IncidentSheet> {
  final _service = SupabaseService();
  final _favorites = FavoritesService();
  List<Incident> _incidents = [];
  bool _loading = true;
  bool _isFav = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Panel tur gruplari gosterdigi icin olaylar tek seferde cekilir (hex
    // basina olay sayisi sinirli; sayfalama tur ici listede gerekirse V2'de).
    final results = await Future.wait([
      _service.incidentsInHex(widget.hex.h3Res9,
          sinceDays: widget.sinceDays, page: 0, pageSize: 200),
      _favorites.isFavorite(widget.hex.h3Res9),
    ]);
    if (!mounted) return;
    setState(() {
      _incidents = results[0] as List<Incident>;
      _isFav = results[1] as bool;
      _loading = false;
    });
  }

  Future<void> _toggleFavorite() async {
    try {
      final nowFav = await _favorites.toggle(widget.hex);
      Analytics.capture(nowFav ? 'favorite_add' : 'favorite_remove');
      if (mounted) setState(() => _isFav = nowFav);
    } on StateError {
      // Uye degil → giris ekranina yonlendir, donunce tekrar dene.
      if (!mounted) return;
      final loggedIn = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const AuthScreen()),
      );
      if (loggedIn == true) _toggleFavorite();
    }
  }

  Map<String, List<Incident>> get _byType {
    final map = <String, List<Incident>>{};
    for (final i in _incidents) {
      map.putIfAbsent(i.eventType, () => []).add(i);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final ff = formFactorOf(context);
    final content = Column(children: [
      _buildHeader(ff),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _buildGroupedList(ff),
      ),
    ]);

    if (ff.sidePanel) return content; // masaustu: yan panelde tam boy
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: ff.sheetInitialSize,
      builder: (context, _) => content,
    );
  }

  Widget _buildHeader(FormFactor ff) {
    final score = widget.hex.safetyScore;
    final color = score > 70
        ? Colors.green
        : (score > 40 ? Colors.orange : Colors.red);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        CircleAvatar(
          radius: 26 * ff.scale,
          backgroundColor: color,
          child: Text('$score',
              style: TextStyle(
                  color: Colors.white, fontSize: 18 * ff.scale,
                  fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Güvenlik Skoru (1-100)',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Text('Bu ~300 metrelik alanda ${widget.hex.incidentCount} kayıtlı olay'),
          ]),
        ),
        IconButton(
          iconSize: 26 * ff.scale,
          tooltip: _isFav ? 'Favorilerden çıkar' : 'Bölgeyi favorile',
          icon: Icon(_isFav ? Icons.favorite : Icons.favorite_border,
              color: _isFav ? Colors.red : null),
          onPressed: _toggleFavorite,
        ),
      ]),
    );
  }

  Widget _buildGroupedList(FormFactor ff) {
    final groups = _byType.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    final children = <Widget>[];
    for (var i = 0; i < groups.length; i++) {
      final type = groups[i].key;
      final items = groups[i].value;
      children.add(ExpansionTile(
        leading: Icon(eventTypeIcon(type), size: 22 * ff.scale),
        title: Text(items.first.eventTypeLabel,
            style: TextStyle(fontSize: 15 * ff.scale)),
        trailing: CircleAvatar(
          radius: 12 * ff.scale,
          child: Text('${items.length}',
              style: TextStyle(fontSize: 11 * ff.scale)),
        ),
        children: [for (final inc in items) _IncidentCard(incident: inc)],
      ));
      // Dogal reklam: her 2 tur grubundan sonra bir kart.
      if (i.isOdd) children.add(const AdCard());
    }
    if (groups.isNotEmpty && groups.length < 2) children.add(const AdCard());

    return ListView(children: children);
  }
}

class _IncidentCard extends StatelessWidget {
  final Incident incident;
  const _IncidentCard({required this.incident});

  @override
  Widget build(BuildContext context) {
    final d = incident.occurredOn;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(
              '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const Spacer(),
            if (incident.sourceCount > 1)
              Text('${incident.sourceCount} kaynak doğruladı',
                  style: TextStyle(color: Colors.green.shade700, fontSize: 12)),
          ]),
          const SizedBox(height: 6),
          Text(incident.summary),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Habere Git (Kaynak)'),
              onPressed: () => _openSources(context),
            ),
          ),
        ]),
      ),
    );
  }

  void _openSources(BuildContext context) {
    // Gelir kaniti: "Kocaeli'de su kadar haber kaynaga yonlendirildi" verisi.
    Analytics.capture('news_source_click', {
      'event_type': incident.eventType,
      'district': incident.district,
    });
    if (incident.sourceUrls.length == 1) {
      launchUrl(Uri.parse(incident.sourceUrls.first),
          mode: LaunchMode.externalApplication);
      return;
    }
    showDialog(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Kaynaklar'),
        children: [
          for (final url in incident.sourceUrls)
            SimpleDialogOption(
              child: Text(Uri.parse(url).host,
                  style: const TextStyle(color: Colors.blue)),
              onPressed: () {
                Navigator.pop(context);
                launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
              },
            ),
        ],
      ),
    );
  }
}
