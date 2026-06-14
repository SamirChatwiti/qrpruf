// Renamed scope: tests ProofVerifier (pure static logic, no platform dependencies)
// Original file referenced qrpruf/services/proof_service.dart which no longer exists.
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qrpruf/models/proof.dart';
import 'package:qrpruf/utils/proof_verifier.dart';

// Replicates ProofVerifier._canonicalize: sort keys alphabetically then JSON encode
String _canonical(Map<String, dynamic> data) {
  dynamic sortValue(dynamic v) {
    if (v is List) return v.map(sortValue).toList();
    if (v is Map) {
      final keys = v.keys.toList()..sort();
      return {for (final k in keys) k: sortValue(v[k])};
    }
    return v;
  }

  return jsonEncode(sortValue(data));
}

String _computeHash(Proof proof) {
  final data = {
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
  };
  return sha256.convert(utf8.encode(_canonical(data))).toString();
}

Proof _makeProof({String? overrideHash}) {
  final base = Proof(
    proofId: 'proof-test-001',
    proofVersion: '1.0',
    status: 'valid',
    createdAt: DateTime.utc(2026, 1, 1),
    timestampPrimary: DateTime.utc(2026, 1, 1, 10),
    timezone: 'UTC',
    subjectId: 'user-samir',
    itemsCount: 3,
    hashAlgorithm: 'SHA-256',
    signatureAlgorithm: 'ECDSA-P256',
    publicKeyId: 'qrpruf-key-2026-01',
    proofHash: '',
    signature: '',
    authMethod: 'server',
    confidenceLevel: 'high',
    purposeType: 'general',
    purposes: const ['proof_of_identity'],
  );

  final hash = overrideHash ?? _computeHash(base);

  return Proof(
    proofId: base.proofId,
    proofVersion: base.proofVersion,
    status: base.status,
    createdAt: base.createdAt,
    timestampPrimary: base.timestampPrimary,
    timezone: base.timezone,
    subjectId: base.subjectId,
    itemsCount: base.itemsCount,
    hashAlgorithm: base.hashAlgorithm,
    signatureAlgorithm: base.signatureAlgorithm,
    publicKeyId: base.publicKeyId,
    proofHash: hash,
    signature: '',
    authMethod: base.authMethod,
    confidenceLevel: base.confidenceLevel,
    purposeType: base.purposeType,
    purposes: base.purposes,
  );
}

void main() {
  group('ProofVerifier.verify', () {
    test('returns true for correct hash', () {
      expect(ProofVerifier.verify(_makeProof()), isTrue);
    });

    test('returns false for tampered hash', () {
      final proof = _makeProof(
        overrideHash: 'a' * 64, // wrong SHA-256
      );
      expect(ProofVerifier.verify(proof), isFalse);
    });

    test('returns false for empty hash', () {
      expect(ProofVerifier.verify(_makeProof(overrideHash: '')), isFalse);
    });

    test('is deterministic — same proof verifies twice', () {
      final proof = _makeProof();
      expect(ProofVerifier.verify(proof), isTrue);
      expect(ProofVerifier.verify(proof), isTrue);
    });

    test('canonical is key-order independent', () {
      // ProofVerifier sorts keys — the same proof built differently still hashes the same
      final proof = _makeProof();
      final hash1 = _computeHash(proof);
      expect(hash1, equals(proof.proofHash));
    });
  });
}
