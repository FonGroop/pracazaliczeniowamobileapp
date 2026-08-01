import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../app/providers.dart';
import '../../data/models/city_note.dart';
import '../../data/models/saved_place_entity.dart';
import '../../l10n/app_localizations.dart';
import '../shared/add_saved_place_to_plan_sheet.dart';
import '../shared/note_sync_badge.dart';

class SavedScreen extends ConsumerWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.saved),
          bottom: TabBar(
            tabs: [
              Tab(icon: const Icon(Icons.bookmark_outline), text: l10n.places),
              Tab(
                icon: const Icon(Icons.lightbulb_outline),
                text: l10n.myIdeas,
              ),
            ],
          ),
        ),
        body: const TabBarView(children: [_SavedPlacesTab(), _SavedNotesTab()]),
      ),
    );
  }
}

class _SavedPlacesTab extends ConsumerWidget {
  const _SavedPlacesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedPlacesProvider);
    return saved.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) =>
          Center(child: Text(AppLocalizations.of(context).savedPlacesError)),
      data: (items) => items.isEmpty
          ? const _EmptySavedPlaces()
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) =>
                  _SavedPlaceTile(place: items[index]),
            ),
    );
  }
}

class _SavedPlaceTile extends ConsumerWidget {
  const _SavedPlaceTile({required this.place});

  final SavedPlaceEntity place;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.bookmark)),
        title: Text(place.title),
        subtitle: Text(
          place.notes,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: () => context.goNamed(
          'map',
          extra: LatLng(place.latitude, place.longitude),
        ),
        trailing: PopupMenuButton<_SavedPlaceAction>(
          tooltip: l10n.placeActions,
          onSelected: (action) => _handleAction(context, ref, action),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: _SavedPlaceAction.addToPlan,
              child: Text(l10n.addToPlan),
            ),
            PopupMenuItem(
              value: _SavedPlaceAction.showOnMap,
              child: Text(l10n.showOnMap),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: _SavedPlaceAction.remove,
              child: Text(l10n.removeSavedPlace),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    _SavedPlaceAction action,
  ) async {
    switch (action) {
      case _SavedPlaceAction.addToPlan:
        await showAddSavedPlaceToPlanSheet(context: context, place: place);
      case _SavedPlaceAction.showOnMap:
        if (context.mounted) {
          context.goNamed(
            'map',
            extra: LatLng(place.latitude, place.longitude),
          );
        }
      case _SavedPlaceAction.remove:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(AppLocalizations.of(context).removeSavedPlaceQuestion),
            content: Text(
              AppLocalizations.of(context).removeSavedPlaceDescription,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(AppLocalizations.of(context).cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(AppLocalizations.of(context).removeSavedPlace),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await ref
              .read(placeRepositoryProvider)
              .removeSavedPlace(place.remoteId);
          if (context.mounted) {
            showAppNotice(ref, AppLocalizations.of(context).savedPlaceRemoved);
          }
        }
    }
  }
}

enum _SavedPlaceAction { addToPlan, showOnMap, remove }

class _SavedNotesTab extends ConsumerWidget {
  const _SavedNotesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(notesProvider);
    return notes.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) =>
          Center(child: Text(AppLocalizations.of(context).ideasError)),
      data: (items) => items.isEmpty
          ? _EmptySavedNotes(onOpenNotes: () => context.goNamed('ideas'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ...items.map((note) => _SavedNoteTile(note: note)),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => context.goNamed('ideas'),
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(AppLocalizations.of(context).manageIdeas),
                ),
              ],
            ),
    );
  }
}

class _SavedNoteTile extends ConsumerWidget {
  const _SavedNoteTile({required this.note});

  final CityNote note;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    child: ListTile(
      leading: const CircleAvatar(child: Icon(Icons.lightbulb_outline)),
      title: Text(note.title),
      subtitle: Text(note.body, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          NoteSyncBadge(status: note.syncStatus),
          IconButton(
            tooltip: AppLocalizations.of(context).deleteNote,
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      onTap: () =>
          context.goNamed('map', extra: LatLng(note.latitude, note.longitude)),
    ),
  );

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).deleteIdeaQuestion),
        content: Text(AppLocalizations.of(context).deleteIdeaDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context).delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(noteRepositoryProvider).deleteIdea(note.id);
    if (context.mounted) {
      showAppNotice(ref, AppLocalizations.of(context).ideaDeleteSyncing);
    }
  }
}

class _EmptySavedPlaces extends StatelessWidget {
  const _EmptySavedPlaces();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bookmark_add_outlined, size: 48),
          SizedBox(height: 12),
          Text(
            AppLocalizations.of(context).welcomeBody,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class _EmptySavedNotes extends StatelessWidget {
  const _EmptySavedNotes({required this.onOpenNotes});

  final VoidCallback onOpenNotes;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lightbulb_outline, size: 48),
          const SizedBox(height: 12),
          Text(
            AppLocalizations.of(context).ideasEmpty,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onOpenNotes,
            icon: const Icon(Icons.lightbulb_outline),
            label: Text(AppLocalizations.of(context).openIdeas),
          ),
        ],
      ),
    ),
  );
}
