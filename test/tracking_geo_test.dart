import 'package:ebic_user/features/chef_booking/tracking/tracking_geo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

void main() {
  test('decodes Google encoded polyline (reference example)', () {
    final points = TrackingGeo.decodePolyline(r'_p~iF~ps|U_ulLnnqC_mqNvxq`@');
    expect(points.length, 3);
    expect(points[0].latitude, closeTo(38.5, 1e-5));
    expect(points[0].longitude, closeTo(-120.2, 1e-5));
    expect(points[1].latitude, closeTo(40.7, 1e-5));
    expect(points[1].longitude, closeTo(-120.95, 1e-5));
    expect(points[2].latitude, closeTo(43.252, 1e-5));
    expect(points[2].longitude, closeTo(-126.453, 1e-5));
  });

  test('bearing points east and lerpBearing takes the short way round', () {
    expect(TrackingGeo.bearing(const LatLng(12.97, 77.59), const LatLng(12.97, 77.60)), closeTo(90, 0.1));
    expect(TrackingGeo.lerpBearing(350, 10, 0.5), closeTo(0, 1e-9));
  });

  test('remainingRoute trims the travelled part of the route', () {
    const route = [LatLng(12.970, 77.590), LatLng(12.970, 77.600), LatLng(12.980, 77.600)];
    // Chef halfway along the first segment
    final remaining = TrackingGeo.remainingRoute(route, const LatLng(12.970, 77.595));
    expect(remaining.length, 3);
    expect(remaining.first.longitude, closeTo(77.595, 1e-6));
    expect(remaining[1], route[1]);
    expect(remaining.last, route[2]);
  });
}
