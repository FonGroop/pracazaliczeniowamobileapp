import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

import '../../config/env.dart';
import '../models/wikipedia_place_dto.dart';

class PlacesApiException implements Exception {
  const PlacesApiException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => 'PlacesApiException: $message';
}

class ApiService {
  ApiService({Dio? dio, String? endpointTemplate})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 6),
              receiveTimeout: const Duration(seconds: 6),
              headers: const {
                'Api-User-Agent': 'CityCompanion/1.0 (Flutter student project)',
              },
            ),
          ),
      _endpointTemplate = endpointTemplate ?? Env.placesApiUrl;

  final Dio _dio;
  final String _endpointTemplate;

  Future<List<WikipediaPlaceDto>> fetchNearbyPlaces({
    String languageCode = 'en',
    required LatLng center,
    int radiusMeters = 5000,
  }) async {
    final wikiLanguage = languageCode == 'pl' ? 'pl' : 'en';
    final endpoint = _endpointTemplate.replaceFirst('{language}', wikiLanguage);
    final coordinates =
        '${center.latitude.toStringAsFixed(6)}|'
        '${center.longitude.toStringAsFixed(6)}';
    final safeRadius = radiusMeters.clamp(1000, 10000);
    final pages = await _fetchArea(
      endpoint,
      coordinates,
      radiusMeters: safeRadius,
    );

    final sorted = [...pages]..sort((a, b) => a.index.compareTo(b.index));
    final selectedById = <int, WikipediaPlaceDto>{};
    for (final place in sorted.where((item) => item.coordinates.isNotEmpty)) {
      selectedById.putIfAbsent(place.pageId, () => place);
      if (selectedById.length == 10) break;
    }

    if (selectedById.isEmpty) {
      throw const PlacesApiException(
        'Wikipedia returned no usable places near the map center.',
      );
    }
    return selectedById.values.toList(growable: false);
  }

  Future<List<WikipediaPlaceDto>> _fetchArea(
    String endpoint,
    String coordinates, {
    required int radiusMeters,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        endpoint,
        queryParameters: {
          'action': 'query',
          'generator': 'geosearch',
          'ggscoord': coordinates,
          'ggsradius': radiusMeters,
          'ggslimit': 10,
          'ggsnamespace': 0,
          'prop': 'coordinates|extracts',
          'exintro': 1,
          'explaintext': 1,
          'exchars': 260,
          'format': 'json',
          'formatversion': 2,
          'origin': '*',
        },
      );

      final json = response.data;
      if (json == null) {
        throw const PlacesApiException('Wikipedia returned no JSON data.');
      }
      if (json['query'] == null) return const <WikipediaPlaceDto>[];
      return WikipediaGeoSearchResponse.fromJson(json).query.pages;
    } on PlacesApiException {
      rethrow;
    } on DioException catch (error) {
      throw PlacesApiException('Wikipedia request failed.', error);
    } on Object catch (error) {
      throw PlacesApiException(
        'Wikipedia response could not be decoded.',
        error,
      );
    }
  }
}
