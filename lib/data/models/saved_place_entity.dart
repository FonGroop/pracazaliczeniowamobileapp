class SavedPlaceEntity {
  SavedPlaceEntity({
    required this.remoteId,
    required this.title,
    required this.notes,
    required this.latitude,
    required this.longitude,
    required this.savedAt,
  });

  final int remoteId;
  final String title;
  final String notes;
  final double latitude;
  final double longitude;
  final DateTime savedAt;

  factory SavedPlaceEntity.fromJson(Map<String, dynamic> json) {
    return SavedPlaceEntity(
      remoteId: (json['remoteId'] as num).toInt(),
      title: json['title'] as String,
      notes: json['notes'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      savedAt: DateTime.parse(json['savedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'remoteId': remoteId,
    'title': title,
    'notes': notes,
    'latitude': latitude,
    'longitude': longitude,
    'savedAt': savedAt.toIso8601String(),
  };
}
