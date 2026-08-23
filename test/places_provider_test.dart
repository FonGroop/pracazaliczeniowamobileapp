import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:pracazaliczeniowamobileapp/app/providers.dart';
import 'package:pracazaliczeniowamobileapp/data/models/saved_place_entity.dart';
import 'package:pracazaliczeniowamobileapp/data/models/wikipedia_place_dto.dart';
import 'package:pracazaliczeniowamobileapp/data/repositories/place_repository.dart';
import 'package:pracazaliczeniowamobileapp/data/services/api_service.dart';
import 'package:pracazaliczeniowamobileapp/data/services/local_database_service.dart';
import 'package:pracazaliczeniowamobileapp/data/services/location_service.dart';

void main() {
  test(
    'built-in places load when iOS location and Wikipedia are unavailable',
    () async {
      final api = _RecordingPlacesGateway();
      final repository = PlaceRepository(
        apiService: api,
        databaseService: _EmptySavedPlaceStore(),
      );
      final container = ProviderContainer(
        overrides: [
          locationProvider.overrideWith(
            (ref) => Future<LatLng>.error(const LocationPermissionDenied()),
          ),
          placeRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final places = await container.read(placesProvider.future);

      expect(api.requestedCenter, defaultDiscoveryCenter);
      expect(places, isNotEmpty);
      expect(places.first.title, 'Old Town Market Square');
    },
  );
}

class _RecordingPlacesGateway implements PlacesGateway {
  LatLng? requestedCenter;

  @override
  Future<List<WikipediaPlaceDto>> fetchNearbyPlaces({
    String languageCode = 'en',
    required LatLng center,
    int radiusMeters = 5000,
  }) async {
    requestedCenter = center;
    throw const PlacesApiException('Network unavailable in test.');
  }
}

class _EmptySavedPlaceStore implements SavedPlaceStore {
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
