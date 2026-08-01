import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:pracazaliczeniowamobileapp/app/providers.dart';
import 'package:pracazaliczeniowamobileapp/data/models/tour_place.dart';
import 'package:pracazaliczeniowamobileapp/l10n/app_localizations.dart';
import 'package:pracazaliczeniowamobileapp/ui/screens/home_screen.dart';

void main() {
  testWidgets('place cards hide API ids and render without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const place = TourPlace(
      id: 6605,
      title: 'Rynek Starego Miasta w Warszawie',
      body:
          'Historyczne centrum Warszawy z zabytkowymi kamienicami i pomnikiem Syreny.\n\nŹródło: Wikipedia',
      latitude: 52.2497,
      longitude: 21.0122,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          placesProvider.overrideWith((ref) => Future.value(const [place])),
        ],
        child: const MaterialApp(
          locale: Locale('pl'),
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: HomeScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('6605'), findsNothing);
    expect(find.byIcon(Icons.location_on_outlined), findsOneWidget);
    expect(find.text('Rynek Starego Miasta w Warszawie'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Discover replaces places when the shared map area changes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const warsaw = TourPlace(
      id: 1,
      title: 'Warsaw place',
      body: 'Warsaw description',
      latitude: 52.2297,
      longitude: 21.0122,
    );
    const krakow = TourPlace(
      id: 2,
      title: 'Krakow place',
      body: 'Krakow description',
      latitude: 50.0614,
      longitude: 19.9366,
    );
    final krakowResponse = Completer<List<TourPlace>>();
    final container = ProviderContainer(
      overrides: [
        placesProvider.overrideWith((ref) async {
          final area = ref.watch(discoveryAreaProvider);
          return area?.center.latitude == 50.0614
              ? krakowResponse.future
              : const [warsaw];
        }),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Warsaw place'), findsOneWidget);

    container.read(discoveryAreaProvider.notifier).state = (
      center: const LatLng(50.0614, 19.9366),
      radiusMeters: 4000,
    );
    await tester.pump();

    expect(find.text('Warsaw place'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    krakowResponse.complete(const [krakow]);
    await tester.pumpAndSettle();

    expect(find.text('Krakow place'), findsOneWidget);
  });
}
