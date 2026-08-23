import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:pracazaliczeniowamobileapp/data/models/saved_place_entity.dart';
import 'package:pracazaliczeniowamobileapp/data/models/wikipedia_place_dto.dart';
import 'package:pracazaliczeniowamobileapp/data/repositories/place_repository.dart';
import 'package:pracazaliczeniowamobileapp/data/services/api_service.dart';
import 'package:pracazaliczeniowamobileapp/data/services/local_database_service.dart';

void main() {
  test(
    'identical recommendation requests share one API call and cache',
    () async {
      final api = _FakePlacesGateway();
      final repository = PlaceRepository(
        apiService: api,
        databaseService: _FakeSavedPlaceStore(),
      );
      const center = LatLng(52.2297, 21.0122);

      final firstTwo = await Future.wait([
        repository.loadPlaces(languageCode: 'pl', center: center),
        repository.loadPlaces(languageCode: 'pl', center: center),
      ]);
      final cached = await repository.loadPlaces(
        languageCode: 'pl',
        center: center,
      );

      expect(api.callsByLanguage['pl'], 1);
      expect(firstTwo.first, firstTwo.last);
      expect(cached, firstTwo.first);

      repository.clearRecommendationCache();
      await repository.loadPlaces(languageCode: 'pl', center: center);
      expect(api.callsByLanguage['pl'], 2);
    },
  );

  test('Polish and English results have separate cache entries', () async {
    final api = _FakePlacesGateway();
    final repository = PlaceRepository(
      apiService: api,
      databaseService: _FakeSavedPlaceStore(),
    );
    const center = LatLng(52.2297, 21.0122);

    await Future.wait([
      repository.loadPlaces(languageCode: 'pl', center: center),
      repository.loadPlaces(languageCode: 'en', center: center),
    ]);
    await repository.loadPlaces(languageCode: 'en', center: center);

    expect(api.callsByLanguage, {'pl': 1, 'en': 1});
  });
}

class _FakePlacesGateway implements PlacesGateway {
  final callsByLanguage = <String, int>{};

  @override
  Future<List<WikipediaPlaceDto>> fetchNearbyPlaces({
    String languageCode = 'en',
    required LatLng center,
    int radiusMeters = 5000,
  }) async {
    callsByLanguage.update(
      languageCode,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return [
      WikipediaPlaceDto(
        pageId: languageCode == 'pl' ? 1 : 2,
        title: languageCode == 'pl' ? 'Miejsce' : 'Place',
        extract: 'Description',
        coordinates: [
          WikipediaCoordinateDto(lat: center.latitude, lon: center.longitude),
        ],
      ),
    ];
  }
}

class _FakeSavedPlaceStore implements SavedPlaceStore {
  @override
  Future<void> deleteSavedPlace(int remoteId) async {}

  @override
  Future<void> savePlace({
    required int remoteId,
    required String title,
    required String notes,
    required double latitude,
    required double longitude,
  }) async {}

  @override
  Stream<List<SavedPlaceEntity>> watchSavedPlaces() =>
      const Stream<List<SavedPlaceEntity>>.empty();
}
