import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../app/providers.dart';
import '../../data/models/city_note.dart';
import '../../l10n/app_localizations.dart';
import '../shared/note_sync_badge.dart';

class NotesScreen extends ConsumerWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(notesProvider);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.myIdeas),
        actions: [
          IconButton(
            tooltip: l10n.syncNow,
            onPressed: () => _syncNotes(context, ref),
            icon: const Icon(Icons.cloud_sync_outlined),
          ),
        ],
      ),
      body: notes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: Text(l10n.ideasError)),
        data: (items) => items.isEmpty
            ? const _NotesEmptyState()
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) => _NoteTile(note: items[index]),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.pushNamed('ideaCreate'),
        icon: const Icon(Icons.add),
        label: Text(l10n.newNote),
      ),
    );
  }

  Future<void> _syncNotes(BuildContext context, WidgetRef ref) async {
    try {
      final summary = await ref.read(noteRepositoryProvider).syncFromCloud();
      if (context.mounted) {
        showAppNotice(
          ref,
          summary.waitingToSync == 0
              ? AppLocalizations.of(context).ideasUpToDate
              : AppLocalizations.of(
                  context,
                ).ideasWaitingToSync(summary.waitingToSync),
        );
      }
    } catch (_) {
      if (context.mounted) {
        showAppNotice(ref, AppLocalizations.of(context).ideasSyncError);
      }
    }
  }
}

class NoteEditorScreen extends ConsumerStatefulWidget {
  const NoteEditorScreen({super.key, this.initialLocation, this.existingNote});

  final LatLng? initialLocation;
  final CityNote? existingNote;

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  XFile? _selectedAttachment;
  var _isSaving = false;

  CityNote? get _existing => widget.existingNote;
  LatLng get _location => _existing == null
      ? widget.initialLocation ?? const LatLng(52.2297, 21.0122)
      : LatLng(_existing!.latitude, _existing!.longitude);

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: _existing?.title ?? '');
    _bodyController = TextEditingController(text: _existing?.body ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_existing == null ? l10n.newNote : l10n.editNote),
        actions: [
          if (_existing != null)
            IconButton(
              tooltip: l10n.deleteNote,
              icon: const Icon(Icons.delete_outline),
              onPressed: _isSaving ? null : _delete,
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  l10n.locationLabel(
                    _location.latitude.toStringAsFixed(4),
                    _location.longitude.toStringAsFixed(4),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: l10n.ideaName,
                    prefixIcon: Icon(Icons.title),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? l10n.ideaNameRequired
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _bodyController,
                  minLines: 4,
                  maxLines: 7,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: l10n.ideaDetails,
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _isSaving ? null : _pickAttachment,
                  icon: const Icon(Icons.attach_file_outlined),
                  label: Text(
                    _selectedAttachment == null &&
                            _existing?.hasAttachment != true
                        ? l10n.chooseAttachment
                        : l10n.changeAttachment,
                  ),
                ),
                if (_selectedAttachment?.name ?? _existing?.attachmentName
                    case final attachmentName?) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.attachment(attachmentName),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_isSaving ? l10n.saving : l10n.saveNote),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickAttachment() async {
    try {
      final selected = await openFile();
      if (selected != null && mounted) {
        setState(() => _selectedAttachment = selected);
      }
    } catch (_) {
      if (mounted) {
        showAppNotice(ref, AppLocalizations.of(context).attachmentPickError);
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final id =
        _existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString();
    try {
      final attachment = _selectedAttachment == null
          ? null
          : await ref
                .read(noteRepositoryProvider)
                .persistAttachment(source: _selectedAttachment!, noteId: id);
      final base =
          _existing ??
          CityNote(
            id: id,
            title: _titleController.text.trim(),
            body: _bodyController.text.trim(),
            latitude: _location.latitude,
            longitude: _location.longitude,
            createdAt: DateTime.now(),
          );
      final note = base.copyWith(
        title: _titleController.text.trim(),
        body: _bodyController.text.trim(),
        attachmentName: attachment?.name,
        attachmentPath: attachment?.localPath,
        clearRemoteAttachment: attachment != null,
        modifiedAt: DateTime.now(),
      );
      final result = _existing == null
          ? await ref.read(noteRepositoryProvider).saveNote(note)
          : await ref.read(noteRepositoryProvider).updateNote(note);
      if (mounted) {
        showAppNotice(
          ref,
          result.synced
              ? AppLocalizations.of(context).ideaSaved
              : AppLocalizations.of(context).ideaSavedDevice,
        );
        context.pop();
      }
    } catch (_) {
      if (mounted) {
        showAppNotice(ref, AppLocalizations.of(context).ideaSaveError);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _delete() async {
    final note = _existing;
    if (note == null) return;
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
    setState(() => _isSaving = true);
    await ref.read(noteRepositoryProvider).deleteIdea(note.id);
    if (mounted) {
      showAppNotice(ref, AppLocalizations.of(context).ideaRemoved);
      context.pop();
    }
  }
}

class _NoteTile extends ConsumerWidget {
  const _NoteTile({required this.note});

  final CityNote note;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    child: ListTile(
      leading: const CircleAvatar(child: Icon(Icons.sticky_note_2_outlined)),
      title: Text(note.title),
      subtitle: Text(note.body, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: NoteSyncBadge(status: note.syncStatus),
      onTap: () => context.pushNamed('ideaEdit', extra: note),
    ),
  );
}

class _NotesEmptyState extends StatelessWidget {
  const _NotesEmptyState();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sticky_note_2_outlined, size: 48),
          SizedBox(height: 12),
          Text(
            AppLocalizations.of(context).ideasStartEmpty,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
