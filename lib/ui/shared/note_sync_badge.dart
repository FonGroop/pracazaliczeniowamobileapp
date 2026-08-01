import 'package:flutter/material.dart';

import '../../data/models/city_note.dart';
import '../../l10n/app_localizations.dart';

class NoteSyncBadge extends StatelessWidget {
  const NoteSyncBadge({super.key, required this.status});

  final NoteSyncStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final (label, icon, color) = switch (status) {
      NoteSyncStatus.synced => (
        l10n.syncStatusSynced,
        Icons.cloud_done_outlined,
        scheme.primary,
      ),
      NoteSyncStatus.pending => (
        l10n.syncStatusWaiting,
        Icons.cloud_upload_outlined,
        scheme.secondary,
      ),
      NoteSyncStatus.failed => (
        l10n.syncStatusWaiting,
        Icons.cloud_off_outlined,
        scheme.error,
      ),
    };
    return Semantics(
      label: label,
      child: Icon(icon, color: color, size: 20),
    );
  }
}
