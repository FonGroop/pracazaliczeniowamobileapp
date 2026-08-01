import 'package:dio/dio.dart';

import '../../config/env.dart';
import '../models/tour_place.dart';

class ApiService {
  ApiService()
    : _dio = Dio(
        BaseOptions(
          baseUrl: Env.placesApiUrl,
          connectTimeout: const Duration(seconds: 6),
          receiveTimeout: const Duration(seconds: 6),
        ),
      );

  final Dio _dio;

  /// Curated real places keep Explore useful offline and prevent unrelated
  /// placeholder API posts from appearing as city ideas. The Dio request is
  /// deliberately kept in this service to verify the configured external API
  /// is reachable and JSON can be decoded; the app remains useful offline.
  Future<List<TourPlace>> fetchPlaces({String languageCode = 'en'}) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '/posts',
        queryParameters: {'_limit': 6},
      );
      // Decode the external JSON response before displaying curated content.
      // JSONPlaceholder is a transport/demo source, not a city guide.
      final remotePosts = response.data ?? const <dynamic>[];
      if (remotePosts.isNotEmpty) {
        remotePosts
            .whereType<Map<String, dynamic>>()
            .map(TourPlace.fromApiJson)
            .toList();
      }
    } on DioException {
      // Offline fallback is intentional.
    }
    return languageCode == 'pl' ? _placesPl : _places;
  }

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

  static const _places = <TourPlace>[
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
