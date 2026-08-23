import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../app/providers.dart';
import '../../data/models/city_note.dart';
import '../../data/models/map_focus_target.dart';
import '../../data/models/saved_place_entity.dart';
import '../../data/models/tour_place.dart';
import '../../data/services/location_service.dart';
import '../../domain/place_marker_clusterer.dart';
import '../../l10n/app_localizations.dart';
import '../shared/add_idea_map_button.dart';
import '../shared/add_note_to_plan_sheet.dart';
import '../shared/add_saved_place_to_plan_sheet.dart';
import '../shared/note_attachment.dart';
import '../shared/place_cluster_marker_button.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({
    super.key,
    this.initialCenter,
    this.focusTarget,
    this.tileProvider,
    this.mapController,
  });

  final LatLng? initialCenter;
  final MapFocusTarget? focusTarget;
  final TileProvider? tileProvider;
  final MapController? mapController;

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  static const _placeClusterer = PlaceMarkerClusterer();

  late final MapController _mapController;
  Timer? _discoveryDebounce;
  LatLng? _selectedPosition;
  MapFocusTarget? _focusedTarget;
  bool _mapReady = false;
  bool _initialLocationApplied = false;
  double _clusterZoom = 13.5;

  @override
  void initState() {
    super.initState();
    _mapController = widget.mapController ?? MapController();
    _focusedTarget = widget.focusTarget;
    if (_focusedTarget != null) _clusterZoom = 17;
  }

  @override
  void didUpdateWidget(covariant MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusTarget?.key == oldWidget.focusTarget?.key) return;
    final target = widget.focusTarget;
    if (target == null) {
      setState(() => _focusedTarget = null);
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusOnTarget(target);
    });
  }

  @override
  void dispose() {
    _discoveryDebounce?.cancel();
    if (widget.mapController == null) _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final location = ref.watch(locationProvider);
    final useGps = ref.watch(useGpsProvider);
    final resolvedLocation = location.value;
    final currentLocation = useGps ? resolvedLocation : null;
    final discoveryArea = ref.watch(discoveryAreaProvider);
    final placesState = ref.watch(placesProvider);
    final places = placesState.value ?? const <TourPlace>[];
    final placeClusters = _placeClusterer.cluster(places, zoom: _clusterZoom);
    final discoveryStatus = switch (placesState) {
      AsyncError() => l10n.guideError,
      AsyncLoading() => l10n.updatingNearbyPlaces,
      _ => l10n.recommendationsFollowMap,
    };
    final savedPlaces =
        ref.watch(savedPlacesProvider).value ?? const <SavedPlaceEntity>[];
    final recommendedIds = {for (final place in places) place.id};
    final savedOnlyPlaces = savedPlaces.where(
      (saved) => !recommendedIds.contains(saved.remoteId),
    );
    final notes = ref.watch(notesProvider).value ?? const <CityNote>[];
    final mapCenter =
        _focusedTarget?.position ??
        widget.initialCenter ??
        discoveryArea?.center ??
        resolvedLocation ??
        defaultDiscoveryCenter;
    final waitingForInitialLocation =
        location.isLoading &&
        _focusedTarget == null &&
        widget.initialCenter == null &&
        discoveryArea == null;

    ref.listen(locationProvider, (previous, next) {
      if (next case AsyncData(:final value)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _applyInitialLocation(value);
        });
      }
    });

    return Scaffold(
      appBar: AppBar(title: Text(l10n.map)),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: mapCenter,
              initialZoom: _focusedTarget != null
                  ? 17
                  : widget.initialCenter != null
                  ? 16
                  : 13.5,
              onMapReady: _handleMapReady,
              onPositionChanged: _scheduleDiscoveryUpdate,
              onTap: (_, point) => setState(() {
                _focusedTarget = null;
                _selectedPosition = point;
              }),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.pracazaliczeniowamobileapp',
                tileProvider: widget.tileProvider,
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
                            _savedPlaceFor(cluster.places.single, savedPlaces),
                          )
                        : _placeClusterMarker(cluster, savedPlaces),
                  ),
                  ...savedOnlyPlaces.map(_savedPlaceMarker),
                  ...notes.map((note) => _noteMarker(note)),
                  if (_focusedTarget case final target?)
                    _focusedMarker(target, savedPlaces, notes),
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
              key: _focusedTarget == null
                  ? null
                  : const ValueKey('map-focus-banner'),
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
                        Icon(
                          _focusedTarget?.type == MapFocusType.idea
                              ? Icons.edit_location_alt
                              : _focusedTarget == null
                              ? Icons.travel_explore
                              : Icons.location_on,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _focusedTarget?.title ?? discoveryStatus,
                            style: _focusedTarget == null
                                ? null
                                : Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        if (_focusedTarget != null)
                          IconButton(
                            tooltip: l10n.close,
                            onPressed: () =>
                                setState(() => _focusedTarget = null),
                            icon: const Icon(Icons.close),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _focusedTarget != null
                          ? l10n.highlightedOnMap
                          : _selectedPosition == null
                          ? l10n.mapIdeaPrompt
                          : l10n.mapIdeaSelected,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (_focusedTarget == null && placesState.isLoading) ...[
                      const SizedBox(height: 8),
                      const LinearProgressIndicator(),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (waitingForInitialLocation)
            const Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: LinearProgressIndicator(),
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
        onPressed: () => _focusAndShowPlace(place, savedPlace),
      ),
    ),
  );

  Marker _savedPlaceMarker(SavedPlaceEntity savedPlace) => _placeMarker(
    TourPlace(
      id: savedPlace.remoteId,
      title: savedPlace.title,
      body: savedPlace.notes,
      latitude: savedPlace.latitude,
      longitude: savedPlace.longitude,
    ),
    savedPlace,
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
                          if (mounted) {
                            _focusAndShowPlace(place, savedPlace);
                          }
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
      onPressed: () => _focusAndShowIdea(note),
    ),
  );

  Marker _focusedMarker(
    MapFocusTarget target,
    List<SavedPlaceEntity> savedPlaces,
    List<CityNote> notes,
  ) => Marker(
    point: target.position,
    width: 74,
    height: 74,
    child: Semantics(
      label: target.title,
      button: true,
      child: Container(
        key: ValueKey('focused-map-marker-${target.key}'),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.tertiaryContainer,
          border: Border.all(
            color: Theme.of(context).colorScheme.tertiary,
            width: 5,
          ),
          boxShadow: const [
            BoxShadow(color: Colors.black38, blurRadius: 10, spreadRadius: 2),
          ],
        ),
        child: IconButton(
          tooltip: target.title,
          iconSize: 34,
          icon: Icon(
            target.type == MapFocusType.idea
                ? Icons.edit_location_alt
                : target.saved
                ? Icons.bookmark
                : Icons.location_on,
          ),
          onPressed: () {
            if (target.type == MapFocusType.place) {
              final savedPlace = savedPlaces
                  .where((place) => place.remoteId == target.placeId)
                  .firstOrNull;
              _showPlaceSheet(target.asPlace, savedPlace);
              return;
            }
            final note = notes
                .where((note) => note.id == target.noteId)
                .firstOrNull;
            if (note != null) _showIdeaDialog(note);
          },
        ),
      ),
    ),
  );

  void _focusAndShowPlace(TourPlace place, SavedPlaceEntity? savedPlace) {
    _focusOnTarget(MapFocusTarget.place(place, saved: savedPlace != null));
    _showPlaceSheet(place, savedPlace);
  }

  void _focusAndShowIdea(CityNote note) {
    _focusOnTarget(MapFocusTarget.idea(note));
    _showIdeaDialog(note);
  }

  void _focusOnTarget(MapFocusTarget target) {
    setState(() {
      _focusedTarget = target;
      _selectedPosition = null;
    });
    if (!_mapReady) return;
    _mapController.move(target.position, 17);
    _updateClusterZoom(17);
    _updateDiscoveryArea(_mapController.camera);
  }

  void _showIdeaDialog(CityNote note) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(note.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(note.body),
          if (note.hasAttachment) ...[
            const SizedBox(height: 12),
            NoteAttachmentSummary(note: note),
          ],
        ],
      ),
      actions: [
        if (note.hasAttachment)
          TextButton.icon(
            onPressed: () => openNoteAttachment(this.context, ref, note),
            icon: const Icon(Icons.attachment_outlined),
            label: Text(AppLocalizations.of(this.context).openAttachment),
          ),
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
  );

  Future<void> _centerOnMyLocation() async {
    ref.read(useGpsProvider.notifier).state = true;
    final preferences = await ref.read(preferencesProvider.future);
    await preferences.setUseGps(true);
    try {
      final position = await ref
          .read(locationServiceProvider)
          .currentPosition();
      if (!mounted) return;
      ref.read(latestDeviceLocationProvider.notifier).state = position;
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

  void _handleMapReady() {
    if (_mapReady) return;
    _mapReady = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateClusterZoom(_mapController.camera.zoom);
      if (_focusedTarget case final target?) {
        _mapController.move(target.position, 17);
        _updateClusterZoom(17);
        _updateDiscoveryArea(_mapController.camera);
        return;
      }
      if (widget.initialCenter != null) {
        _updateDiscoveryArea(_mapController.camera);
        return;
      }
      final initialLocation = ref.read(locationProvider).value;
      if (initialLocation != null) _applyInitialLocation(initialLocation);
    });
  }

  void _applyInitialLocation(LatLng location) {
    if (!_mapReady ||
        _initialLocationApplied ||
        _focusedTarget != null ||
        widget.initialCenter != null ||
        ref.read(discoveryAreaProvider) != null) {
      return;
    }
    _initialLocationApplied = true;
    _mapController.move(location, 13.5);
    _updateClusterZoom(_mapController.camera.zoom);
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
