import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:url_launcher/url_launcher.dart';

import '../models/hex_score.dart';
import '../models/incident.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../services/scan_service.dart';
import '../services/supabase_service.dart';
import '../utils/hex_utils.dart';
import '../utils/responsive.dart';
import '../widgets/incident_sheet.dart';
import 'auth_screen.dart';
import 'settings_screen.dart';

/// Ana ekran: tam ekran harita + hex katmani + arama + profil menusu.
/// Harita KULLANICININ KONUMUNDAN acilir (izin verilmezse Izmit).
/// Zoom >= [_detailZoom]: hex poligonlari + olay ikonlari.
/// Zoom <  [_detailZoom]: res-7 kume rozetleri — performans.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const _izmitCenter = LatLng(40.7654, 29.9408);
  static const _detailZoom = 13.0;

  final _service = SupabaseService();
  final _auth = AuthService();
  final _scanService = ScanService();
  final _mapController = MapController();
  List<HexScore> _hexes = [];
  List<ScanResult> _scanResults = [];
  bool _scanning = false;
  double _zoom = 13;
  Timer? _debounce;
  bool _disclaimerShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showDisclaimer();
      _startFromUserLocation();
    });
    // Giris/cikis sonrasi favori durumu vb. tazelensin.
    _auth.onAuthChange.listen((_) => mounted ? setState(() {}) : null);
  }

  /// Once tarayici/cihaz konumu istenir; alinirsa harita oradan acilir.
  Future<void> _startFromUserLocation() async {
    final pos = await LocationService.currentPosition();
    if (pos != null && mounted) {
      _mapController.move(pos, 14);
    }
    _loadVisibleHexes();
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

  /// Bounding Box kurali: harita durunca sadece gorunen alani cek.
  Future<void> _loadVisibleHexes() async {
    final bounds = _mapController.camera.visibleBounds;
    try {
      final hexes = await _service.hexesInBbox(
        minLat: bounds.south,
        minLng: bounds.west,
        maxLat: bounds.north,
        maxLng: bounds.east,
      );
      if (mounted) setState(() => _hexes = hexes);
    } catch (e) {
      debugPrint('hex yukleme hatasi: $e');
    }
  }

  void _onMapMoved(MapEvent event) {
    _zoom = _mapController.camera.zoom;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _loadVisibleHexes);
  }

  bool get _detailed => _zoom >= _detailZoom;

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
            onTap: (_, point) => _detailed ? _handleTap(point) : null,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.urbhex.app',
            ),
            if (_detailed) ...[
              PolygonLayer(
                polygons: [
                  for (final hex in _hexes)
                    Polygon(
                      points: HexUtils.hexagonVertices(hex.lat, hex.lng),
                      color: HexUtils.fillColor(hex.safetyScore),
                      borderColor: Colors.black26,
                      borderStrokeWidth: 0.5,
                    ),
                ],
              ),
              MarkerLayer(markers: _eventIconMarkers(ff)),
            ] else
              MarkerLayer(markers: _clusterMarkers(ff)),
            if (_scanResults.isNotEmpty)
              MarkerLayer(markers: _scanMarkers(ff)),
          ],
        ),
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
            heroTag: 'loc',
            tooltip: 'Konumuma git',
            onPressed: _startFromUserLocation,
            child: const Icon(Icons.my_location),
          ),
        ],
      ),
    );
  }

  /// Ekranda gorunen alanin guncel haberlerini GDELT'ten ANLIK ceker.
  Future<void> _scanVisibleArea() async {
    setState(() => _scanning = true);
    final b = _mapController.camera.visibleBounds;
    // Kuyruga da yaz: bot bu bolgeyi sonraki turda kalici olarak isler.
    _service
        .requestScan(
            minLat: b.south, minLng: b.west, maxLat: b.north, maxLng: b.east)
        .catchError((_) {});
    try {
      final results = await _scanService.scanBbox(
        minLat: b.south, minLng: b.west, maxLat: b.north, maxLng: b.east,
      );
      if (!mounted) return;
      setState(() => _scanResults = results);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(results.isEmpty
            ? 'Bu alanda son 7 günde uluslararası basına yansıyan olay yok.'
            : '${results.length} haber noktası bulundu (mavi işaretler — son 7 gün).'),
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tarama başarısız — tekrar dene.')));
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  /// Anlik tarama sonuclari: mavi haber pinleri (gecici katman).
  List<Marker> _scanMarkers(FormFactor ff) {
    final size = 34.0 * ff.scale;
    return [
      for (final r in _scanResults)
        Marker(
          point: LatLng(r.lat, r.lng),
          width: size,
          height: size,
          child: GestureDetector(
            onTap: () => _showScanResult(r),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.blue.shade700,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.newspaper, color: Colors.white, size: 16),
            ),
          ),
        ),
    ];
  }

  void _showScanResult(ScanResult r) {
    showDialog(
      context: context,
      builder: (_) => SimpleDialog(
        title: Text('${r.name} — ${r.count} haber'),
        children: [
          if (r.urls.isEmpty)
            const Padding(
                padding: EdgeInsets.all(16), child: Text('Link bulunamadı.')),
          for (final url in r.urls)
            SimpleDialogOption(
              child: Text(Uri.parse(url).host,
                  style: const TextStyle(color: Colors.blue)),
              onPressed: () =>
                  launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
            ),
        ],
      ),
    );
  }

  /// Yakin zoom: her hex'in merkezine baskin olay ikonu + ANLIK SKOR rozeti.
  /// Ikon boyutlari cihaza gore oranlanir (telefon/tablet/pc).
  List<Marker> _eventIconMarkers(FormFactor ff) {
    final w = 34.0 * ff.scale;
    final h = 48.0 * ff.scale;
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
                width: 28 * ff.scale,
                height: 28 * ff.scale,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: HexUtils.clusterColor(hex.safetyScore), width: 2),
                ),
                child: Icon(
                  eventTypeIcon(hex.topEventType),
                  size: 15 * ff.scale,
                  color: HexUtils.clusterColor(hex.safetyScore),
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 5 * ff.scale),
                decoration: BoxDecoration(
                  color: HexUtils.clusterColor(hex.safetyScore),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${hex.safetyScore}',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 10 * ff.scale,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ]),
          ),
        ),
    ];
  }

  /// Uzak zoom: res-7 kumeleri — binlerce cizim yerine tek rozet + sayi.
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
          // Rozetler kucultuldu + beyaz cerceve eklendi: komsu kumeler
          // uzak zoomda ust uste binince bile ayirt edilebiliyor.
          final base = total > 99 ? 44.0 : (total > 20 ? 38.0 : 30.0);
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
                        fontSize: 12 * ff.scale)),
              ),
            ),
          );
        }(),
    ];
  }

  void _onHexTapped(HexScore hex) {
    final ff = formFactorOf(context);
    if (ff.sidePanel) {
      showDialog(
        context: context,
        builder: (_) => Dialog(
          alignment: Alignment.centerRight,
          insetPadding: const EdgeInsets.all(16),
          child: SizedBox(width: 460, child: IncidentSheet(hex: hex)),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => IncidentSheet(hex: hex),
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: ff.searchBarMaxWidth),
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(28),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Mahalle ara...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                      ),
                      onSubmitted: _searchMahalle,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _buildProfileButton(ff),
          ],
        ),
      ),
    );
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
            // Ayarlardan favori secilirse (lat, lng) doner → haritayi odakla.
            final result = await Navigator.push(
                context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
            if (result is (num, num)) {
              _mapController.move(
                  LatLng(result.$1.toDouble(), result.$2.toDouble()), 15);
            }
          }
          if (mounted) setState(() {});
        },
        child: CircleAvatar(
          radius: 22 * ff.scale,
          backgroundColor:
              user == null ? Colors.grey.shade200 : const Color(0xFF1B5E20),
          child: user == null
              ? const Icon(Icons.person_outline, color: Colors.black54)
              : Text((user.email ?? 'U')[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white)),
        ),
      ),
    );
  }

  /// MVP arama: bot tarafindaki mahalle listesiyle ayni merkezlere odaklanir.
  /// V2: Sahibinden ilan no cozumleme buraya eklenecek.
  void _searchMahalle(String query) {
    const centers = {
      'yahya kaptan': LatLng(40.7729, 29.9530),
      'kadikoy': LatLng(40.7726, 29.9350),
      'yenisehir': LatLng(40.7772, 29.9663),
      'alikahya': LatLng(40.7900, 30.0180),
      'cedit': LatLng(40.7660, 29.9260),
    };
    final target = centers[query.toLowerCase().trim()];
    if (target != null) {
      _mapController.move(target, 15);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
