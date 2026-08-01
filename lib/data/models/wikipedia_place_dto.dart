import 'package:freezed_annotation/freezed_annotation.dart';

import 'tour_place.dart';

part 'wikipedia_place_dto.freezed.dart';
part 'wikipedia_place_dto.g.dart';

@freezed
abstract class WikipediaGeoSearchResponse with _$WikipediaGeoSearchResponse {
  const factory WikipediaGeoSearchResponse({
    required WikipediaGeoSearchQuery query,
  }) = _WikipediaGeoSearchResponse;

  factory WikipediaGeoSearchResponse.fromJson(Map<String, dynamic> json) =>
      _$WikipediaGeoSearchResponseFromJson(json);
}

@freezed
abstract class WikipediaGeoSearchQuery with _$WikipediaGeoSearchQuery {
  const factory WikipediaGeoSearchQuery({
    @Default(<WikipediaPlaceDto>[]) List<WikipediaPlaceDto> pages,
  }) = _WikipediaGeoSearchQuery;

  factory WikipediaGeoSearchQuery.fromJson(Map<String, dynamic> json) =>
      _$WikipediaGeoSearchQueryFromJson(json);
}

@freezed
abstract class WikipediaPlaceDto with _$WikipediaPlaceDto {
  const factory WikipediaPlaceDto({
    @JsonKey(name: 'pageid') required int pageId,
    required String title,
    @Default(0) int index,
    String? extract,
    @Default(<WikipediaCoordinateDto>[])
    List<WikipediaCoordinateDto> coordinates,
  }) = _WikipediaPlaceDto;

  factory WikipediaPlaceDto.fromJson(Map<String, dynamic> json) =>
      _$WikipediaPlaceDtoFromJson(json);
}

@freezed
abstract class WikipediaCoordinateDto with _$WikipediaCoordinateDto {
  const factory WikipediaCoordinateDto({
    required double lat,
    required double lon,
  }) = _WikipediaCoordinateDto;

  factory WikipediaCoordinateDto.fromJson(Map<String, dynamic> json) =>
      _$WikipediaCoordinateDtoFromJson(json);
}

extension WikipediaPlaceMapping on WikipediaPlaceDto {
  TourPlace? toTourPlace({required String languageCode}) {
    final coordinate = coordinates.firstOrNull;
    if (coordinate == null) return null;

    final description = extract?.trim();
    final fallbackDescription = languageCode == 'pl'
        ? 'Miejsce opisane w Wikipedii.'
        : 'A place described on Wikipedia.';
    final sourceLabel = languageCode == 'pl'
        ? 'Źródło: Wikipedia'
        : 'Source: Wikipedia';
    return TourPlace(
      id: pageId,
      title: title,
      body:
          '${description == null || description.isEmpty ? fallbackDescription : description}\n\n$sourceLabel',
      latitude: coordinate.lat,
      longitude: coordinate.lon,
    );
  }
}
