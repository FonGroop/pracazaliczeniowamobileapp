import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../app/providers.dart';
import '../../data/models/city_note.dart';
import '../../data/models/saved_place_entity.dart';
import '../../data/models/tour_place.dart';
import '../../l10n/app_localizations.dart';
import '../shared/add_note_to_plan_sheet.dart';
import '../shared/add_saved_place_to_plan_sheet.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key, this.initialCenter});

  final LatLng? initialCenter;

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _mapController = MapController();
  LatLng? _selectedPosition;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final location = ref.watch(locationProvider);
    final places = ref.watch(placesProvider).value ?? const <TourPlace>[];
    final savedPlaces =
        ref.watch(savedPlacesProvider).value ?? const <SavedPlaceEntity>[];
    final notes = ref.watch(notesProvider).value ?? const <CityNote>[];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.map)),
      body: location.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: Text(l10n.locationUnavailable)),
        data: (center) {
          final mapCenter = widget.initialCenter ?? center;
          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: mapCenter,
                  initialZoom: 12,
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
                      Marker(
                        point: center,
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
                      ...places.map(
                        (place) => _placeMarker(
                          place,
                          savedPlaces
                              .where((saved) => saved.remoteId == place.id)
                              .firstOrNull,
                        ),
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
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Text(
                      _selectedPosition == null
                          ? l10n.mapIdeaPrompt
                          : l10n.mapIdeaSelected,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: location.value == null
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'new_idea',
                  onPressed: () => context.pushNamed(
                    'ideaCreate',
                    extra: _selectedPosition ?? location.value,
                  ),
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: Text(l10n.addIdea),
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
      _mapController.move(position, 14);
      if (mounted) showAppNotice(ref, AppLocalizations.of(context).mapCentered);
    } catch (_) {
      if (mounted) {
        showAppNotice(ref, AppLocalizations.of(context).gpsUnavailable);
      }
    }
  }
}
