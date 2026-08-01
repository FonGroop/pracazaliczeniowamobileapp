import '../models/saved_place_entity.dart';
import '../models/tour_place.dart';
import '../services/api_service.dart';
import '../services/local_database_service.dart';

class PlaceRepository {
  PlaceRepository({required this.apiService, required this.databaseService});

  final ApiService apiService;
  final LocalDatabaseService databaseService;

  Future<List<TourPlace>> loadPlaces({String languageCode = 'en'}) =>
      apiService.fetchPlaces(languageCode: languageCode);
  Stream<List<SavedPlaceEntity>> watchSavedPlaces() =>
      databaseService.watchSavedPlaces();

  Future<void> savePlace(TourPlace place) {
    return databaseService.savePlace(
      remoteId: place.id,
      title: place.title,
      notes: place.body,
      latitude: place.latitude,
      longitude: place.longitude,
    );
  }

  Future<void> removeSavedPlace(int remoteId) =>
      databaseService.deleteSavedPlace(remoteId);
}
