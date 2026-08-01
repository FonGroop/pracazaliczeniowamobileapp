import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pracazaliczeniowamobileapp/data/models/tour_place.dart';
import 'package:pracazaliczeniowamobileapp/domain/place_marker_clusterer.dart';
import 'package:pracazaliczeniowamobileapp/ui/shared/place_cluster_marker_button.dart';

void main() {
  const first = TourPlace(
    id: 1,
    title: 'First',
    body: 'First place',
    latitude: 52.2297,
    longitude: 21.0122,
  );
  const nearby = TourPlace(
    id: 2,
    title: 'Nearby',
    body: 'Nearby place',
    latitude: 52.2302,
    longitude: 21.0122,
  );
  const distant = TourPlace(
    id: 3,
    title: 'Distant',
    body: 'Distant place',
    latitude: 52.2497,
    longitude: 21.0122,
  );

  test('nearby markers merge when zoomed out and split when zoomed in', () {
    const clusterer = PlaceMarkerClusterer();

    final zoomedOut = clusterer.cluster(const [
      first,
      nearby,
      distant,
    ], zoom: 13);
    final zoomedIn = clusterer.cluster(const [
      first,
      nearby,
      distant,
    ], zoom: 18);

    expect(zoomedOut, hasLength(2));
    expect(zoomedOut.first.places, const [first, nearby]);
    expect(zoomedIn, hasLength(3));
  });

  testWidgets('cluster marker shows its count and opens when tapped', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: PlaceClusterMarkerButton(
              count: 3,
              tooltip: '3 places in this area',
              onPressed: () => tapped = true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('3'), findsOneWidget);
    await tester.tap(find.byType(PlaceClusterMarkerButton));
    await tester.pump();

    expect(tapped, isTrue);
  });
}
