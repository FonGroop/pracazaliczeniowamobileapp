import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:latlong2/latlong.dart';

import '../data/models/city_note.dart';
import '../data/models/plan_item.dart';
import '../data/models/saved_place_entity.dart';
import '../data/models/travel_plan.dart';
import '../data/models/tour_place.dart';
import '../data/repositories/place_repository.dart';
import '../data/repositories/note_repository.dart';
import '../data/repositories/plan_repository.dart';
import '../data/services/api_service.dart';
import '../data/services/attachment_service.dart';
import '../data/services/local_database_service.dart';
import '../data/services/firebase_service.dart';
import '../data/services/location_service.dart';
import '../data/services/preferences_service.dart';

final preferencesProvider = FutureProvider<PreferencesService>(
  (ref) => PreferencesService.create(),
);

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);
final localeProvider = StateProvider<Locale>((ref) => const Locale('en'));
final useGpsProvider = StateProvider<bool>((ref) => true);
final appNoticeProvider = StateProvider<String?>((ref) => null);

void showAppNotice(WidgetRef ref, String message) {
  ref.read(appNoticeProvider.notifier).state = message;
}

final placeRepositoryProvider = Provider<PlaceRepository>((ref) {
  return PlaceRepository(
    apiService: ApiService(),
    databaseService: LocalDatabaseService.instance,
  );
});

typedef DiscoveryArea = ({LatLng center, int radiusMeters});

/// The area currently driving recommendations on both Discover and Map.
/// A null value means that the user's configured starting location is used.
final discoveryAreaProvider = StateProvider<DiscoveryArea?>((ref) => null);

final placesProvider = FutureProvider<List<TourPlace>>((ref) async {
  final languageCode = ref.watch(localeProvider).languageCode;
  final area = ref.watch(discoveryAreaProvider);
  final LatLng searchCenter;
  if (area != null) {
    searchCenter = area.center;
  } else {
    searchCenter = await ref.watch(locationProvider.future);
  }
  final repository = ref.watch(placeRepositoryProvider);
  final radiusMeters = area?.radiusMeters ?? 5000;
  return repository.loadPlaces(
    languageCode: languageCode,
    center: searchCenter,
    radiusMeters: radiusMeters,
  );
});

final savedPlacesProvider = StreamProvider<List<SavedPlaceEntity>>((ref) {
  return ref.watch(placeRepositoryProvider).watchSavedPlaces();
});

final planRepositoryProvider = Provider<PlanRepository>((ref) {
  return PlanRepository(databaseService: LocalDatabaseService.instance);
});

final plansProvider = StreamProvider<List<TravelPlan>>((ref) {
  return ref.watch(planRepositoryProvider).watchPlans();
});

final planProvider = StreamProvider.family<TravelPlan?, String>((ref, planId) {
  return ref.watch(planRepositoryProvider).watchPlan(planId);
});

final planItemsProvider = StreamProvider.family<List<PlanItem>, String>(
  (ref, planId) => ref.watch(planRepositoryProvider).watchPlanItems(planId),
);

final noteRepositoryProvider = Provider<NoteRepository>((ref) {
  return NoteRepository(
    databaseService: LocalDatabaseService.instance,
    firebaseService: FirebaseService(),
    attachmentService: AttachmentService(),
  );
});

final notesProvider = StreamProvider<List<CityNote>>((ref) {
  return ref.watch(noteRepositoryProvider).watchNotes();
});

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

final latestDeviceLocationProvider = StateProvider<LatLng?>((ref) => null);

final locationProvider = FutureProvider<LatLng>((ref) {
  final useGps = ref.watch(useGpsProvider);
  if (!useGps) return Future.value(const LatLng(52.2297, 21.0122));
  final latestLocation = ref.watch(latestDeviceLocationProvider);
  if (latestLocation != null) return Future.value(latestLocation);
  return ref.watch(locationServiceProvider).initialPosition();
});
