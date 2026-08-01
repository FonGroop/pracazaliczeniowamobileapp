import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../app/providers.dart';
import '../../data/models/city_note.dart';
import '../../data/models/saved_place_entity.dart';
import '../../data/models/tour_place.dart';
import '../../data/services/location_service.dart';
import '../../domain/place_marker_clusterer.dart';
import '../../l10n/app_localizations.dart';
import '../shared/add_idea_map_button.dart';
import '../shared/add_note_to_plan_sheet.dart';
import '../shared/add_saved_place_to_plan_sheet.dart';
import '../shared/place_cluster_marker_button.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key, this.initialCenter});

  final LatLng? initialCenter;

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  static const _placeClusterer = PlaceMarkerClusterer();

  final _mapController = MapController();
  Timer? _discoveryDebounce;
  LatLng? _selectedPosition;
  bool _discoveryInitialized = false;
  double _clusterZoom = 13.5;

  @override
  void dispose() {
    _discoveryDebounce?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final location = ref.watch(locationProvider);
    final useGps = ref.watch(useGpsProvider);
    final resolvedLocation = location.asData?.value;
    final currentLocation = useGps ? resolvedLocation : null;
    final discoveryArea = ref.watch(discoveryAreaProvider);
    final placesState = ref.watch(placesProvider);
    final places = placesState.asData?.value ?? const <TourPlace>[];
    final placeClusters = _placeClusterer.cluster(places, zoom: _clusterZoom);
    final discoveryStatus = switch (placesState) {
      AsyncError() => l10n.guideError,
      AsyncLoading() => l10n.updatingNearbyPlaces,
      _ => l10n.recommendationsFollowMap,
    };
    final savedPlaces =
        ref.watch(savedPlacesProvider).value ?? const <SavedPlaceEntity>[];
    final notes = ref.watch(notesProvider).value ?? const <CityNote>[];
    final mapCenter =
        widget.initialCenter ??
        discoveryArea?.center ??
        resolvedLocation ??
        const LatLng(52.2297, 21.0122);
    final waitingForInitialLocation =
        location.isLoading &&
        widget.initialCenter == null &&
        discoveryArea == null;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.map)),
      body: waitingForInitialLocation
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: mapCenter,
                    initialZoom: 13.5,
                    onMapReady: _initializeDiscoveryFromMap,
                    onPositionChanged: _scheduleDiscoveryUpdate,
                    onTap: (_, point) =>
                        setState(() => _selectedPosition = point),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName:
                          'com.example.pracazaliczeniowamobileapp',
                    ),
                    MarkerLayer(
                      markers: [
                        if (currentLocation != null)
                          Marker(
                            point: currentLocation,
                            width: 50,
                            height: 50,
                            child: Tooltip(
                              message: l10n.yourLocation,
                              child: Icon(
                                Icons.my_location,
                                color: Theme.of(context).colorScheme.primary,
                                size: 34,
                              ),
                            ),
                          ),
                        ...placeClusters.map(
                          (cluster) => cluster.places.length == 1
                              ? _placeMarker(
                                  cluster.places.single,
                                  _savedPlaceFor(
                                    cluster.places.single,
                                    savedPlaces,
                                  ),
                                )
                              : _placeClusterMarker(cluster, savedPlaces),
                        ),
                        ...notes.map((note) => _noteMarker(note)),
                        if (_selectedPosition case final position?)
                          Marker(
                            point: position,
                            width: 52,
                            height: 52,
                            child: Icon(
                              Icons.add_location_alt,
                              color: Theme.of(context).colorScheme.error,
                              size: 38,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  top: 16,
                  child: Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.travel_explore, size: 20),
                              const SizedBox(width: 8),
                              Expanded(child: Text(discoveryStatus)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _selectedPosition == null
                                ? l10n.mapIdeaPrompt
                                : l10n.mapIdeaSelected,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (placesState.isLoading) ...[
                            const SizedBox(height: 8),
                            const LinearProgressIndicator(),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          AddIdeaMapButton(
            selectedPosition: _selectedPosition,
            label: l10n.addIdea,
            disabledTooltip: l10n.selectPointBeforeIdea,
            onCreate: (position) =>
                context.pushNamed('ideaCreate', extra: position),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'gps',
            onPressed: _centerOnMyLocation,
            icon: const Icon(Icons.gps_fixed),
            label: Text(l10n.centerOnLocation),
          ),
        ],
      ),
    );
  }

  Marker _placeMarker(TourPlace place, SavedPlaceEntity? savedPlace) => Marker(
    point: LatLng(place.latitude, place.longitude),
    width: 52,
    height: 52,
    child: Tooltip(
      message: savedPlace == null
          ? place.title
          : '${place.title} (${AppLocalizations.of(context).savedFlash})',
      child: IconButton.filled(
        tooltip: AppLocalizations.of(context).openDetails,
        icon: Icon(savedPlace == null ? Icons.location_on : Icons.bookmark),
        onPressed: () => _showPlaceSheet(place, savedPlace),
      ),
    ),
  );

  Marker _placeClusterMarker(
    PlaceMarkerCluster cluster,
    List<SavedPlaceEntity> savedPlaces,
  ) => Marker(
    point: cluster.center,
    width: 60,
    height: 60,
    child: PlaceClusterMarkerButton(
      count: cluster.places.length,
      tooltip: AppLocalizations.of(
        context,
      ).placesInCluster(cluster.places.length),
      onPressed: () => _showPlaceClusterSheet(cluster, savedPlaces),
    ),
  );

  SavedPlaceEntity? _savedPlaceFor(
    TourPlace place,
    List<SavedPlaceEntity> savedPlaces,
  ) => savedPlaces.where((saved) => saved.remoteId == place.id).firstOrNull;

  void _showPlaceClusterSheet(
    PlaceMarkerCluster cluster,
    List<SavedPlaceEntity> savedPlaces,
  ) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.65,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.placesInCluster(cluster.places.length),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.zoomInToSeparateMarkers,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: cluster.places.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final place = cluster.places[index];
                    final savedPlace = _savedPlaceFor(place, savedPlaces);
                    return ListTile(
                      leading: Icon(
                        savedPlace == null
                            ? Icons.location_on_outlined
                            : Icons.bookmark,
                      ),
                      title: Text(place.title),
                      subtitle: Text(
                        place.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) _showPlaceSheet(place, savedPlace);
                        });
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPlaceSheet(TourPlace place, SavedPlaceEntity? savedPlace) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(place.title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(place.body, maxLines: 3, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  context.pushNamed(
                    'details',
                    pathParameters: {'id': '${place.id}'},
                    extra: place,
                  );
                },
                icon: const Icon(Icons.open_in_new),
                label: Text(l10n.openDetails),
              ),
              const SizedBox(height: 8),
              if (savedPlace == null)
                OutlinedButton.icon(
                  onPressed: () async {
                    await ref.read(placeRepositoryProvider).savePlace(place);
                    if (sheetContext.mounted) {
                      Navigator.pop(sheetContext);
                    }
                    showAppNotice(ref, l10n.savedPlace);
                  },
                  icon: const Icon(Icons.bookmark_add_outlined),
                  label: Text(l10n.savePlace),
                )
              else
                OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(sheetContext);
                    await showAddSavedPlaceToPlanSheet(
                      context: context,
                      place: savedPlace,
                    );
                  },
                  icon: const Icon(Icons.add_task_outlined),
                  label: Text(l10n.addToPlan),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Marker _noteMarker(CityNote note) => Marker(
    point: LatLng(note.latitude, note.longitude),
    width: 52,
    height: 52,
    child: IconButton.filledTonal(
      tooltip: note.title,
      icon: const Icon(Icons.edit_location_alt),
      onPressed: () => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(note.title),
          content: Text([note.body].join('\n\n')),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                this.context.pushNamed('ideaEdit', extra: note);
              },
              child: Text(AppLocalizations.of(this.context).editIdea),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await showAddNoteToPlanSheet(context: this.context, note: note);
              },
              child: Text(AppLocalizations.of(this.context).addToPlan),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(AppLocalizations.of(this.context).close),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _centerOnMyLocation() async {
    ref.read(useGpsProvider.notifier).state = true;
    final preferences = await ref.read(preferencesProvider.future);
    await preferences.setUseGps(true);
    try {
      final position = await ref.refresh(locationProvider.future);
      if (!mounted) return;
      _mapController.move(position, 14);
      _updateClusterZoom(_mapController.camera.zoom);
      _updateDiscoveryArea(_mapController.camera);
      showAppNotice(ref, AppLocalizations.of(context).mapCentered);
    } on LocationFailure catch (failure) {
      if (mounted) await _showLocationFailure(failure);
    } on Object {
      if (mounted) {
        showAppNotice(ref, AppLocalizations.of(context).gpsUnavailable);
      }
    }
  }

  Future<void> _showLocationFailure(LocationFailure failure) async {
    final l10n = AppLocalizations.of(context);
    final message = switch (failure) {
      LocationServicesDisabled() => l10n.locationServicesDisabled,
      LocationPermissionDenied() => l10n.locationPermissionDenied,
      LocationPermissionPermanentlyDenied() =>
        l10n.locationPermissionPermanentlyDenied,
      LocationFixUnavailable() => l10n.locationFixUnavailable,
    };
    final shouldOpenSettings = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.locationUnavailable),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.settings_outlined),
            label: Text(l10n.openSettings),
          ),
        ],
      ),
    );
    if (shouldOpenSettings != true || !mounted) return;

    final opened = await ref
        .read(locationServiceProvider)
        .openSettingsFor(failure);
    if (!opened && mounted) {
      showAppNotice(ref, l10n.locationSettingsOpenFailed);
    }
  }

  void _initializeDiscoveryFromMap() {
    if (_discoveryInitialized) return;
    _discoveryInitialized = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateClusterZoom(_mapController.camera.zoom);
      _updateDiscoveryArea(_mapController.camera);
    });
  }

  void _scheduleDiscoveryUpdate(MapCamera camera, bool hasGesture) {
    if (!hasGesture) return;
    _discoveryDebounce?.cancel();
    _discoveryDebounce = Timer(const Duration(milliseconds: 650), () {
      if (!mounted) return;
      _updateClusterZoom(camera.zoom);
      _updateDiscoveryArea(camera);
    });
  }

  void _updateClusterZoom(double zoom) {
    if ((_clusterZoom - zoom).abs() < 0.05) return;
    setState(() => _clusterZoom = zoom);
  }

  void _updateDiscoveryArea(MapCamera camera) {
    final next = (
      center: camera.center,
      radiusMeters: _searchRadiusFor(camera),
    );
    final current = ref.read(discoveryAreaProvider);
    if (current != null) {
      const distance = Distance();
      final movedMeters = distance.as(
        LengthUnit.Meter,
        current.center,
        next.center,
      );
      final radiusChanged =
          (current.radiusMeters - next.radiusMeters).abs() >= 500;
      if (movedMeters < 150 && !radiusChanged) return;
    }
    ref.read(discoveryAreaProvider.notifier).state = next;
  }

  int _searchRadiusFor(MapCamera camera) {
    const distance = Distance();
    final meters = distance.as(
      LengthUnit.Meter,
      camera.center,
      camera.visibleBounds.northEast,
    );
    return meters.round().clamp(1000, 10000);
  }
}
