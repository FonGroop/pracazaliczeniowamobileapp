import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';

import '../models/city_note.dart';
import '../models/plan_item.dart';
import '../models/saved_place_entity.dart';
import '../models/travel_plan.dart';

abstract interface class SavedPlaceStore {
  Stream<List<SavedPlaceEntity>> watchSavedPlaces();

  Future<void> savePlace({
    required int remoteId,
    required String title,
    required String notes,
    required double latitude,
    required double longitude,
  });

  Future<void> deleteSavedPlace(int remoteId);
}

abstract interface class NoteStore {
  Stream<List<CityNote>> watchNotes();

  Future<void> saveNote(CityNote note);

  Future<List<CityNote>> readNotes();

  Future<CityNote?> readNote(String id);

  Future<void> queueNoteDeletion(CityNote note);

  Future<List<CityNote>> readPendingNoteDeletions();

  Future<void> clearPendingNoteDeletion(String id);

  Future<void> deleteNote(String id);
}

class LocalDatabaseService implements SavedPlaceStore, NoteStore {
  LocalDatabaseService._(this._database);

  static LocalDatabaseService? _instance;
  final Database _database;
  final _savedPlaces = stringMapStoreFactory.store('saved_places');
  final _notes = stringMapStoreFactory.store('city_notes');
  final _plans = stringMapStoreFactory.store('travel_plans');
  final _planItems = stringMapStoreFactory.store('plan_items');
  final _pendingNoteDeletes = stringMapStoreFactory.store(
    'pending_note_deletes',
  );

  static Future<void> bootstrap() async {
    if (_instance != null) return;
    final directory = await getApplicationDocumentsDirectory();
    final database = await databaseFactoryIo.openDatabase(
      path.join(directory.path, 'city_companion.db'),
    );
    _instance = LocalDatabaseService._(database);
  }

  static LocalDatabaseService get instance {
    final service = _instance;
    if (service == null) {
      throw StateError('Local database is not initialized.');
    }
    return service;
  }

  @override
  Stream<List<SavedPlaceEntity>> watchSavedPlaces() => _savedPlaces
      .query(finder: Finder(sortOrders: [SortOrder('savedAt', false)]))
      .onSnapshots(_database)
      .map(
        (records) => records
            .map((record) => SavedPlaceEntity.fromJson(record.value))
            .toList(),
      );

  @override
  Stream<List<CityNote>> watchNotes() => _notes
      .query(finder: Finder(sortOrders: [SortOrder('createdAt', false)]))
      .onSnapshots(_database)
      .map(
        (records) =>
            records.map((record) => CityNote.fromJson(record.value)).toList(),
      );

  Stream<List<TravelPlan>> watchPlans() => _plans
      .query(finder: Finder(sortOrders: [SortOrder('updatedAt', false)]))
      .onSnapshots(_database)
      .map(
        (records) =>
            records.map((record) => TravelPlan.fromJson(record.value)).toList(),
      );

  Stream<TravelPlan?> watchPlan(String id) => _plans
      .record(id)
      .onSnapshot(_database)
      .map(
        (record) => record == null ? null : TravelPlan.fromJson(record.value),
      );

  Stream<List<PlanItem>> watchPlanItems(String planId) => _planItems
      .query(
        finder: Finder(
          filter: Filter.equals('planId', planId),
          sortOrders: [SortOrder('sortOrder')],
        ),
      )
      .onSnapshots(_database)
      .map(
        (records) =>
            records.map((record) => PlanItem.fromJson(record.value)).toList(),
      );

  @override
  Future<void> savePlace({
    required int remoteId,
    required String title,
    required String notes,
    required double latitude,
    required double longitude,
  }) async {
    final place = SavedPlaceEntity(
      remoteId: remoteId,
      title: title,
      notes: notes,
      latitude: latitude,
      longitude: longitude,
      savedAt: DateTime.now(),
    );
    await _savedPlaces.record('$remoteId').put(_database, place.toJson());
  }

  @override
  Future<void> deleteSavedPlace(int remoteId) =>
      _savedPlaces.record('$remoteId').delete(_database);

  Future<void> savePlan(TravelPlan plan) =>
      _plans.record(plan.id).put(_database, plan.toJson());

  Future<List<TravelPlan>> readPlans() async {
    final records = await _plans.find(_database);
    return records.map((record) => TravelPlan.fromJson(record.value)).toList();
  }

  Future<void> savePlanItem(PlanItem item) =>
      _planItems.record(item.id).put(_database, item.toJson());

  Future<List<PlanItem>> readPlanItems(String planId) async {
    final records = await _planItems.find(
      _database,
      finder: Finder(
        filter: Filter.equals('planId', planId),
        sortOrders: [SortOrder('sortOrder')],
      ),
    );
    return records.map((record) => PlanItem.fromJson(record.value)).toList();
  }

  Future<void> deletePlan(String planId) =>
      _database.transaction((transaction) async {
        await _plans.record(planId).delete(transaction);
        await _planItems.delete(
          transaction,
          finder: Finder(filter: Filter.equals('planId', planId)),
        );
      });

  Future<void> deletePlanItem(String itemId) =>
      _planItems.record(itemId).delete(_database);

  @override
  Future<void> saveNote(CityNote note) =>
      _notes.record(note.id).put(_database, note.toJson());

  Future<void> saveNotes(Iterable<CityNote> notes) async {
    await _database.transaction((transaction) async {
      for (final note in notes) {
        await _notes.record(note.id).put(transaction, note.toJson());
      }
    });
  }

  @override
  Future<List<CityNote>> readNotes() async {
    final records = await _notes.find(_database);
    return records.map((record) => CityNote.fromJson(record.value)).toList();
  }

  @override
  Future<CityNote?> readNote(String id) async {
    final value = await _notes.record(id).get(_database);
    return value == null ? null : CityNote.fromJson(value);
  }

  @override
  Future<void> queueNoteDeletion(CityNote note) =>
      _pendingNoteDeletes.record(note.id).put(_database, note.toJson());

  @override
  Future<List<CityNote>> readPendingNoteDeletions() async {
    final records = await _pendingNoteDeletes.find(_database);
    return records.map((record) => CityNote.fromJson(record.value)).toList();
  }

  @override
  Future<void> clearPendingNoteDeletion(String id) =>
      _pendingNoteDeletes.record(id).delete(_database);

  @override
  Future<void> deleteNote(String id) => _notes.record(id).delete(_database);
}
