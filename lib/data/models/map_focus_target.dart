import 'package:latlong2/latlong.dart';

import 'city_note.dart';
import 'saved_place_entity.dart';
import 'tour_place.dart';

enum MapFocusType { place, idea }

class MapFocusTarget {
  const MapFocusTarget({
    required this.key,
    required this.type,
    required this.title,
    required this.body,
    required this.position,
    this.placeId,
    this.noteId,
    this.saved = false,
  });

  factory MapFocusTarget.place(TourPlace place, {bool saved = false}) =>
      MapFocusTarget(
        key: 'place-${place.id}',
        type: MapFocusType.place,
        title: place.title,
        body: place.body,
        position: LatLng(place.latitude, place.longitude),
        placeId: place.id,
        saved: saved,
      );

  factory MapFocusTarget.savedPlace(SavedPlaceEntity place) => MapFocusTarget(
    key: 'place-${place.remoteId}',
    type: MapFocusType.place,
    title: place.title,
    body: place.notes,
    position: LatLng(place.latitude, place.longitude),
    placeId: place.remoteId,
    saved: true,
  );

  factory MapFocusTarget.idea(CityNote note) => MapFocusTarget(
    key: 'idea-${note.id}',
    type: MapFocusType.idea,
    title: note.title,
    body: note.body,
    position: LatLng(note.latitude, note.longitude),
    noteId: note.id,
  );

  final String key;
  final MapFocusType type;
  final String title;
  final String body;
  final LatLng position;
  final int? placeId;
  final String? noteId;
  final bool saved;

  TourPlace get asPlace => TourPlace(
    id: placeId ?? 0,
    title: title,
    body: body,
    latitude: position.latitude,
    longitude: position.longitude,
  );
}
