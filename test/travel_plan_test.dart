import 'package:flutter_test/flutter_test.dart';
import 'package:pracazaliczeniowamobileapp/data/models/plan_item.dart';
import 'package:pracazaliczeniowamobileapp/data/models/travel_plan.dart';

void main() {
  test('reads a legacy single-plan record and writes the new plan fields', () {
    final plan = TravelPlan.fromJson({
      'name': 'Saturday in Warsaw',
      'notes': 'Start by the river',
      'date': '2026-08-01T09:00:00.000',
      'fileName': 'ideas.pdf',
    });

    final json = plan.toJson();
    expect(plan.name, 'Saturday in Warsaw');
    expect(plan.status, PlanStatus.draft);
    expect(json['id'], startsWith('plan-'));
    expect(json['createdAt'], isNotEmpty);
    expect(json['updatedAt'], isNotEmpty);
  });

  test('keeps an itinerary item linked to its saved-place source', () {
    const item = PlanItem(
      id: 'item-1',
      planId: 'plan-1',
      type: PlanItemType.savedPlace,
      sourceId: '42',
      title: 'Old Town walk',
      latitude: 52.2497,
      longitude: 21.0122,
      sortOrder: 0,
    );

    final restored = PlanItem.fromJson(item.toJson());
    expect(restored.type, PlanItemType.savedPlace);
    expect(restored.sourceId, '42');
    expect(restored.latitude, 52.2497);
    expect(restored.sortOrder, 0);
  });
}
