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

  /// 1-100 guvenlik skoru → kirmizi(1) → sari(50) → yesil(100) surekli skala.
  /// PDR kurali: seffaf %40-50 dolgu, sokaklar altigenin arkasindan gorunur.
  static Color fillColor(int safetyScore) {
    final t = (safetyScore.clamp(1, 100) - 1) / 99.0; // 0 = riskli, 1 = guvenli
    return HSVColor.fromAHSV(0.45, 120.0 * t, 0.85, 0.90).toColor();
  }

  /// Kume rozeti rengi: kumedeki ortalama skora gore.
  static Color clusterColor(int avgSafetyScore) {
    final t = (avgSafetyScore.clamp(1, 100) - 1) / 99.0;
    return HSVColor.fromAHSV(1.0, 120.0 * t, 0.80, 0.75).toColor();
  }
}
