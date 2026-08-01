enum PlanItemType { savedPlace, note, customStop }

/// One ordered stop in a [TravelPlan]. A source id is present for items made
/// from Saved or Notes; custom stops are fully owned by the plan.
class PlanItem {
  const PlanItem({
    required this.id,
    required this.planId,
    required this.type,
    required this.title,
    required this.sortOrder,
    this.sourceId,
    this.latitude,
    this.longitude,
    this.scheduledAt,
    this.durationMinutes,
    this.note,
  });

  final String id;
  final String planId;
  final PlanItemType type;
  final String title;
  final int sortOrder;
  final String? sourceId;
  final double? latitude;
  final double? longitude;
  final DateTime? scheduledAt;
  final int? durationMinutes;
  final String? note;

  factory PlanItem.fromJson(Map<String, dynamic> json) => PlanItem(
    id: json['id'] as String,
    planId: json['planId'] as String,
    type: PlanItemType.values.firstWhere(
      (type) => type.name == json['type'],
      orElse: () => PlanItemType.customStop,
    ),
    title: json['title'] as String,
    sortOrder: (json['sortOrder'] as num).toInt(),
    sourceId: json['sourceId'] as String?,
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
    scheduledAt: json['scheduledAt'] == null
        ? null
        : DateTime.tryParse(json['scheduledAt'] as String),
    durationMinutes: (json['durationMinutes'] as num?)?.toInt(),
    note: json['note'] as String?,
  );

  PlanItem copyWith({
    String? title,
    int? sortOrder,
    DateTime? scheduledAt,
    int? durationMinutes,
    String? note,
  }) => PlanItem(
    id: id,
    planId: planId,
    type: type,
    title: title ?? this.title,
    sortOrder: sortOrder ?? this.sortOrder,
    sourceId: sourceId,
    latitude: latitude,
    longitude: longitude,
    scheduledAt: scheduledAt ?? this.scheduledAt,
    durationMinutes: durationMinutes ?? this.durationMinutes,
    note: note ?? this.note,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'planId': planId,
    'type': type.name,
    'title': title,
    'sortOrder': sortOrder,
    'sourceId': sourceId,
    'latitude': latitude,
    'longitude': longitude,
    'scheduledAt': scheduledAt?.toIso8601String(),
    'durationMinutes': durationMinutes,
    'note': note,
  };
}
