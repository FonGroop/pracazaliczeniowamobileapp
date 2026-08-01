import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../data/models/city_note.dart';
import '../../data/models/plan_item.dart';
import '../../data/models/saved_place_entity.dart';
import '../../l10n/app_localizations.dart';

class PlanDetailScreen extends ConsumerWidget {
  const PlanDetailScreen({super.key, required this.planId});

  final String planId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(planProvider(planId));
    final items = ref.watch(planItemsProvider(planId));
    final l10n = AppLocalizations.of(context);

    return plan.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => const Scaffold(body: _PlanUnavailable()),
      data: (value) {
        if (value == null) return const Scaffold(body: _PlanUnavailable());
        return Scaffold(
          appBar: AppBar(
            title: Text(value.name),
            actions: [
              IconButton(
                tooltip: l10n.deletePlan,
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _confirmDelete(context, ref),
              ),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: items.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => Center(child: Text(l10n.planStopsError)),
                data: (entries) => _PlanBody(
                  planId: planId,
                  notes: value.notes,
                  date: value.date,
                  items: entries,
                ),
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showAddStopSheet(context, ref),
            icon: const Icon(Icons.add_location_alt_outlined),
            label: Text(l10n.addStop),
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).deletePlanQuestion),
        content: Text(AppLocalizations.of(context).deletePlanDescription),
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
    await ref.read(planRepositoryProvider).deletePlan(planId);
    if (context.mounted) context.goNamed('planner');
  }

  void _showAddStopSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => _AddPlanStopSheet(planId: planId),
    );
  }
}

class _PlanBody extends ConsumerWidget {
  const _PlanBody({
    required this.planId,
    required this.notes,
    required this.date,
    required this.items,
  });

  final String planId;
  final String notes;
  final DateTime date;
  final List<PlanItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ReorderableListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        header: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat.yMMMMEEEEd(
                Localizations.localeOf(context).languageCode,
              ).format(date),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (notes.isNotEmpty) ...[const SizedBox(height: 8), Text(notes)],
            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context).itinerary,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (items.isEmpty)
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(AppLocalizations.of(context).itineraryEmpty),
                ),
              )
            else
              Text(
                AppLocalizations.of(context).reorderStops,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 8),
          ],
        ),
        itemCount: items.length,
        onReorderItem: (oldIndex, newIndex) {
          final reordered = List<PlanItem>.of(items);
          final item = reordered.removeAt(oldIndex);
          reordered.insert(newIndex, item);
          final itemIds = reordered
              .map((item) => item.id)
              .toList(growable: false);

          // ReorderableListView invokes this callback while it is resolving the
          // drag layout. The Sembast stream synchronously rebuilds the list, so
          // persisting here would mutate a RenderLayoutBuilder mid-layout.
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!context.mounted) return;
            await ref
                .read(planRepositoryProvider)
                .reorderPlanItems(planId, itemIds);
          });
        },
        itemBuilder: (context, index) =>
            _PlanItemTile(key: ValueKey(items[index].id), item: items[index]),
      );
}

class _PlanItemTile extends ConsumerWidget {
  const _PlanItemTile({super.key, required this.item});

  final PlanItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    child: ListTile(
      leading: Icon(switch (item.type) {
        PlanItemType.savedPlace => Icons.bookmark_outline,
        PlanItemType.note => Icons.sticky_note_2_outlined,
        PlanItemType.customStop => Icons.location_on_outlined,
      }),
      title: Text(item.title),
      subtitle: item.note == null || item.note!.isEmpty
          ? null
          : Text(item.note!, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: IconButton(
        tooltip: AppLocalizations.of(context).removeStop,
        icon: const Icon(Icons.close),
        onPressed: () async {
          await ref.read(planRepositoryProvider).removePlanItem(item.id);
          if (context.mounted) {
            showAppNotice(ref, AppLocalizations.of(context).stopRemoved);
          }
        },
      ),
    ),
  );
}

class _AddPlanStopSheet extends ConsumerWidget {
  const _AddPlanStopSheet({required this.planId});

  final String planId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved =
        ref.watch(savedPlacesProvider).value ?? const <SavedPlaceEntity>[];
    final notes = ref.watch(notesProvider).value ?? const <CityNote>[];

    return SafeArea(
      child: SizedBox(
        height: 460,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Text(
              AppLocalizations.of(context).addStop,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.add_location_alt_outlined),
              title: Text(AppLocalizations.of(context).addCustomStop),
              subtitle: Text(
                AppLocalizations.of(context).customStopDescription,
              ),
              onTap: () => showDialog<void>(
                context: context,
                builder: (_) => _CustomStopDialog(planId: planId),
              ),
            ),
            const Divider(),
            if (saved.isEmpty && notes.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(AppLocalizations.of(context).savePlaceOrIdeaFirst),
              ),
            if (saved.isNotEmpty) ...[
              _SheetSectionTitle(
                title: AppLocalizations.of(context).savedPlaces,
              ),
              ...saved.map(
                (place) => ListTile(
                  leading: const Icon(Icons.bookmark_outline),
                  title: Text(place.title),
                  onTap: () async {
                    await ref
                        .read(planRepositoryProvider)
                        .addSavedPlace(planId, place);
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
              ),
            ],
            if (notes.isNotEmpty) ...[
              _SheetSectionTitle(title: AppLocalizations.of(context).myIdeas),
              ...notes.map(
                (note) => ListTile(
                  leading: const Icon(Icons.sticky_note_2_outlined),
                  title: Text(note.title),
                  subtitle: Text(
                    note.body,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () async {
                    await ref
                        .read(planRepositoryProvider)
                        .addNote(planId, note);
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CustomStopDialog extends ConsumerStatefulWidget {
  const _CustomStopDialog({required this.planId});

  final String planId;

  @override
  ConsumerState<_CustomStopDialog> createState() => _CustomStopDialogState();
}

class _CustomStopDialogState extends ConsumerState<_CustomStopDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();
  var _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(AppLocalizations.of(context).addCustomStop),
    content: Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _titleController,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context).stopName,
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? AppLocalizations.of(context).enterStopName
                : null,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context).optionalNote,
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _isSaving ? null : () => Navigator.pop(context),
        child: Text(AppLocalizations.of(context).cancel),
      ),
      FilledButton(
        onPressed: _isSaving ? null : _save,
        child: Text(
          _isSaving
              ? AppLocalizations.of(context).adding
              : AppLocalizations.of(context).addStop,
        ),
      ),
    ],
  );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    await ref
        .read(planRepositoryProvider)
        .addCustomStop(
          planId: widget.planId,
          title: _titleController.text.trim(),
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
        );
    if (mounted) Navigator.pop(context);
  }
}

class _SheetSectionTitle extends StatelessWidget {
  const _SheetSectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 4),
    child: Text(title, style: Theme.of(context).textTheme.titleMedium),
  );
}

class _PlanUnavailable extends StatelessWidget {
  const _PlanUnavailable();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: Text(AppLocalizations.of(context).planUnavailable),
    ),
  );
}
