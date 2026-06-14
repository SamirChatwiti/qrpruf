import 'dart:convert';

class Proof {
  // ======================
  // Champs privés
  // ======================
  final String _proofId;
  final String _proofVersion;
  final String _status;

  final DateTime _createdAt;
  final DateTime _timestampPrimary;
  final String _timezone;

  final String _subjectId;
  final int _itemsCount;

  final String _hashAlgorithm;
  final String _signatureAlgorithm;
  final String _publicKeyId;
  final String _proofHash;
  final String _signature;

  final String _authMethod;
  final String _confidenceLevel;
  final String _purposeType;
  final List<String> _purposes;
  final String? _selectedType;
  final List<dynamic>? _mediaAssets;

  // ======================
  // Constructeur principal
  // ======================
  Proof({
    required String proofId,
    required String proofVersion,
    required String status,
    required DateTime createdAt,
    required DateTime timestampPrimary,
    required String timezone,
    required String subjectId,
    required int itemsCount,
    required String hashAlgorithm,
    required String signatureAlgorithm,
    required String publicKeyId,
    required String proofHash,
    required String signature,
    required String authMethod,
    required String confidenceLevel,
    required String purposeType,
    required List<String> purposes,
    String? selectedType,
    List<dynamic>? mediaAssets,
  })  : _selectedType = selectedType,
        _mediaAssets = mediaAssets,
        _proofId = proofId,
        _proofVersion = proofVersion,
        _status = status,
        _createdAt = createdAt,
        _timestampPrimary = timestampPrimary,
        _timezone = timezone,
        _subjectId = subjectId,
        _itemsCount = itemsCount,
        _hashAlgorithm = hashAlgorithm,
        _signatureAlgorithm = signatureAlgorithm,
        _publicKeyId = publicKeyId,
        _proofHash = proofHash,
        _signature = signature,
        _authMethod = authMethod,
        _confidenceLevel = confidenceLevel,
        _purposeType = purposeType,
        _purposes = purposes;

  // ======================
  // ✅ FACTORY ATTENDUE PAR L’UI (LOCAL / TEST)
  // ======================
  factory Proof.local({
    required String subjectId,
    required int itemsCount,
    DateTime? timestamp,
  }) {
    final now = DateTime.now().toUtc();

    return Proof(
      proofId: now.microsecondsSinceEpoch.toString(),
      proofVersion: "1.0",
      status: "valid",
      createdAt: now,
      timestampPrimary: timestamp ?? now,
      timezone: "UTC",
      subjectId: subjectId,
      itemsCount: itemsCount,
      hashAlgorithm: "SHA-256",
      signatureAlgorithm: "ECDSA-P256",
      publicKeyId: "qrpruf-key-2026-01",
      proofHash: "",
      signature: "",
      authMethod: "server",
      confidenceLevel: "high",
      purposeType: "general",
      purposes: const ["proof_of_identity"],
    );
  }

  // ======================
  // ✅ FACTORY REMOTE (PROOF OFFICIEL SERVEUR)
  // ======================
  factory Proof.remote({
    required String proofId,
  }) {
    final now = DateTime.now().toUtc();

    return Proof(
      proofId: proofId,
      proofVersion: "1.0",
      status: "valid",
      createdAt: now,
      timestampPrimary: now,
      timezone: "UTC",
      subjectId: "server:$proofId",
      itemsCount: 0,
      hashAlgorithm: "SHA-256",
      signatureAlgorithm: "ECDSA-P256",
      publicKeyId: "qrpruf-key-2026-01",
      proofHash: "",
      signature: "",
      authMethod: "server",
      confidenceLevel: "high",
      purposeType: "general",
      purposes: const ["proof_of_identity"],
    );
  }

  // ======================
  // Getters publics
  // ======================
  String get proofId => _proofId;
  String get proofVersion => _proofVersion;
  String get status => _status;

  DateTime get createdAt => _createdAt;
  DateTime get timestampPrimary => _timestampPrimary;
  String get timezone => _timezone;

  String get subjectId => _subjectId;
  int get itemsCount => _itemsCount;

  String get hashAlgorithm => _hashAlgorithm;
  String get signatureAlgorithm => _signatureAlgorithm;
  String get publicKeyId => _publicKeyId;
  String get proofHash => _proofHash;
  String get signature => _signature;

  String get authMethod => _authMethod;
  String get confidenceLevel => _confidenceLevel;
  String get purposeType => _purposeType;
  List<String> get purposes => _purposes;
  String? get selectedType => _selectedType;
  List<dynamic>? get mediaAssets => _mediaAssets;

  // ======================
  // JSON
  // ======================
  static List<dynamic>? _parseList(dynamic value) {
    if (value is List) return value;
    if (value is String && value.isNotEmpty) {
      try {
        final d = jsonDecode(value);
        if (d is List) return d;
      } catch (_) {}
    }
    return null;
  }

  factory Proof.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now().toUtc();

    String readString(String key, {String fallback = ""}) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        return value;
      }
      return fallback;
    }

    int readInt(String key, {int fallback = 0}) {
      final value = json[key];
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) {
          return parsed;
        }
      }
      return fallback;
    }

    DateTime readDate(String key, {DateTime? fallback}) {
      final value = json[key];
      if (value is String && value.isNotEmpty) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) {
          return parsed.toUtc();
        }
      }
      if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
      }
      return fallback ?? now;
    }

    List<String> readPurposes() {
      final value = json["purposes"];
      if (value is List) {
        final list = value
            .whereType<String>()
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList();
        if (list.isNotEmpty) {
          return list;
        }
      }
      return const ["proof_of_identity"];
    }

    return Proof(
      proofId: readString("proof_id", fallback: now.microsecondsSinceEpoch.toString()),
      proofVersion: readString("proof_version", fallback: "1.0"),
      status: readString("status", fallback: "valid"),
      createdAt: readDate("created_at"),
      timestampPrimary: readDate("timestamp_primary"),
      timezone: readString("timezone", fallback: "UTC"),
      subjectId: readString("subject_id", fallback: "anon"),
      itemsCount: readInt("items_count"),
      hashAlgorithm: readString("hash_algorithm", fallback: "SHA-256"),
      signatureAlgorithm: readString("signature_algorithm", fallback: "ECDSA-P256"),
      publicKeyId: readString("public_key_id", fallback: "qrpruf-key-2026-01"),
      proofHash: readString("proof_hash"),
      signature: readString("signature"),
      authMethod: readString("auth_method", fallback: "server"),
      confidenceLevel: readString("confidence_level", fallback: "high"),
      purposeType: readString("purpose_type", fallback: "general"),
      purposes: readPurposes(),
      selectedType: json['selected_type'] as String?,
      mediaAssets: _parseList(json['media_assets']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'proof_id': _proofId,
      'proof_version': _proofVersion,
      'status': _status,
      'created_at': _createdAt.toIso8601String(),
      'timestamp_primary': _timestampPrimary.toIso8601String(),
      'timezone': _timezone,
      'subject_id': _subjectId,
      'items_count': _itemsCount,
      'hash_algorithm': _hashAlgorithm,
      'signature_algorithm': _signatureAlgorithm,
      'public_key_id': _publicKeyId,
      'proof_hash': _proofHash,
      'signature': _signature,
      'auth_method': _authMethod,
      'confidence_level': _confidenceLevel,
      'purpose_type': _purposeType,
      'purposes': _purposes,
    };
  }

  @override
  String toString() => jsonEncode(toJson());
}
