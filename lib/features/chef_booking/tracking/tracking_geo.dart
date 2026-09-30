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

  /// Road-following path between two consecutive chef positions: both are
  /// snapped onto [route] and the path follows the route's vertices between
  /// them, so the marker turns corners instead of cutting across blocks.
  /// Falls back to a straight hop when either point is off the route or the
  /// chef appears to have moved backwards along it.
  static List<LatLng> pathAlongRoute(List<LatLng> route, LatLng from, LatLng to) {
    if (route.length < 2) return [from, to];
    final a = _snap(route, from);
    final b = _snap(route, to);
    const offRouteM = 40.0;
    if (a.distance > offRouteM || b.distance > offRouteM) return [from, to];
    final forward = b.segment > a.segment || (b.segment == a.segment && b.t >= a.t);
    if (!forward) return [from, to];
    return [
      from,
      a.point,
      for (var i = a.segment + 1; i <= b.segment; i++) route[i],
      b.point,
      to,
    ];
  }

  static double pathLengthMeters(List<LatLng> path) {
    var total = 0.0;
    for (var i = 0; i < path.length - 1; i++) {
      total += distanceMeters(path[i], path[i + 1]);
    }
    return total;
  }

  /// Point at fraction [t] (0..1) of the way along [path], with the heading of
  /// the segment it's on (for rotating the chef marker).
  static ({LatLng point, double bearing}) pointAlong(List<LatLng> path, double t) {
    if (path.length == 1) return (point: path.first, bearing: 0);
    final total = pathLengthMeters(path);
    if (total <= 0) return (point: path.last, bearing: bearing(path.first, path.last));
    var target = total * t.clamp(0.0, 1.0);
    for (var i = 0; i < path.length - 1; i++) {
      final seg = distanceMeters(path[i], path[i + 1]);
      if (target <= seg || i == path.length - 2) {
        final f = seg == 0 ? 1.0 : (target / seg).clamp(0.0, 1.0);
        return (point: lerp(path[i], path[i + 1], f), bearing: bearing(path[i], path[i + 1]));
      }
      target -= seg;
    }
    return (point: path.last, bearing: bearing(path[path.length - 2], path.last));
  }

  /// Share of the journey done: travelled ÷ (travelled + remaining).
  static double progress(double travelledM, double remainingM) {
    final total = travelledM + remainingM;
    return total <= 0 ? 0 : (travelledM / total).clamp(0.0, 1.0);
  }

  static ({int segment, double t, LatLng point, double distance}) _snap(List<LatLng> route, LatLng p) {
    var bestSegment = 0;
    var bestT = 0.0;
    var bestPoint = route.first;
    var bestDist = double.infinity;
    for (var i = 0; i < route.length - 1; i++) {
      final proj = _projectOnSegment(p, route[i], route[i + 1]);
      final d = distanceMeters(p, proj);
      if (d < bestDist) {
        final segLen = distanceMeters(route[i], route[i + 1]);
        bestDist = d;
        bestSegment = i;
        bestPoint = proj;
        bestT = segLen == 0 ? 0 : distanceMeters(route[i], proj) / segLen;
      }
    }
    return (segment: bestSegment, t: bestT, point: bestPoint, distance: bestDist);
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
