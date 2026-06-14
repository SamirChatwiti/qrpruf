enum MediaType { image, video, audio, text }

class Draft {
  final String id;
  final MediaType type;
  final String originalPath; // Internal use only
  final String transformedPath; // The ONLY path shown to user
  final DateTime timestamp; // Creation (Live) or Upload time
  final List<String>? intentions;
  final String? role; // Role (e.g. 'مساعد مفوض' or 'مفوض قضائي')
  final int durationSeconds; // 0 for images/text, actual duration for video/audio
  bool isCertified;

  Draft({
    required this.id,
    required this.type,
    required this.originalPath,
    required this.transformedPath,
    required this.timestamp,
    this.intentions,
    this.role,
    this.durationSeconds = 0,
    this.isCertified = false,
  });

  Draft copyWith({
    String? id,
    MediaType? type,
    String? originalPath,
    String? transformedPath,
    DateTime? timestamp,
    List<String>? intentions,
    String? role,
    int? durationSeconds,
    bool? isCertified,
  }) {
    return Draft(
      id: id ?? this.id,
      type: type ?? this.type,
      originalPath: originalPath ?? this.originalPath,
      transformedPath: transformedPath ?? this.transformedPath,
      timestamp: timestamp ?? this.timestamp,
      intentions: intentions ?? this.intentions,
      role: role ?? this.role,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      isCertified: isCertified ?? this.isCertified,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.index,
      'originalPath': originalPath,
      'transformedPath': transformedPath,
      'timestamp': timestamp.toIso8601String(),
      'intentions': intentions,
      'role': role,
      'durationSeconds': durationSeconds,
      'isCertified': isCertified,
    };
  }

  factory Draft.fromJson(Map<String, dynamic> json) {
    return Draft(
      id: json['id'] as String,
      type: MediaType.values[json['type'] as int],
      originalPath: json['originalPath'] as String,
      transformedPath: json['transformedPath'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      intentions: (json['intentions'] as List<dynamic>?)?.map((e) => e as String).toList(),
      role: json['role'] as String?,
      durationSeconds: json['durationSeconds'] as int? ?? 0,
      isCertified: json['isCertified'] as bool? ?? false,
    );
  }
}
