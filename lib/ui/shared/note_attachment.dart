import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/models/city_note.dart';
import '../../data/services/attachment_service.dart';
import '../../l10n/app_localizations.dart';

class NoteAttachmentSummary extends StatelessWidget {
  const NoteAttachmentSummary({super.key, required this.note});

  final CityNote note;

  @override
  Widget build(BuildContext context) {
    final name = note.attachmentName;
    if (name == null) return const SizedBox.shrink();
    return Row(
      children: [
        const Icon(Icons.attach_file_outlined, size: 16),
        const SizedBox(width: 4),
        Expanded(
          child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

class NoteAttachmentTile extends ConsumerWidget {
  const NoteAttachmentTile({super.key, required this.note});

  final CityNote note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.attach_file_outlined)),
        title: Text(note.attachmentName ?? l10n.openAttachment),
        subtitle: Text(l10n.attachmentStoredOnDevice),
        trailing: const Icon(Icons.open_in_new),
        onTap: () => openNoteAttachment(context, ref, note),
      ),
    );
  }
}

class NoteAttachmentOpenButton extends ConsumerStatefulWidget {
  const NoteAttachmentOpenButton({super.key, required this.note});

  final CityNote note;

  @override
  ConsumerState<NoteAttachmentOpenButton> createState() =>
      _NoteAttachmentOpenButtonState();
}

class _NoteAttachmentOpenButtonState
    extends ConsumerState<NoteAttachmentOpenButton> {
  var _opening = false;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: AppLocalizations.of(context).openAttachment,
    onPressed: _opening ? null : _open,
    icon: _opening
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.attachment_outlined),
  );

  Future<void> _open() async {
    setState(() => _opening = true);
    await openNoteAttachment(context, ref, widget.note);
    if (mounted) setState(() => _opening = false);
  }
}

Future<void> openNoteAttachment(
  BuildContext context,
  WidgetRef ref,
  CityNote note,
) async {
  try {
    await ref.read(noteRepositoryProvider).openAttachment(note);
  } on Object catch (error) {
    debugPrint('Attachment open failed: $error');
    if (context.mounted) {
      showAppNotice(
        ref,
        error is AttachmentOpenException
            ? error.message
            : AppLocalizations.of(context).attachmentOpenError,
      );
    }
  }
}
