import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:pracazaliczeniowamobileapp/data/models/wikipedia_place_dto.dart';
import 'package:pracazaliczeniowamobileapp/data/services/api_service.dart';

void main() {
  const responseJson = <String, dynamic>{
    'batchcomplete': true,
    'query': <String, dynamic>{
      'pages': <Map<String, dynamic>>[
        <String, dynamic>{
          'pageid': 823101,
          'title': 'Rondo Romana Dmowskiego w Warszawie',
          'coordinates': <Map<String, dynamic>>[
            <String, dynamic>{'lat': 52.229861, 'lon': 21.01175},
          ],
          'extract': 'Rondo w śródmieściu Warszawy.',
        },
      ],
    },
  };

  test('Freezed decodes a Wikipedia page and maps it to a map place', () {
    final response = WikipediaGeoSearchResponse.fromJson(responseJson);
    final place = response.query.pages.single.toTourPlace(languageCode: 'pl');

    expect(place, isNotNull);
    expect(place!.id, 823101);
    expect(place.title, 'Rondo Romana Dmowskiego w Warszawie');
    expect(place.body, contains('Rondo w śródmieściu Warszawy.'));
    expect(place.body, endsWith('Źródło: Wikipedia'));
    expect(place.latitude, 52.229861);
    expect(place.longitude, 21.01175);
  });

  test('DIO requests Polish Wikipedia and returns decoded API pages', () async {
    final dio = Dio();
    String? requestedCoordinates;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          expect(options.uri.host, 'pl.wikipedia.org');
          expect(options.queryParameters['generator'], 'geosearch');
          expect(options.queryParameters['prop'], 'coordinates|extracts');
          requestedCoordinates = options.queryParameters['ggscoord'] as String;
          expect(options.queryParameters['ggsradius'], 4200);
          expect(options.queryParameters['ggslimit'], 10);
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: responseJson,
            ),
          );
        },
      ),
    );

    final service = ApiService(
      dio: dio,
      endpointTemplate: 'https://{language}.wikipedia.org/w/api.php',
    );
    final pages = await service.fetchNearbyPlaces(
      languageCode: 'pl',
      center: const LatLng(50.06143, 19.93658),
      radiusMeters: 4200,
    );

    expect(pages, hasLength(1));
    expect(pages.single.pageId, 823101);
    expect(requestedCoordinates, '50.061430|19.936580');
  });
}
