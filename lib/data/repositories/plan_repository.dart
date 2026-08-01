import '../models/city_note.dart';
import '../models/plan_item.dart';
import '../models/saved_place_entity.dart';
import '../models/travel_plan.dart';
import '../services/local_database_service.dart';
import '../services/preferences_service.dart';

/// The single source of truth for plans and their ordered itinerary items.
class PlanRepository {
  PlanRepository({required this.databaseService});

  final LocalDatabaseService databaseService;

  Stream<List<TravelPlan>> watchPlans() => databaseService.watchPlans();
  Stream<TravelPlan?> watchPlan(String id) => databaseService.watchPlan(id);
  Stream<List<PlanItem>> watchPlanItems(String planId) =>
      databaseService.watchPlanItems(planId);

  Future<void> migrateLegacyPlan(PreferencesService preferences) async {
    final legacyPlan = preferences.lastPlan;
    if (legacyPlan == null) return;

    final existingPlans = await databaseService.readPlans();
    if (existingPlans.isEmpty) {
      await databaseService.savePlan(TravelPlan.fromJson(legacyPlan));
    }
    await preferences.clearLegacyPlan();
  }

  Future<TravelPlan> createPlan({
    required String name,
    required DateTime date,
    String notes = '',
    String? fileName,
  }) async {
    final plan = TravelPlan(
      name: name,
      notes: notes,
      date: date,
      fileName: fileName,
    );
    await databaseService.savePlan(plan);
    return plan;
  }

  Future<void> updatePlan(TravelPlan plan) =>
      databaseService.savePlan(plan.copyWith());

  Future<void> deletePlan(String planId) => databaseService.deletePlan(planId);

  Future<PlanItem> addSavedPlace(String planId, SavedPlaceEntity place) =>
      _addItem(
        planId: planId,
        type: PlanItemType.savedPlace,
        sourceId: '${place.remoteId}',
        title: place.title,
        latitude: place.latitude,
        longitude: place.longitude,
        note: place.notes,
      );

  Future<PlanItem> addNote(String planId, CityNote note) => _addItem(
    planId: planId,
    type: PlanItemType.note,
    sourceId: note.id,
    title: note.title,
    latitude: note.latitude,
    longitude: note.longitude,
    note: note.body,
  );

  Future<PlanItem> addCustomStop({
    required String planId,
    required String title,
    double? latitude,
    double? longitude,
    String? note,
  }) => _addItem(
    planId: planId,
    type: PlanItemType.customStop,
    title: title,
    latitude: latitude,
    longitude: longitude,
    note: note,
  );

  Future<void> updatePlanItem(PlanItem item) =>
      databaseService.savePlanItem(item);

  Future<void> removePlanItem(String itemId) =>
      databaseService.deletePlanItem(itemId);

  Future<void> reorderPlanItems(String planId, List<String> itemIds) async {
    final items = await databaseService.readPlanItems(planId);
    final byId = {for (final item in items) item.id: item};
    for (var index = 0; index < itemIds.length; index++) {
      final item = byId[itemIds[index]];
      if (item != null) {
        await databaseService.savePlanItem(item.copyWith(sortOrder: index));
      }
    }
  }

  Future<PlanItem> _addItem({
    required String planId,
    required PlanItemType type,
    required String title,
    String? sourceId,
    double? latitude,
    double? longitude,
    String? note,
  }) async {
    final item = PlanItem(
      id: 'item-${DateTime.now().microsecondsSinceEpoch}',
      planId: planId,
      type: type,
      sourceId: sourceId,
      title: title,
      latitude: latitude,
      longitude: longitude,
      note: note,
      sortOrder: (await databaseService.readPlanItems(planId)).length,
    );
    await databaseService.savePlanItem(item);
    return item;
  }
}
