import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Hexagon Layer Fill yardimcilari.
///
/// MVP notu: kose koordinatlari hex MERKEZINDEN geometrik olarak uretilir
/// (duzgun altigen yaklasimi). V2'de h3 boundary API'sine gecilecek.
class HexUtils {
  /// H3 res 9 kenar uzunlugu ~ 174 m.
  static const double _edgeMeters = 174;

  /// Merkez koordinattan 6 koseli poligon uretir.
  static List<LatLng> hexagonVertices(double lat, double lng) {
    const metersPerDegLat = 111320.0;
    final metersPerDegLng = 111320.0 * math.cos(lat * math.pi / 180);
    return List.generate(6, (i) {
      final angle = math.pi / 180 * (60 * i + 30); // pointy-top
      return LatLng(
        lat + _edgeMeters * math.sin(angle) / metersPerDegLat,
        lng + _edgeMeters * math.cos(angle) / metersPerDegLng,
      );
    });
  }

  /// Risk skoruna gore dolgu rengi (PDR: seffaf %40-50 katman).
  static Color fillColor(double riskScore) {
    if (riskScore <= 0) return Colors.transparent;
    if (riskScore < 5) return Colors.green.withOpacity(0.30);
    if (riskScore < 15) return Colors.yellow.withOpacity(0.40);
    if (riskScore < 30) return Colors.orange.withOpacity(0.45);
    return Colors.red.withOpacity(0.50);
  }
}
