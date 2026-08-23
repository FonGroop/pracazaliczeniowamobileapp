import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:pracazaliczeniowamobileapp/data/models/city_note.dart';
import 'package:pracazaliczeniowamobileapp/data/repositories/note_repository.dart';
import 'package:pracazaliczeniowamobileapp/data/services/attachment_service.dart';
import 'package:pracazaliczeniowamobileapp/data/services/firebase_service.dart';
import 'package:pracazaliczeniowamobileapp/data/services/local_database_service.dart';

void main() {
  test('local attachment does not block Firestore idea sync', () async {
    final local = _MemoryNoteStore();
    final cloud = _MemoryCloudStore();
    final repository = NoteRepository(
      databaseService: local,
      firebaseService: cloud,
      attachmentService: _FakeAttachmentGateway(),
    );
    final note = _noteWithAttachment();

    final result = await repository.saveNote(note);

    expect(result.synced, isTrue);
    expect(cloud.savedNotes, hasLength(1));
    expect(
      cloud.savedNotes.single.toCloudJson(),
      isNot(contains('attachmentName')),
    );
    expect(
      cloud.savedNotes.single.toCloudJson(),
      isNot(contains('attachmentPath')),
    );
    expect(local.notes[note.id]!.syncStatus, NoteSyncStatus.synced);
  });

  test('a local attachment is opened with the platform viewer', () async {
    final local = _MemoryNoteStore();
    final attachments = _FakeAttachmentGateway();
    final repository = NoteRepository(
      databaseService: local,
      firebaseService: _MemoryCloudStore(),
      attachmentService: attachments,
    );
    final note = _noteWithAttachment();

    await repository.openAttachment(note);

    expect(attachments.openedPath, '/local/ticket.pdf');
  });

  test('Firestore refresh preserves the device-only attachment', () async {
    final local = _MemoryNoteStore();
    final localNote = _noteWithAttachment().copyWith(
      syncStatus: NoteSyncStatus.synced,
    );
    await local.saveNote(localNote);
    final cloudNote = CityNote(
      id: localNote.id,
      title: 'Updated museum ticket',
      body: localNote.body,
      latitude: localNote.latitude,
      longitude: localNote.longitude,
      createdAt: localNote.createdAt,
      modifiedAt: DateTime(2026, 2),
      syncStatus: NoteSyncStatus.synced,
    );
    final repository = NoteRepository(
      databaseService: local,
      firebaseService: _MemoryCloudStore(notesToRead: [cloudNote]),
      attachmentService: _FakeAttachmentGateway(),
    );

    await repository.syncFromCloud();

    final merged = local.notes[localNote.id]!;
    expect(merged.title, 'Updated museum ticket');
    expect(merged.attachmentName, 'ticket.pdf');
    expect(merged.attachmentPath, '/local/ticket.pdf');
  });

  test('a stale Apple sandbox path is repaired before opening', () async {
    final appSupport = await Directory.systemTemp.createTemp(
      'city-companion-attachments-',
    );
    addTearDown(() => appSupport.delete(recursive: true));
    final attachmentDirectory = Directory(
      path.join(appSupport.path, 'attachments'),
    );
    await attachmentDirectory.create();
    final currentFile = File(
      path.join(attachmentDirectory.path, 'note-1-1234.png'),
    );
    await currentFile.writeAsBytes(const [1, 2, 3]);
    final service = AttachmentService(
      appSupportDirectory: () async => appSupport,
    );

    final resolved = await service.resolveLocalPath(
      name: 'photo.png',
      localPath:
          '/old/apple/container/Library/Application Support/attachments/'
          'note-1-1234.png',
    );

    expect(resolved, currentFile.path);
  });
}

CityNote _noteWithAttachment() => CityNote(
  id: 'note-1',
  title: 'Museum ticket',
  body: 'Remember the entrance time.',
  latitude: 52.2297,
  longitude: 21.0122,
  createdAt: DateTime(2026),
  attachmentName: 'ticket.pdf',
  attachmentPath: '/local/ticket.pdf',
);

class _MemoryNoteStore implements NoteStore {
  final notes = <String, CityNote>{};
  final pendingDeletes = <String, CityNote>{};

  @override
  Future<void> clearPendingNoteDeletion(String id) async {
    pendingDeletes.remove(id);
  }

  @override
  Future<void> deleteNote(String id) async {
    notes.remove(id);
  }

  @override
  Future<void> queueNoteDeletion(CityNote note) async {
    pendingDeletes[note.id] = note;
  }

  @override
  Future<CityNote?> readNote(String id) async => notes[id];

  @override
  Future<List<CityNote>> readNotes() async => notes.values.toList();

  @override
  Future<List<CityNote>> readPendingNoteDeletions() async =>
      pendingDeletes.values.toList();

  @override
  Future<void> saveNote(CityNote note) async {
    notes[note.id] = note;
  }

  @override
  Stream<List<CityNote>> watchNotes() => Stream.value(notes.values.toList());
}

class _MemoryCloudStore implements NoteCloudStore {
  _MemoryCloudStore({this.notesToRead = const []});

  final List<CityNote> notesToRead;
  final savedNotes = <CityNote>[];

  @override
  Future<void> deleteIdea(CityNote idea) async {}

  @override
  Future<List<CityNote>> readNotes() async => notesToRead;

  @override
  Future<void> saveNote(CityNote note) async {
    savedNotes.add(note);
  }
}

class _FakeAttachmentGateway implements AttachmentGateway {
  String? openedPath;

  @override
  Future<void> delete(String? localPath) async {}

  @override
  Future<void> open(String localPath) async {
    openedPath = localPath;
  }

  @override
  Future<StoredAttachment> persist({
    required XFile source,
    required String noteId,
  }) async => StoredAttachment(name: source.name, localPath: source.path);

  @override
  Future<String> resolveLocalPath({
    required String name,
    String? localPath,
  }) async => localPath!;
}
