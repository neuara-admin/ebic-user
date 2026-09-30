import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ebic_user/features/chef_booking/tracking/tracking_geo.dart';

void main() {
  // An L-shaped road: east ~1.1 km, then north ~1.1 km.
  const a = LatLng(17.4000, 78.5000);
  const corner = LatLng(17.4000, 78.5100);
  const b = LatLng(17.4100, 78.5100);
  final route = [a, corner, b];

  group('pathAlongRoute', () {
    test('follows the road round the corner instead of cutting across', () {
      const before = LatLng(17.4000, 78.5080); // on the east leg
      const after = LatLng(17.4020, 78.5100); // on the north leg
      final path = TrackingGeo.pathAlongRoute(route, before, after);
      expect(path, contains(corner));
      // Road distance (~220 m + ~220 m) is longer than the straight hop (~300 m).
      expect(TrackingGeo.pathLengthMeters(path), greaterThan(TrackingGeo.distanceMeters(before, after) + 50));
    });

    test('falls back to a straight hop when the chef is off the route', () {
      const offRoute = LatLng(17.4050, 78.5040); // ~500 m off either leg
      final path = TrackingGeo.pathAlongRoute(route, a, offRoute);
      expect(path, [a, offRoute]);
    });

    test('never animates backwards along the route', () {
      const ahead = LatLng(17.4020, 78.5100);
      const behind = LatLng(17.4000, 78.5050);
      expect(TrackingGeo.pathAlongRoute(route, ahead, behind), [ahead, behind]);
    });
  });

  group('pointAlong', () {
    test('returns the ends at 0 and 1 and heads along the current segment', () {
      final path = [a, corner, b];
      expect(TrackingGeo.pointAlong(path, 0).point, a);
      final end = TrackingGeo.pointAlong(path, 1);
      expect(TrackingGeo.distanceMeters(end.point, b), lessThan(1));
      // First half heads east (~90°), second half north (~0°).
      expect(TrackingGeo.pointAlong(path, 0.25).bearing, closeTo(90, 2));
      final north = TrackingGeo.pointAlong(path, 0.75).bearing;
      expect(north < 2 || north > 358, isTrue);
    });
  });

  test('progress is travelled over total, clamped', () {
    expect(TrackingGeo.progress(1000, 3000), 0.25);
    expect(TrackingGeo.progress(0, 0), 0);
    expect(TrackingGeo.progress(5000, 0), 1);
  });
}
