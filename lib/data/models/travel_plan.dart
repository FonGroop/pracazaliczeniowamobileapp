enum PlanStatus { draft, upcoming, completed }

/// A dated itinerary. Plans deliberately reference saved places and notes
/// through [PlanItem] instead of owning copies of those records.
class TravelPlan {
  TravelPlan({
    String? id,
    required this.name,
    required this.notes,
    required this.date,
    this.fileName,
    this.status = PlanStatus.draft,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? _newId(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  final String id;
  final String name;
  final String notes;
  final DateTime date;

  /// Retained for compatibility with the original one-form planner. New plan
  /// attachments should be persisted as real files before being exposed again.
  final String? fileName;
  final PlanStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get title => name;
  String get description => notes;

  factory TravelPlan.fromJson(Map<String, dynamic> json) => TravelPlan(
    id: json['id'] as String?,
    name:
        json['name'] as String? ?? json['title'] as String? ?? 'Untitled plan',
    notes: json['notes'] as String? ?? json['description'] as String? ?? '',
    date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
    fileName: json['fileName'] as String?,
    status: PlanStatus.values.firstWhere(
      (status) => status.name == json['status'],
      orElse: () => PlanStatus.draft,
    ),
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    updatedAt:
        DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
  );

  TravelPlan copyWith({
    String? name,
    String? notes,
    DateTime? date,
    String? fileName,
    PlanStatus? status,
    DateTime? updatedAt,
  }) => TravelPlan(
    id: id,
    name: name ?? this.name,
    notes: notes ?? this.notes,
    date: date ?? this.date,
    fileName: fileName ?? this.fileName,
    status: status ?? this.status,
    createdAt: createdAt,
    updatedAt: updatedAt ?? DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'notes': notes,
    'date': date.toIso8601String(),
    'fileName': fileName,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  static String _newId() => 'plan-${DateTime.now().microsecondsSinceEpoch}';
}
