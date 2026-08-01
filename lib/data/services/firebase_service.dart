import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;

import '../models/city_note.dart';

class FirebaseService {
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

  Future<void> saveNote(CityNote note) async {
    final user = await _currentUser();
    await FirebaseFirestore.instance.collection('city_notes').doc(note.id).set({
      ...note.toCloudJson(),
      'ownerId': user.uid,
      'syncedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<CityNote> uploadAttachment(CityNote note) async {
    final localPath = note.attachmentPath;
    if (note.attachmentName == null || localPath == null) return note;

    final file = File(localPath);
    if (!await file.exists()) {
      throw StateError('The local attachment is no longer available.');
    }

    final user = await _currentUser();
    final safeName = path.basename(note.attachmentName!);
    final remotePath = 'city_notes/${user.uid}/${note.id}/$safeName';
    final reference = FirebaseStorage.instance.ref(remotePath);
    await reference.putFile(file);
    final downloadUrl = await reference.getDownloadURL();
    return note.copyWith(
      attachmentRemotePath: remotePath,
      attachmentDownloadUrl: downloadUrl,
    );
  }

  Future<List<CityNote>> readNotes() async {
    final user = await _currentUser();
    final snapshot = await FirebaseFirestore.instance
        .collection('city_notes')
        .where('ownerId', isEqualTo: user.uid)
        .get();
    return snapshot.docs
        .map(
          (document) => CityNote.fromJson({
            ...document.data(),
            // Older app versions could have written a device-only path.
            // Never restore such a path from another device.
            'attachmentPath': null,
            'syncStatus': NoteSyncStatus.synced.name,
          }),
        )
        .toList();
  }

  Future<void> deleteNote(CityNote note) async {
    await _currentUser();
    final remotePath = note.attachmentRemotePath;
    if (remotePath != null) {
      try {
        await FirebaseStorage.instance.ref(remotePath).delete();
      } on FirebaseException catch (error) {
        if (error.code != 'object-not-found') rethrow;
      }
    }
    await FirebaseFirestore.instance
        .collection('city_notes')
        .doc(note.id)
        .delete();
  }

  /// Ideas use the existing cloud collection so previously saved content keeps
  /// working. This removes the Firebase document as well as any old file.
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
        'Cloud access was denied. Check your signed-in user permissions.',
      'failed-precondition' => 'Cloud storage needs to be set up for this app.',
      'unavailable' =>
        'Cloud sync is temporarily unavailable. Check your connection and try again.',
      _ => 'Cloud sync could not complete. Your note is still on this device.',
    };
  }
  return 'Cloud sync could not complete. Your note is still on this device.';
}
