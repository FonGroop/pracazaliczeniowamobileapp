import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/city_note.dart';

abstract interface class NoteCloudStore {
  Future<void> saveNote(CityNote note);

  Future<List<CityNote>> readNotes();

  Future<void> deleteIdea(CityNote idea);
}

class FirebaseService implements NoteCloudStore {
  bool get isReady => Firebase.apps.isNotEmpty;

  Future<User> _currentUser() async {
    if (!isReady) {
      throw StateError('Firebase is not available on this platform.');
    }
    final current = FirebaseAuth.instance.currentUser;
    if (current != null) {
      return current;
    }
    final credential = await FirebaseAuth.instance.signInAnonymously();
    final user = credential.user;
    if (user == null) {
      throw StateError('Anonymous Firebase sign-in did not return a user.');
    }
    return user;
  }

  @override
  Future<void> saveNote(CityNote note) async {
    final user = await _currentUser();
    await FirebaseFirestore.instance.collection('city_notes').doc(note.id).set({
      ...note.toCloudJson(),
      'ownerId': user.uid,
      'syncedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<List<CityNote>> readNotes() async {
    final user = await _currentUser();
    final snapshot = await FirebaseFirestore.instance
        .collection('city_notes')
        .where('ownerId', isEqualTo: user.uid)
        .get();
    return snapshot.docs.map((document) {
      return CityNote.fromJson({
        ...document.data(),
        // Attachments deliberately stay private to the device.
        'attachmentName': null,
        'attachmentPath': null,
        'syncStatus': NoteSyncStatus.synced.name,
      });
    }).toList();
  }

  Future<void> deleteNote(CityNote note) async {
    await _currentUser();
    await FirebaseFirestore.instance
        .collection('city_notes')
        .doc(note.id)
        .delete();
  }

  /// Ideas use the existing cloud collection so previously saved content keeps
  /// working. Their device-only attachment is removed by the local repository.
  @override
  Future<void> deleteIdea(CityNote idea) => deleteNote(idea);
}

String cloudUserMessage(Object error) {
  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'operation-not-allowed' => 'Cloud sign-in has not been enabled yet.',
      'network-request-failed' => 'Cloud sync could not reach the network.',
      'internal-error' =>
        'Cloud sign-in needs attention. ${error.message ?? ''}',
      _ => 'Cloud sign-in needs attention.',
    };
  }
  if (error is FirebaseException) {
    return switch (error.code) {
      'permission-denied' =>
        'Cloud access was denied. Check your Firestore security rules.',
      'unavailable' =>
        'Cloud sync is temporarily unavailable. Check your connection and try again.',
      _ => 'Cloud sync could not complete. Your note is still on this device.',
    };
  }
  return 'Cloud sync could not complete. Your note is still on this device.';
}
