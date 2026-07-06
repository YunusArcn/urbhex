import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/hex_score.dart';
import '../models/incident.dart';
import '../services/analytics/analytics.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../services/notifications_service.dart';
import '../services/supabase_service.dart';
import '../utils/hex_utils.dart';
import '../utils/responsive.dart';
import '../widgets/incident_sheet.dart';
import '../widgets/tier_avatar.dart';
import 'auth_screen.dart';
import 'settings_screen.dart';

/// Ana ekran: sakin (bulutlu) isi haritasi + tarih filtresi + sol haber paneli
/// + oneri getiren arama + bolge tarama (kuyruk + canli bekleme).
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

/// Tarih filtresi secenekleri.
const _dateFilters = [
  (label: 'Bugün', days: 1),
  (label: 'Son 3 gün', days: 3),
  (label: 'Son 2 hafta', days: 14),
  (label: 'Son 1 ay', days: 30),
  (label: 'Son 1 yıl', days: 365),
  (label: 'Tümü', days: 36500),
];

class _MapScreenState extends State<MapScreen> {
  static const _izmitCenter = LatLng(40.7654, 29.9408);
  static const _detailZoom = 13.0;

  final _service = SupabaseService();
  final _auth = AuthService();
  final _notifications = NotificationsService();
  final _mapController = MapController();
  final _searchController = TextEditingController();

  List<HexScore> _hexes = [];
  List<Incident> _visibleIncidents = [];
  Map<String, dynamic>? _profile; // avatar + uyelik kademesi (halka rengi)
  int _unread = 0;
  List<(String, LatLng)> _suggestions = [];
  int _sinceDays = 3; // varsayılan: Son 3 gün
  bool _filterPinned = false; // kullanıcı elle seçtiyse otomatik genişletme yok
  bool _detailedTiles = false; // false = sakin (Normal), true = Ayrıntılı (OSM)
  bool _panelOpen = true;
  bool _scanning = false;
  double _zoom = 13;
  Timer? _debounce;
  Timer? _searchDebounce;
  bool _disclaimerShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showDisclaimer();
      _panelOpen = formFactorOf(context) != FormFactor.mobile;
      _startFromUserLocation();
    });
    _auth.onAuthChange.listen((_) {
      if (mounted) {
        setState(() {});
        _refreshUnread();
      }
    });
    _refreshUnread();
  }

  Future<void> _refreshUnread() async {
    final n = await _notifications.unreadCount();
    final profile = await _auth.getProfile();
    if (mounted) {
      setState(() {
        _unread = n;
        _profile = profile;
      });
    }
  }

  Future<void> _startFromUserLocation() async {
    final pos = await LocationService.currentPosition();
    if (pos != null && mounted) {
      _mapController.move(pos, 14);
    }
    _reloadData();
  }

  void _showDisclaimer() {
    if (_disclaimerShown) return;
    _disclaimerShown = true;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      duration: Duration(seconds: 8),
      content: Text(
        'Bu platform acik kaynakli haberleri matematiksel olarak gorsellestirir. '
        'Kesin emlak veya yatirim tavsiyesi degildir.',
      ),
    ));
  }

  /// Gorunen alan + tarih filtresine gore hex'leri VE sol panel listesini cek.
  Future<void> _reloadData() async {
    final b = _mapController.camera.visibleBounds;
    try {
      final results = await Future.wait([
        _service.hexesInBbox(
          minLat: b.south, minLng: b.west, maxLat: b.north, maxLng: b.east,
          sinceDays: _sinceDays,
        ),
        _service.incidentsInBbox(
          minLat: b.south, minLng: b.west, maxLat: b.north, maxLng: b.east,
          sinceDays: _sinceDays,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _hexes = results[0] as List<HexScore>;
        _visibleIncidents = results[1] as List<Incident>;
      });
      _maybeExpandPeriod();
    } catch (e) {
      debugPrint('veri yukleme hatasi: $e');
    }
  }

  /// Varsayilan "Son 3 gun" bos kalirsa donemi otomatik genislet
  /// (kullanici filtreyi ELLE sectiyse dokunma).
  static const _expandChain = [3, 30, 365, 36500];

  void _maybeExpandPeriod() {
    if (_filterPinned || _hexes.isNotEmpty || _visibleIncidents.isNotEmpty) {
      return;
    }
    final i = _expandChain.indexOf(_sinceDays);
    if (i < 0 || i >= _expandChain.length - 1) return;
    final next = _expandChain[i + 1];
    final label = _dateFilters.firstWhere((f) => f.days == next).label;
    setState(() => _sinceDays = next);
    _toast('Bu dönemde olay yok — "$label" gösteriliyor.');
    _reloadData();
  }

  void _onMapMoved(MapEvent event) {
    _zoom = _mapController.camera.zoom;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _reloadData);
  }

  bool get _detailed => _zoom >= _detailZoom;

  // ---------------- BOLGE TARAMA (kuyruk + canli bekleme) ----------------

  /// Butona basinca: istek kuyruklanir, bot isleyene kadar durum izlenir,
  /// bitince harita kendiliginden yenilenir.
  Future<void> _scanVisibleArea() async {
    setState(() => _scanning = true);
    final b = _mapController.camera.visibleBounds;
    Analytics.capture('scan_click', {
      'lat': _mapController.camera.center.latitude,
      'lng': _mapController.camera.center.longitude,
    });
    try {
      final id = await _service.requestScan(
        minLat: b.south, minLng: b.west, maxLat: b.north, maxLng: b.east,
      );
      _toast('Bölge tarama kuyruğuna alındı — bot çalışınca sonuçlar düşecek.');

      // 2 dakika boyunca 4 sn'de bir durum kontrolu (bot lokal/bulutta calisiyorsa).
      for (var i = 0; i < 30; i++) {
        await Future.delayed(const Duration(seconds: 4));
        if (!mounted) return;
        final status = await _service.scanStatus(id);
        if (status?['status'] == 'done') {
          await _reloadData();
          _toast('Tarama bitti: ${status?['found_count'] ?? 0} olay haritaya eklendi.');
          break;
        }
        if (status?['status'] == 'failed') {
          _toast('Bu bölge için haber bulunamadı veya tarama başarısız oldu.');
          break;
        }
        if (i == 29) {
          _toast('İstek kuyrukta — bot en geç 15 dk içinde işleyecek, '
              'sonuçlar otomatik görünecek.');
        }
      }
    } catch (e) {
      _toast('Tarama isteği gönderilemedi — bağlantıyı kontrol et.');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---------------- ARAMA (oneriler: yerel takma adlar + Nominatim) --------

  static const _aliases = <String, (String, LatLng)>{
    'kocaeli': ('İzmit, Kocaeli', LatLng(40.7654, 29.9408)),
    'izmit': ('İzmit, Kocaeli', LatLng(40.7654, 29.9408)),
  };

  void _onSearchChanged(String q) {
    _searchDebounce?.cancel();
    if (q.trim().length < 2) {
      setState(() => _suggestions = []);
      return;
    }
    _searchDebounce =
        Timer(const Duration(milliseconds: 350), () => _fetchSuggestions(q));
  }

  Future<void> _fetchSuggestions(String q) async {
    final results = <(String, LatLng)>[];
    final alias = _aliases[q.toLowerCase().trim()];
    if (alias != null) results.add(alias);

    try {
      // Oneri dili, cihazin/konumun diline gore (accept-language).
      final lang = ui.PlatformDispatcher.instance.locale.toLanguageTag();
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(q)}&format=json&limit=5&accept-language=$lang',
      );
      final resp = await http.get(uri).timeout(const Duration(seconds: 8));
      for (final r in (jsonDecode(resp.body) as List)) {
        results.add((
          r['display_name'] as String,
          LatLng(double.parse(r['lat']), double.parse(r['lon'])),
        ));
      }
    } catch (_) {/* oneri gelmezse sadece takma adlar kalir */}

    if (mounted) setState(() => _suggestions = results.take(6).toList());
  }

  void _pickSuggestion((String, LatLng) s) {
    Analytics.capture('search_pick', {'place': s.$1});
    _searchController.text = s.$1.split(',').first;
    setState(() => _suggestions = []);
    _mapController.move(s.$2, 13.5);
    _reloadData();
  }

  // ---------------- GORUNUM ----------------

  @override
  Widget build(BuildContext context) {
    final ff = formFactorOf(context);
    return Scaffold(
      body: Stack(children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _izmitCenter,
            initialZoom: 13,
            onMapEvent: _onMapMoved,
            onTap: (_, point) {
              setState(() => _suggestions = []);
              if (_detailed) _handleTap(point);
            },
          ),
          children: [
            // Normal: sade/pastel altlik (goz yormaz). Ayrintili: klasik OSM.
            TileLayer(
              urlTemplate: _detailedTiles
                  ? 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'
                  : 'https://basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.urbhex.app',
            ),
            PolygonLayer(
              polygons: [
                for (final hex in _hexes)
                  Polygon(
                    points: HexUtils.hexagonVertices(hex.lat, hex.lng),
                    color: HexUtils.fillColor(hex.safetyScore),
                    // "bulutlu" gorunum: kenar cizgisi yok
                    borderStrokeWidth: 0,
                  ),
              ],
            ),
            if (_detailed)
              MarkerLayer(markers: _eventIconMarkers(ff))
            else
              MarkerLayer(markers: _clusterMarkers(ff)),
          ],
        ),
        if (_panelOpen) _buildNewsPanel(ff),
        _buildTopBar(ff),
      ]),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'scan',
            onPressed: _scanning ? null : _scanVisibleArea,
            icon: _scanning
                ? const SizedBox(
                    height: 18, width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.radar),
            label: Text(_scanning ? 'Taranıyor...' : 'Bu bölgede haber tara'),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.small(
            heroTag: 'panel',
            tooltip: _panelOpen ? 'Haber panelini gizle' : 'Haber panelini aç',
            onPressed: () => setState(() => _panelOpen = !_panelOpen),
            child: Icon(_panelOpen ? Icons.list_alt : Icons.list),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.small(
            heroTag: 'loc',
            tooltip: 'Konumuma git',
            onPressed: _startFromUserLocation,
            child: const Icon(Icons.my_location),
          ),
        ],
      ),
    );
  }

  /// Sol panel: gorunen alandaki haberler ve ozetleri.
  Widget _buildNewsPanel(FormFactor ff) {
    final width = ff == FormFactor.mobile
        ? MediaQuery.sizeOf(context).width * 0.85
        : 340.0 * ff.scale;
    return Positioned(
      left: 0,
      top: 90,
      bottom: 12,
      width: width,
      child: Card(
        margin: const EdgeInsets.only(left: 12),
        elevation: 6,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
            child: Row(children: [
              const Icon(Icons.feed_outlined, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Bu alandaki haberler (${_visibleIncidents.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => setState(() => _panelOpen = false),
              ),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: _visibleIncidents.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'Bu alan ve dönemde kayıtlı haber yok.\n'
                        '"Bu bölgede haber tara" ile bölgeyi taratabilirsin.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: _visibleIncidents.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final inc = _visibleIncidents[i];
                      final d = inc.occurredOn;
                      return ListTile(
                        dense: true,
                        leading: Icon(inc.icon, size: 20 * ff.scale),
                        title: Text(
                          inc.summary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12.5 * ff.scale),
                        ),
                        subtitle: Text(
                          '${inc.eventTypeLabel} · ${inc.district} · '
                          '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}',
                          style: TextStyle(fontSize: 10.5 * ff.scale),
                        ),
                        onTap: () {
                          _mapController.move(LatLng(inc.lat, inc.lng), 15);
                          _reloadData();
                        },
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }

  /// Yakin zoom: buyutulmus ikon + anlik skor rozeti.
  List<Marker> _eventIconMarkers(FormFactor ff) {
    final w = 42.0 * ff.scale;
    final h = 58.0 * ff.scale;
    return [
      for (final hex in _hexes)
        Marker(
          point: LatLng(hex.lat, hex.lng),
          width: w,
          height: h,
          child: GestureDetector(
            onTap: () => _onHexTapped(hex),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 34 * ff.scale,
                height: 34 * ff.scale,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: HexUtils.clusterColor(hex.safetyScore), width: 2.5),
                ),
                child: Icon(
                  eventTypeIcon(hex.topEventType),
                  size: 19 * ff.scale,
                  color: HexUtils.clusterColor(hex.safetyScore),
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6 * ff.scale),
                decoration: BoxDecoration(
                  color: HexUtils.clusterColor(hex.safetyScore),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  '${hex.safetyScore}',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 11.5 * ff.scale,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ]),
          ),
        ),
    ];
  }

  /// Uzak zoom: res-7 kumeleri.
  List<Marker> _clusterMarkers(FormFactor ff) {
    final groups = <String, List<HexScore>>{};
    for (final hex in _hexes) {
      groups.putIfAbsent(hex.h3Res7, () => []).add(hex);
    }
    return [
      for (final entry in groups.entries)
        () {
          final members = entry.value;
          final total = members.fold(0, (s, h) => s + h.incidentCount);
          final avgScore =
              (members.fold(0, (s, h) => s + h.safetyScore) / members.length)
                  .round();
          final center = LatLng(
            members.fold(0.0, (s, h) => s + h.lat) / members.length,
            members.fold(0.0, (s, h) => s + h.lng) / members.length,
          );
          final base = total > 99 ? 50.0 : (total > 20 ? 44.0 : 36.0);
          final size = base * ff.scale;
          return Marker(
            point: center,
            width: size,
            height: size,
            child: GestureDetector(
              onTap: () => _mapController.move(center, _detailZoom + 0.5),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: HexUtils.clusterColor(avgScore),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Text('$total',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13 * ff.scale)),
              ),
            ),
          );
        }(),
    ];
  }

  void _onHexTapped(HexScore hex) {
    Analytics.capture('hex_tap', {
      'safety_score': hex.safetyScore,
      'incident_count': hex.incidentCount,
      'top_event_type': hex.topEventType,
    });
    final ff = formFactorOf(context);
    if (ff.sidePanel) {
      showDialog(
        context: context,
        builder: (_) => Dialog(
          alignment: Alignment.centerRight,
          insetPadding: const EdgeInsets.all(16),
          child: SizedBox(
              width: 460,
              child: IncidentSheet(hex: hex, sinceDays: _sinceDays)),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => IncidentSheet(hex: hex, sinceDays: _sinceDays),
      );
    }
  }

  void _handleTap(LatLng point) {
    const d = Distance();
    for (final hex in _hexes) {
      if (d.as(LengthUnit.Meter, point, LatLng(hex.lat, hex.lng)) < 200) {
        _onHexTapped(hex);
        return;
      }
    }
  }

  Widget _buildTopBar(FormFactor ff) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: ff.searchBarMaxWidth),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(28),
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        decoration: InputDecoration(
                          hintText: 'Şehir veya mahalle ara...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                        ),
                      ),
                    ),
                    if (_suggestions.isNotEmpty)
                      Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(12),
                        child: Column(children: [
                          for (final s in _suggestions)
                            ListTile(
                              dense: true,
                              leading:
                                  const Icon(Icons.place_outlined, size: 18),
                              title: Text(s.$1,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13)),
                              onTap: () => _pickSuggestion(s),
                            ),
                        ]),
                      ),
                  ]),
                ),
              ),
            ),
            const SizedBox(width: 6),
            _buildDateFilter(ff),
            const SizedBox(width: 6),
            _buildStyleToggle(ff),
            const SizedBox(width: 6),
            _buildBellButton(ff),
            const SizedBox(width: 6),
            _buildProfileButton(ff),
          ]),
        ]),
      ),
    );
  }

  /// Sag ust: tarih filtresi (Bugun / 3 gun / 2 hafta / 1 ay / 1 yil / Tumu).
  Widget _buildDateFilter(FormFactor ff) {
    final current =
        _dateFilters.firstWhere((f) => f.days == _sinceDays).label;
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(22),
      child: PopupMenuButton<int>(
        tooltip: 'Tarih filtresi',
        initialValue: _sinceDays,
        onSelected: (days) {
          setState(() {
            _sinceDays = days;
            _filterPinned = true; // elle secim: otomatik genisletme devre disi
          });
          _reloadData();
        },
        itemBuilder: (_) => [
          for (final f in _dateFilters)
            PopupMenuItem(value: f.days, child: Text(f.label)),
        ],
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: 10 * ff.scale, vertical: 9 * ff.scale),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.calendar_month, size: 17),
            if (ff != FormFactor.mobile) ...[
              const SizedBox(width: 6),
              Text(current, style: const TextStyle(fontSize: 13)),
            ],
            const Icon(Icons.arrow_drop_down, size: 18),
          ]),
        ),
      ),
    );
  }

  /// Harita stili: Normal (pastel, sakin) ↔ Ayrintili (klasik OSM).
  Widget _buildStyleToggle(FormFactor ff) {
    return Material(
      elevation: 4,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => setState(() => _detailedTiles = !_detailedTiles),
        child: Tooltip(
          message: _detailedTiles
              ? 'Harita: Ayrıntılı — sakin görünüme geç'
              : 'Harita: Normal — ayrıntılı görünüme geç',
          child: Padding(
            padding: EdgeInsets.all(8 * ff.scale),
            child: Icon(
              _detailedTiles ? Icons.layers : Icons.layers_outlined,
              size: 20 * ff.scale,
            ),
          ),
        ),
      ),
    );
  }

  /// Bildirim zili: Guvenlik Alarmi bildirimleri (okunmamis sayaci ile).
  Widget _buildBellButton(FormFactor ff) {
    return Material(
      elevation: 4,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _showNotifications,
        child: Padding(
          padding: EdgeInsets.all(8 * ff.scale),
          child: Badge(
            isLabelVisible: _unread > 0,
            label: Text('$_unread'),
            child: Icon(Icons.notifications_outlined, size: 20 * ff.scale),
          ),
        ),
      ),
    );
  }

  Future<void> _showNotifications() async {
    if (!_notifications.loggedIn) {
      await Navigator.push(
          context, MaterialPageRoute(builder: (_) => const AuthScreen()));
      _refreshUnread();
      return;
    }
    final items = await _notifications.list();
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(children: [
          const Expanded(child: Text('Güvenlik Alarmı')),
          if (items.isNotEmpty)
            TextButton(
              onPressed: () async {
                await _notifications.markAllRead();
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Tümünü okundu say', style: TextStyle(fontSize: 12)),
            ),
        ]),
        content: SizedBox(
          width: 420,
          child: items.isEmpty
              ? const Text('Henüz bildirim yok.\n\nHaritada bir bölgeye dokunup '
                  'kalp simgesiyle Ev/İş konumunu kaydet — 2 km çevresinde olay '
                  'olursa burada ve e-postanda görürsün (lansman süresince ücretsiz).')
              : SizedBox(
                  height: 380,
                  child: ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final n = items[i];
                      final created = DateTime.tryParse(n['created_at'] ?? '');
                      final inc = n['incidents'] as Map<String, dynamic>?;
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          n['read'] == true
                              ? Icons.notifications_none
                              : Icons.notifications_active,
                          color: n['read'] == true ? null : Colors.red,
                        ),
                        title: Text(n['title'] ?? '',
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          '${n['body'] ?? ''}\n'
                          '${created != null ? "${created.day.toString().padLeft(2, '0')}.${created.month.toString().padLeft(2, '0')}.${created.year}" : ''}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        onTap: inc == null
                            ? null
                            : () {
                                Navigator.pop(context);
                                _mapController.move(
                                    LatLng((inc['lat'] as num).toDouble(),
                                        (inc['lng'] as num).toDouble()),
                                    15);
                                _reloadData();
                              },
                      );
                    },
                  ),
                ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Kapat')),
        ],
      ),
    );
    _refreshUnread();
  }

  Widget _buildProfileButton(FormFactor ff) {
    final user = _auth.currentUser;
    return Material(
      elevation: 4,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () async {
          if (user == null) {
            await Navigator.push(
                context, MaterialPageRoute(builder: (_) => const AuthScreen()));
          } else {
            final result = await Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()));
            if (result is (num, num)) {
              _mapController.move(
                  LatLng(result.$1.toDouble(), result.$2.toDouble()), 15);
              _reloadData();
            }
          }
          if (mounted) {
            setState(() {});
            _refreshUnread();
          }
        },
        child: user == null
            ? CircleAvatar(
                radius: 17 * ff.scale,
                backgroundColor: Colors.grey.shade200,
                child: Icon(Icons.person_outline,
                    color: Colors.black54, size: 18 * ff.scale),
              )
            : TierAvatar(
                avatarValue: _profile?['avatar_url'] as String?,
                fallbackInitial: (user.email ?? 'U')[0],
                tier: _profile?['tier'] as String? ?? 'bronz',
                radius: 14 * ff.scale,
              ),
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }
}
