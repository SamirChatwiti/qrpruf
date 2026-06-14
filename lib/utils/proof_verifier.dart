import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:qrpruf/models/proof.dart';

class ProofVerifier {
  /// Recalcule le hash canonique et le compare
  static bool verify(Proof proof) {
    final canonical = _canonicalize({
      'proof_id': proof.proofId,
      'proof_version': proof.proofVersion,
      'status': proof.status,
      'created_at': proof.createdAt.toIso8601String(),
      'timestamp_primary': proof.timestampPrimary.toIso8601String(),
      'timezone': proof.timezone,
      'subject_id': proof.subjectId,
      'items_count': proof.itemsCount,
      'hash_algorithm': proof.hashAlgorithm,
      'signature_algorithm': proof.signatureAlgorithm,
      'public_key_id': proof.publicKeyId,
      'auth_method': proof.authMethod,
      'confidence_level': proof.confidenceLevel,
      'purpose_type': proof.purposeType,
      'purposes': proof.purposes,
    });

    final hash = sha256.convert(utf8.encode(canonical)).toString();
    return hash == proof.proofHash;
  }

  static String _canonicalize(Map<String, dynamic> data) {
    return jsonEncode(_sortValue(data));
  }

  static dynamic _sortValue(dynamic value) {
    if (value is List) {
      return value.map(_sortValue).toList();
    }
    if (value is Map) {
      final sortedKeys = value.keys.toList()..sort();
      return {
        for (final key in sortedKeys) key: _sortValue(value[key]),
      };
    }
    return value;
  }
}
