import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:pracazaliczeniowamobileapp/app/providers.dart';
import 'package:pracazaliczeniowamobileapp/data/models/city_note.dart';
import 'package:pracazaliczeniowamobileapp/data/models/map_focus_target.dart';
import 'package:pracazaliczeniowamobileapp/data/models/saved_place_entity.dart';
import 'package:pracazaliczeniowamobileapp/data/models/tour_place.dart';
import 'package:pracazaliczeniowamobileapp/l10n/app_localizations.dart';
import 'package:pracazaliczeniowamobileapp/ui/screens/map_screen.dart';

void main() {
  testWidgets('a saved-only place is shown as a bookmark on the map', (
    tester,
  ) async {
    const center = LatLng(50.0614, 19.9366);
    final savedPlace = SavedPlaceEntity(
      remoteId: 42,
      title: 'Saved museum',
      notes: 'A place outside the current recommendations.',
      latitude: center.latitude,
      longitude: center.longitude,
      savedAt: DateTime(2026),
    );
    final controller = MapController();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          locationProvider.overrideWith((ref) => Future.value(center)),
          placesProvider.overrideWith(
            (ref) => Future.value(const <TourPlace>[]),
          ),
          savedPlacesProvider.overrideWith((ref) => Stream.value([savedPlace])),
          notesProvider.overrideWith((ref) => Stream.value(const <CityNote>[])),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: MapScreen(
            initialCenter: center,
            tileProvider: _TransparentTileProvider(),
            mapController: controller,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byIcon(Icons.bookmark), findsOneWidget);
    expect(find.byTooltip('Saved museum (Saved)'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.bookmark));
    await tester.pumpAndSettle();

    expect(find.text('Saved museum'), findsWidgets);
    expect(find.text('Open details'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('focused-map-marker-place-42')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('map-focus-banner')), findsOneWidget);
    expect(controller.camera.zoom, closeTo(17, 0.01));
    expect(controller.camera.center.latitude, closeTo(center.latitude, 0.0001));
    expect(
      controller.camera.center.longitude,
      closeTo(center.longitude, 0.0001),
    );
  });

  testWidgets('a recommended place is zoomed and highlighted when chosen', (
    tester,
  ) async {
    const center = LatLng(52.2297, 21.0122);
    const place = TourPlace(
      id: 99,
      title: 'Warsaw museum',
      body: 'A recommended museum.',
      latitude: 52.2297,
      longitude: 21.0122,
    );
    final controller = MapController();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          locationProvider.overrideWith((ref) => Future.value(center)),
          placesProvider.overrideWith((ref) => Future.value(const [place])),
          savedPlacesProvider.overrideWith((ref) => Stream.value(const [])),
          notesProvider.overrideWith((ref) => Stream.value(const [])),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: MapScreen(
            initialCenter: center,
            tileProvider: _TransparentTileProvider(),
            mapController: controller,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byTooltip('Open details'));
    await tester.pumpAndSettle();

    expect(find.text('Warsaw museum'), findsWidgets);
    expect(
      find.byKey(const ValueKey('focused-map-marker-place-99')),
      findsOneWidget,
    );
    expect(controller.camera.zoom, closeTo(17, 0.01));
    expect(controller.camera.center.latitude, closeTo(center.latitude, 0.0001));
    expect(
      controller.camera.center.longitude,
      closeTo(center.longitude, 0.0001),
    );
  });

  testWidgets('a routed saved place starts focused and clearly named', (
    tester,
  ) async {
    const center = LatLng(54.4702, 17.0317);
    final savedPlace = SavedPlaceEntity(
      remoteId: 7,
      title: 'My bridge',
      notes: 'A custom saved place.',
      latitude: center.latitude,
      longitude: center.longitude,
      savedAt: DateTime(2026),
    );
    final controller = MapController();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          locationProvider.overrideWith((ref) => Future.value(center)),
          placesProvider.overrideWith((ref) => Future.value(const [])),
          savedPlacesProvider.overrideWith((ref) => Stream.value([savedPlace])),
          notesProvider.overrideWith((ref) => Stream.value(const [])),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: MapScreen(
            focusTarget: MapFocusTarget.savedPlace(savedPlace),
            tileProvider: _TransparentTileProvider(),
            mapController: controller,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('My bridge'), findsOneWidget);
    expect(find.text('Highlighted and centered on the map'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('focused-map-marker-place-7')),
      findsOneWidget,
    );
    expect(controller.camera.zoom, closeTo(17, 0.01));
  });
}

class _TransparentTileProvider extends TileProvider {
  static final _bytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4'
    '2mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  );

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(_bytes);
}
