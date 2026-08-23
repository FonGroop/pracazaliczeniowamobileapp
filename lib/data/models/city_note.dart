enum NoteSyncStatus { pending, synced, failed }

class CityNote {
  const CityNote({
    required this.id,
    required this.title,
    required this.body,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
    this.attachmentName,
    this.attachmentPath,
    this.syncStatus = NoteSyncStatus.pending,
    this.modifiedAt,
  });

  final String id;
  final String title;
  final String body;
  final double latitude;
  final double longitude;
  final DateTime createdAt;
  final String? attachmentName;

  /// A private, app-managed copy used while the note is offline.
  final String? attachmentPath;
  final NoteSyncStatus syncStatus;
  final DateTime? modifiedAt;

  DateTime get lastModifiedAt => modifiedAt ?? createdAt;
  bool get hasAttachment => attachmentName != null;
  bool get isSynced => syncStatus == NoteSyncStatus.synced;

  factory CityNote.fromJson(Map<String, dynamic> json) => CityNote(
    id: json['id'] as String,
    title: json['title'] as String,
    body: json['body'] as String,
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    createdAt: DateTime.parse(json['createdAt'] as String),
    attachmentName: json['attachmentName'] as String?,
    attachmentPath: json['attachmentPath'] as String?,
    syncStatus: NoteSyncStatus.values.firstWhere(
      (status) => status.name == json['syncStatus'],
      orElse: () => NoteSyncStatus.pending,
    ),
    modifiedAt: json['modifiedAt'] == null
        ? null
        : DateTime.tryParse(json['modifiedAt'] as String),
  );

  CityNote copyWith({
    String? title,
    String? body,
    double? latitude,
    double? longitude,
    String? attachmentName,
    String? attachmentPath,
    NoteSyncStatus? syncStatus,
    DateTime? modifiedAt,
  }) => CityNote(
    id: id,
    title: title ?? this.title,
    body: body ?? this.body,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    createdAt: createdAt,
    attachmentName: attachmentName ?? this.attachmentName,
    attachmentPath: attachmentPath ?? this.attachmentPath,
    syncStatus: syncStatus ?? this.syncStatus,
    modifiedAt: modifiedAt ?? this.modifiedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'latitude': latitude,
    'longitude': longitude,
    'createdAt': createdAt.toIso8601String(),
    'attachmentName': attachmentName,
    'attachmentPath': attachmentPath,
    'syncStatus': syncStatus.name,
    'modifiedAt': lastModifiedAt.toIso8601String(),
  };

  /// Data safe to send to Firestore. Device file paths never leave the device.
  Map<String, dynamic> toCloudJson() => {
    'id': id,
    'title': title,
    'body': body,
    'latitude': latitude,
    'longitude': longitude,
    'createdAt': createdAt.toIso8601String(),
    'modifiedAt': lastModifiedAt.toIso8601String(),
  };
}
