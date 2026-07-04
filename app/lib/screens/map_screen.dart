import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/hex_score.dart';
import '../services/supabase_service.dart';
import '../utils/hex_utils.dart';
import '../widgets/incident_sheet.dart';

/// Ana ekran: tam ekran harita + hex katmani + arama cubugu.
/// Adaptive UI: >800px genislikte olay paneli yanda, altta degil.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const _izmitCenter = LatLng(40.7654, 29.9408);

  final _service = SupabaseService();
  final _mapController = MapController();
  List<HexScore> _hexes = [];
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
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _loadVisibleHexes);
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
            onTap: (_, point) => _handleTap(point),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'app.habitex',
            ),
            PolygonLayer(
              polygons: [
                for (final hex in _hexes)
                  Polygon(
                    points: HexUtils.hexagonVertices(hex.lat, hex.lng),
                    color: HexUtils.fillColor(hex.riskScore),
                    borderColor: Colors.black26,
                    borderStrokeWidth: 0.5,
                  ),
              ],
            ),
          ],
        ),
        _buildSearchBar(),
      ]),
    );
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
