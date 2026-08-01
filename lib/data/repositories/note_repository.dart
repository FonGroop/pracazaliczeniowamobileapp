import '../models/city_note.dart';
import 'package:file_selector/file_selector.dart';
import '../services/attachment_service.dart';
import '../services/firebase_service.dart';
import '../services/local_database_service.dart';

class NoteSaveResult {
  const NoteSaveResult({required this.synced, this.error});

  final bool synced;
  final Object? error;
}

class NoteSyncSummary {
  const NoteSyncSummary({
    required this.uploaded,
    required this.downloaded,
    required this.waitingToSync,
  });

  final int uploaded;
  final int downloaded;
  final int waitingToSync;
}

class NoteRepository {
  NoteRepository({
    required this.databaseService,
    required this.firebaseService,
    required this.attachmentService,
  });

  final LocalDatabaseService databaseService;
  final FirebaseService firebaseService;
  final AttachmentService attachmentService;

  Stream<List<CityNote>> watchNotes() => databaseService.watchNotes();

  Future<StoredAttachment> persistAttachment({
    required XFile source,
    required String noteId,
  }) => attachmentService.persist(source: source, noteId: noteId);

  /// Always persists a note first. A cloud failure leaves it available and
  /// clearly marked for a later retry instead of losing the user's work.
  Future<NoteSaveResult> saveNote(CityNote note) async {
    final pendingNote = note.copyWith(
      syncStatus: NoteSyncStatus.pending,
      modifiedAt: DateTime.now(),
    );
    await databaseService.saveNote(pendingNote);
    try {
      await _syncNote(pendingNote);
      return const NoteSaveResult(synced: true);
    } catch (error) {
      await databaseService.saveNote(
        pendingNote.copyWith(syncStatus: NoteSyncStatus.failed),
      );
      return NoteSaveResult(synced: false, error: error);
    }
  }

  Future<NoteSaveResult> updateNote(CityNote note) =>
      saveNote(note.copyWith(modifiedAt: DateTime.now()));

  Future<NoteSyncSummary> syncFromCloud() async {
    var uploaded = await _syncPendingDeletions();
    var waitingToSync = 0;
    final localNotes = await databaseService.readNotes();

    for (final note in localNotes.where((note) => !note.isSynced)) {
      try {
        await _syncNote(note);
        uploaded++;
      } catch (_) {
        waitingToSync++;
        await databaseService.saveNote(
          note.copyWith(syncStatus: NoteSyncStatus.failed),
        );
      }
    }

    final cloudNotes = await firebaseService.readNotes();
    var downloaded = 0;
    for (final cloudNote in cloudNotes) {
      final localNote = await databaseService.readNote(cloudNote.id);
      final shouldUseCloud =
          localNote == null ||
          localNote.isSynced ||
          cloudNote.lastModifiedAt.isAfter(localNote.lastModifiedAt);
      if (!shouldUseCloud) continue;

      await databaseService.saveNote(
        cloudNote.copyWith(
          attachmentPath: localNote?.attachmentPath,
          syncStatus: NoteSyncStatus.synced,
        ),
      );
      downloaded++;
    }
    return NoteSyncSummary(
      uploaded: uploaded,
      downloaded: downloaded,
      waitingToSync: waitingToSync,
    );
  }

  Future<void> deleteNote(String id) async {
    final note = await databaseService.readNote(id);
    if (note == null) return;
    await databaseService.queueNoteDeletion(note);
    await databaseService.deleteNote(id);
    await attachmentService.delete(note.attachmentPath);
    try {
      await _syncPendingDeletions();
    } catch (_) {
      // The deletion stays queued and will be retried by the next sync.
    }
  }

  /// Deletes the idea locally immediately and queues its Firebase deletion if
  /// the device is offline.
  Future<void> deleteIdea(String id) => deleteNote(id);

  Future<void> _syncNote(CityNote note) async {
    final withAttachment = note.attachmentRemotePath == null
        ? await firebaseService.uploadAttachment(note)
        : note;
    await firebaseService.saveNote(withAttachment);
    await databaseService.saveNote(
      withAttachment.copyWith(syncStatus: NoteSyncStatus.synced),
    );
  }

  Future<int> _syncPendingDeletions() async {
    var deleted = 0;
    for (final note in await databaseService.readPendingNoteDeletions()) {
      try {
        await firebaseService.deleteIdea(note);
        await databaseService.clearPendingNoteDeletion(note.id);
        deleted++;
      } catch (_) {
        // Keep this tombstone until a later cloud sync succeeds.
      }
    }
    return deleted;
  }
}
