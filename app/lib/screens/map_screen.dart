import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/hex_score.dart';
import '../models/incident.dart';
import '../services/supabase_service.dart';
import '../utils/hex_utils.dart';
import '../widgets/incident_sheet.dart';

/// Ana ekran: tam ekran harita + hex katmani + arama cubugu.
/// Zoom >= [_detailZoom]: hex poligonlari + olay turu ikonlari.
/// Zoom <  [_detailZoom]: res-7 bazli kume rozetleri ("124" gibi) — performans.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const _izmitCenter = LatLng(40.7654, 29.9408);
  static const _detailZoom = 13.0;

  final _service = SupabaseService();
  final _mapController = MapController();
  List<HexScore> _hexes = [];
  double _zoom = 13;
  Timer? _debounce;
  bool _disclaimerShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showDisclaimer();
      _loadVisibleHexes();
    });
  }

  /// Hukuki kalkan: acilis uyarisi.
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
              MarkerLayer(markers: _eventIconMarkers()),
            ] else
              MarkerLayer(markers: _clusterMarkers()),
          ],
        ),
        _buildSearchBar(),
      ]),
    );
  }

  /// Yakin zoom: her hex'in merkezine baskin olay turunun ikonu.
  List<Marker> _eventIconMarkers() {
    return [
      for (final hex in _hexes)
        Marker(
          point: LatLng(hex.lat, hex.lng),
          width: 30,
          height: 30,
          child: GestureDetector(
            onTap: () => _onHexTapped(hex),
            child: CircleAvatar(
              backgroundColor: Colors.white.withOpacity(0.9),
              child: Icon(
                eventTypeIcon(hex.topEventType),
                size: 17,
                color: HexUtils.clusterColor(hex.safetyScore),
              ),
            ),
          ),
        ),
    ];
  }

  /// Uzak zoom: hex'ler res-7 ebeveynine gore toplanir, tek rozet + sayi.
  /// Binlerce poligon/ikon cizilmez → harita kasmaz.
  List<Marker> _clusterMarkers() {
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
              (members.fold(0, (s, h) => s + h.safetyScore) / members.length).round();
          final center = LatLng(
            members.fold(0.0, (s, h) => s + h.lat) / members.length,
            members.fold(0.0, (s, h) => s + h.lng) / members.length,
          );
          final size = total > 99 ? 52.0 : (total > 20 ? 44.0 : 36.0);
          return Marker(
            point: center,
            width: size,
            height: size,
            child: GestureDetector(
              // Kumeye tiklayinca yakinlas → kume dagilir, ikonlara donusur.
              onTap: () => _mapController.move(center, _detailZoom + 0.5),
              child: CircleAvatar(
                backgroundColor: HexUtils.clusterColor(avgScore),
                child: Text(
                  '$total',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          );
        }(),
    ];
  }

  void _onHexTapped(HexScore hex) {
    final isWide = MediaQuery.sizeOf(context).width > 800;
    if (isWide) {
      showDialog(
        context: context,
        builder: (_) => Dialog(
          alignment: Alignment.centerRight,
          child: SizedBox(width: 420, child: IncidentSheet(hex: hex)),
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

  /// Tiklanan noktaya en yakin hex'i bul (basit mesafe kontrolu, MVP).
  void _handleTap(LatLng point) {
    const d = Distance();
    for (final hex in _hexes) {
      if (d.as(LengthUnit.Meter, point, LatLng(hex.lat, hex.lng)) < 200) {
        _onHexTapped(hex);
        return;
      }
    }
  }

  Widget _buildSearchBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
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
