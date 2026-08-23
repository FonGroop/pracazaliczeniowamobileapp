import 'package:latlong2/latlong.dart';

import '../models/saved_place_entity.dart';
import '../models/tour_place.dart';
import '../models/wikipedia_place_dto.dart';
import '../services/api_service.dart';
import '../services/local_database_service.dart';

class PlaceRepository {
  PlaceRepository({required this.apiService, required this.databaseService});

  final PlacesGateway apiService;
  final SavedPlaceStore databaseService;
  final _recommendationCache = <_PlaceSearchKey, List<TourPlace>>{};
  final _requestsInProgress = <_PlaceSearchKey, Future<List<TourPlace>>>{};

  Future<List<TourPlace>> loadPlaces({
    String languageCode = 'en',
    required LatLng center,
    int radiusMeters = 5000,
    bool forceRefresh = false,
  }) {
    final key = _placeSearchKey(
      languageCode: languageCode,
      center: center,
      radiusMeters: radiusMeters,
    );
    if (!forceRefresh) {
      final cached = _recommendationCache[key];
      if (cached != null) return Future.value(cached);
      final request = _requestsInProgress[key];
      if (request != null) return request;
    }

    final request =
        _loadPlacesFromSource(
              languageCode: languageCode,
              center: center,
              radiusMeters: radiusMeters,
            )
            .then((places) {
              _recommendationCache[key] = places;
              return places;
            })
            .whenComplete(() {
              _requestsInProgress.remove(key);
            });
    _requestsInProgress[key] = request;
    return request;
  }

  Future<List<TourPlace>> _loadPlacesFromSource({
    required String languageCode,
    required LatLng center,
    required int radiusMeters,
  }) async {
    try {
      final pages = await apiService.fetchNearbyPlaces(
        languageCode: languageCode,
        center: center,
        radiusMeters: radiusMeters,
      );
      final places = pages
          .map((page) => page.toTourPlace(languageCode: languageCode))
          .nonNulls
          .toList(growable: false);
      if (places.isNotEmpty) return places;
    } on PlacesApiException {
      final fallback = _nearbyFallbackPlaces(
        languageCode: languageCode,
        center: center,
        radiusMeters: radiusMeters,
      );
      if (fallback.isNotEmpty) return fallback;
      rethrow;
    }
    return const <TourPlace>[];
  }

  void clearRecommendationCache() => _recommendationCache.clear();

  List<TourPlace> _nearbyFallbackPlaces({
    required String languageCode,
    required LatLng center,
    required int radiusMeters,
  }) {
    final places = languageCode == 'pl' ? _placesPl : _placesEn;
    final searchRadius = radiusMeters.clamp(1000, 10000);
    const distance = Distance();
    return places
        .where(
          (place) =>
              distance.as(
                LengthUnit.Meter,
                center,
                LatLng(place.latitude, place.longitude),
              ) <=
              searchRadius,
        )
        .toList(growable: false);
  }

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

  static const _placesPl = <TourPlace>[
    TourPlace(
      id: 1,
      title: 'Rynek Starego Miasta',
      body:
          'Zacznij na Rynku Starego Miasta, a potem przejdź odtworzonymi ulicami w stronę Placu Zamkowego.',
      latitude: 52.2499,
      longitude: 21.0122,
    ),
    TourPlace(
      id: 2,
      title: 'Bulwary Wiślane',
      body:
          'Przejdź się promenadą nad Wisłą, podziwiaj panoramę miasta i zatrzymaj się na kawę.',
      latitude: 52.2433,
      longitude: 21.0311,
    ),
    TourPlace(
      id: 3,
      title: 'Łazienki Królewskie',
      body:
          'Spędź spokojne popołudnie wśród pałacowych alejek, jezior, ogrodów i Pomnika Chopina.',
      latitude: 52.2154,
      longitude: 21.0348,
    ),
    TourPlace(
      id: 4,
      title: 'Koneser na Pradze',
      body:
          'Odkryj odnowiony kompleks dawnej wytwórni wódki z restauracjami, sklepami i muzeum.',
      latitude: 52.2553,
      longitude: 21.0432,
    ),
    TourPlace(
      id: 5,
      title: 'Taras Pałacu Kultury',
      body: 'Wjedź na taras widokowy i zobacz panoramę centrum Warszawy.',
      latitude: 52.2319,
      longitude: 21.0067,
    ),
    TourPlace(
      id: 6,
      title: 'Muzeum POLIN',
      body:
          'Odwiedź Muzeum Historii Żydów Polskich na terenie dawnego getta warszawskiego.',
      latitude: 52.2494,
      longitude: 20.9931,
    ),
  ];

  static const _placesEn = <TourPlace>[
    TourPlace(
      id: 1,
      title: 'Old Town Market Square',
      body:
          'Start at Rynek Starego Miasta, then walk through the rebuilt historic streets towards Castle Square.',
      latitude: 52.2499,
      longitude: 21.0122,
    ),
    TourPlace(
      id: 2,
      title: 'Vistula Boulevards',
      body:
          'Walk the riverside promenades for city views, cafés, and a relaxed sunset route.',
      latitude: 52.2433,
      longitude: 21.0311,
    ),
    TourPlace(
      id: 3,
      title: 'Royal Łazienki Park',
      body:
          'Spend a quiet afternoon among palace paths, lakes, gardens, and the Chopin Monument.',
      latitude: 52.2154,
      longitude: 21.0348,
    ),
    TourPlace(
      id: 4,
      title: 'Koneser in Praga',
      body:
          'Explore a restored vodka-factory complex with restaurants, design shops, and the Polish Vodka Museum.',
      latitude: 52.2553,
      longitude: 21.0432,
    ),
    TourPlace(
      id: 5,
      title: 'Palace of Culture viewpoint',
      body:
          'Take the lift to the observation terrace for a panoramic view of central Warsaw.',
      latitude: 52.2319,
      longitude: 21.0067,
    ),
    TourPlace(
      id: 6,
      title: 'POLIN Museum',
      body:
          'Visit the Museum of the History of Polish Jews in the former Warsaw Ghetto area.',
      latitude: 52.2494,
      longitude: 20.9931,
    ),
  ];
}

typedef _PlaceSearchKey = ({
  String languageCode,
  int latitudeBucket,
  int longitudeBucket,
  int radiusBucket,
});

_PlaceSearchKey _placeSearchKey({
  required String languageCode,
  required LatLng center,
  required int radiusMeters,
}) => (
  languageCode: languageCode == 'pl' ? 'pl' : 'en',
  latitudeBucket: (center.latitude * 1000).round(),
  longitudeBucket: (center.longitude * 1000).round(),
  radiusBucket: (radiusMeters / 500).round(),
);
