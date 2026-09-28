import 'dart:math' as math;
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Geometry helpers for the live chef tracking map.
class TrackingGeo {
  TrackingGeo._();

  /// Decodes a Google encoded polyline (Directions API `overview_polyline`).
  static List<LatLng> decodePolyline(String encoded) {
    final points = <LatLng>[];
    var index = 0, lat = 0, lng = 0;
    while (index < encoded.length) {
      for (var coord = 0; coord < 2; coord++) {
        var shift = 0, result = 0, b = 0;
        do {
          b = encoded.codeUnitAt(index++) - 63;
          result |= (b & 0x1f) << shift;
          shift += 5;
        } while (b >= 0x20 && index < encoded.length);
        final delta = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
        if (coord == 0) {
          lat += delta;
        } else {
          lng += delta;
        }
      }
      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }

  static double distanceMeters(LatLng a, LatLng b) {
    const r = 6371000.0;
    final dLat = _rad(b.latitude - a.latitude);
    final dLng = _rad(b.longitude - a.longitude);
    final h = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_rad(a.latitude)) * math.cos(_rad(b.latitude)) * math.pow(math.sin(dLng / 2), 2);
    return 2 * r * math.asin(math.sqrt(h));
  }

  /// Compass bearing (0 = north, clockwise) from [a] to [b].
  static double bearing(LatLng a, LatLng b) {
    final lat1 = _rad(a.latitude), lat2 = _rad(b.latitude);
    final dLng = _rad(b.longitude - a.longitude);
    final y = math.sin(dLng) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  static LatLng lerp(LatLng a, LatLng b, double t) => LatLng(
        a.latitude + (b.latitude - a.latitude) * t,
        a.longitude + (b.longitude - a.longitude) * t,
      );

  /// Interpolates between two bearings along the shortest rotation.
  static double lerpBearing(double from, double to, double t) {
    final diff = ((to - from + 540) % 360) - 180;
    return (from + diff * t + 360) % 360;
  }

  /// The part of [route] still ahead of [position]: [position] snapped onto the
  /// nearest route segment, followed by the remaining route vertices.
  static List<LatLng> remainingRoute(List<LatLng> route, LatLng position) {
    if (route.length < 2) return route;
    var bestSegment = 0;
    var bestDist = double.infinity;
    LatLng bestPoint = route.first;
    for (var i = 0; i < route.length - 1; i++) {
      final p = _projectOnSegment(position, route[i], route[i + 1]);
      final d = distanceMeters(position, p);
      if (d < bestDist) {
        bestDist = d;
        bestSegment = i;
        bestPoint = p;
      }
    }
    // Chef is well off the planned route — draw from their real position.
    final start = bestDist > 60 ? position : bestPoint;
    return [start, ...route.sublist(bestSegment + 1)];
  }

  static LatLngBounds boundsOf(Iterable<LatLng> points) {
    var minLat = 90.0, maxLat = -90.0, minLng = 180.0, maxLng = -180.0;
    for (final p in points) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }
    return LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng));
  }

  // Equirectangular projection is accurate enough at city scale.
  static LatLng _projectOnSegment(LatLng p, LatLng a, LatLng b) {
    final k = math.cos(_rad(p.latitude));
    final ax = a.longitude * k, ay = a.latitude;
    final bx = b.longitude * k, by = b.latitude;
    final px = p.longitude * k, py = p.latitude;
    final dx = bx - ax, dy = by - ay;
    final len2 = dx * dx + dy * dy;
    if (len2 == 0) return a;
    final t = (((px - ax) * dx + (py - ay) * dy) / len2).clamp(0.0, 1.0);
    return LatLng(ay + dy * t, (ax + dx * t) / k);
  }

  static double _rad(double deg) => deg * math.pi / 180;
}
