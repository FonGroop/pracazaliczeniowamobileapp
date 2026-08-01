import 'package:freezed_annotation/freezed_annotation.dart';

part 'tour_place.freezed.dart';
part 'tour_place.g.dart';

@freezed
abstract class TourPlace with _$TourPlace {
  const factory TourPlace({
    required int id,
    required String title,
    required String body,
    required double latitude,
    required double longitude,
  }) = _TourPlace;

  factory TourPlace.fromJson(Map<String, dynamic> json) =>
      _$TourPlaceFromJson(json);

  factory TourPlace.fromApiJson(Map<String, dynamic> json) {
    final id = (json['id'] as num?)?.toInt() ?? 0;
    return TourPlace(
      id: id,
      title: (json['title'] as String?) ?? 'City stop $id',
      body: (json['body'] as String?) ?? 'No description',
      latitude: 52.2297 + (id % 8) * 0.012,
      longitude: 21.0122 + (id % 8) * 0.014,
    );
  }
}
