import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../data/models/tour_place.dart';

class PlaceMarkerCluster {
  const PlaceMarkerCluster({required this.center, required this.places});

  final LatLng center;
  final List<TourPlace> places;
}

/// Groups recommendation markers that would visually overlap at [zoom].
class PlaceMarkerClusterer {
  const PlaceMarkerClusterer({this.markerDiameterPixels = 56});

  final double markerDiameterPixels;

  List<PlaceMarkerCluster> cluster(
    List<TourPlace> places, {
    required double zoom,
  }) {
    if (places.isEmpty) return const <PlaceMarkerCluster>[];

    final builders = <_ClusterBuilder>[];
    const distance = Distance();

    for (final place in places) {
      final point = LatLng(place.latitude, place.longitude);
      _ClusterBuilder? nearest;
      var nearestDistance = double.infinity;

      for (final builder in builders) {
        final meters = distance.as(LengthUnit.Meter, builder.center, point);
        final threshold = _overlapDistanceMeters(
          latitude: (builder.center.latitude + point.latitude) / 2,
          zoom: zoom,
        );
        if (meters <= threshold && meters < nearestDistance) {
          nearest = builder;
          nearestDistance = meters;
        }
      }

      if (nearest == null) {
        builders.add(_ClusterBuilder(place));
      } else {
        nearest.add(place);
      }
    }

    return builders.map((builder) => builder.build()).toList(growable: false);
  }

  double _overlapDistanceMeters({
    required double latitude,
    required double zoom,
  }) {
    final latitudeRadians = latitude * math.pi / 180;
    final metersPerPixel =
        156543.03392 * math.cos(latitudeRadians).abs() / math.pow(2, zoom);
    return (metersPerPixel * markerDiameterPixels).clamp(4, 20000);
  }
}

class _ClusterBuilder {
  _ClusterBuilder(TourPlace first)
    : _places = [first],
      _latitudeSum = first.latitude,
      _longitudeSum = first.longitude;

  final List<TourPlace> _places;
  double _latitudeSum;
  double _longitudeSum;

  LatLng get center =>
      LatLng(_latitudeSum / _places.length, _longitudeSum / _places.length);

  void add(TourPlace place) {
    _places.add(place);
    _latitudeSum += place.latitude;
    _longitudeSum += place.longitude;
  }

  PlaceMarkerCluster build() =>
      PlaceMarkerCluster(center: center, places: List.unmodifiable(_places));
}
