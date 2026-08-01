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
}
