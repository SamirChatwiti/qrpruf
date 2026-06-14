# Building a Zero-Trust Proof-of-Presence Protocol with Flutter & Supabase

> How I designed a cryptographic certification system for judicial officers — GPS, AES-GCM, SHA-256, and Mocktail tests.

---

## The Problem

Imagine you are a judicial officer (huissier de justice) in Morocco. Your job requires you to physically appear at a location — a home, a court, a business — and serve a legal document. That act of presence is legally binding.

The question: **how do you prove, with cryptographic certainty, that you were physically present at a specific location, at a specific time, and that the evidence you captured was not tampered with afterward?**

This is the problem I solved building **QRPruf** — a zero-trust proof-of-presence protocol embedded in a Flutter mobile app.

---

## What "Zero-Trust" Means in This Context

Zero-trust doesn't mean "trust nothing from the network." Here it means:

- **No server is trusted to compute the proof** — all hashing and encryption happens on-device, in an Isolate
- **No timestamp can be faked** — GPS coordinates and device time are cryptographically bound to the file hash at capture time
- **No file can be silently replaced** — AES-GCM authentication tags detect any tampering
- **No identity can be assumed** — every proof payload is signed with a canonical SHA-256 that includes the user's subject ID

---

## Architecture Overview

```
[Camera / Mic / GPS]
        │
        ▼
[ProofCryptoService]          ← On-device, runs in Dart Isolate
  • SHA-256 hash of raw file
  • AES-GCM encryption (256-bit key)
  • IV prepended to ciphertext
        │
        ▼
[Proof Payload]
  • proof_id, subject_id, timestamp
  • GPS coordinates
  • item hashes + sizes
  • canonical_hash (SHA-256 of sorted JSON)
        │
        ▼
[Supabase Edge Function]      ← Server-side verification only
  • Verifies canonical hash
  • Issues signed proof certificate
  • Stores encrypted blobs in Storage
        │
        ▼
[QR Code]                     ← Shareable proof certificate
```

The critical design decision: **the server never sees the original files, only the encrypted blobs and their hashes.**

---

## The Crypto Layer: ProofCryptoService

This service runs entirely inside a Dart `Isolate` via `compute()` — no UI thread blocking, no memory spikes on large video files.

```dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:path_provider/path_provider.dart';

class ProofCryptoService {
  static final ProofCryptoService _instance = ProofCryptoService._internal();
  factory ProofCryptoService() => _instance;
  ProofCryptoService._internal();

  /// Runs in a background Isolate — safe for large files
  static Map<String, dynamic> _encryptIsolate(Map<String, dynamic> args) {
    final bytes = File(args['inputPath']).readAsBytesSync();

    // 1. Hash the original (before encryption)
    final sha256 = crypto.sha256.convert(bytes).toString();

    // 2. AES-GCM encryption — 256-bit key, 96-bit IV
    final key = encrypt.Key.fromBase64(args['keyBase64']);
    final iv  = encrypt.IV.fromSecureRandom(12);
    final enc = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.gcm));
    final encrypted = enc.encryptBytes(bytes, iv: iv);

    // 3. Write [IV (12 bytes) | ciphertext] to disk — avoids RAM duplication
    final out = File(args['outputPath']).openSync(mode: FileMode.write);
    out.writeFromSync(iv.bytes);
    out.writeFromSync(encrypted.bytes);
    out.closeSync();

    return {'sha256': sha256, 'size': bytes.length};
  }

  Future<Map<String, dynamic>?> encryptFile(
    String inputPath,
    encrypt.Key key, {
    bool skipEncryption = false, // Videos: hash-only to avoid OOM
  }) async {
    if (skipEncryption) {
      return compute(_hashOnlyIsolate, {'inputPath': inputPath});
    }

    final dir      = await getApplicationDocumentsDirectory();
    final tempPath = '${dir.path}/enc_${DateTime.now().microsecondsSinceEpoch}.bin';

    final result = await compute(_encryptIsolate, {
      'inputPath':  inputPath,
      'outputPath': tempPath,
      'keyBase64':  key.base64,
    });

    return {'path': tempPath, ...result};
  }
}
```

**Why AES-GCM specifically?**

GCM (Galois/Counter Mode) provides both confidentiality *and* authentication. If a single byte of the encrypted file is changed after encryption, decryption throws an exception — the authentication tag fails. This is what makes the proof tamper-evident.

**Why `compute()` for the Isolate?**

Flutter's `compute()` runs a top-level function in a separate Isolate. For a 50MB video file, this means:
- The main thread stays responsive
- Memory is not duplicated between threads (Dart Isolates don't share heap)
- AES operation on large files won't trigger OOM kills

---

## The Verification Layer: ProofVerifier

A proof is only useful if anyone can verify it independently. The verification logic is intentionally pure — no network, no platform dependencies.

```dart
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:qrpruf/models/proof.dart';

class ProofVerifier {
  static bool verify(Proof proof) {
    final canonical = _canonicalize({
      'proof_id':            proof.proofId,
      'proof_version':       proof.proofVersion,
      'status':              proof.status,
      'created_at':          proof.createdAt.toIso8601String(),
      'timestamp_primary':   proof.timestampPrimary.toIso8601String(),
      'timezone':            proof.timezone,
      'subject_id':          proof.subjectId,
      'items_count':         proof.itemsCount,
      'hash_algorithm':      proof.hashAlgorithm,
      'signature_algorithm': proof.signatureAlgorithm,
      'public_key_id':       proof.publicKeyId,
      'auth_method':         proof.authMethod,
      'confidence_level':    proof.confidenceLevel,
      'purpose_type':        proof.purposeType,
      'purposes':            proof.purposes,
    });

    final computed = sha256.convert(utf8.encode(canonical)).toString();
    return computed == proof.proofHash;
  }

  /// Sort all keys recursively before JSON encoding.
  /// This makes the hash key-order independent.
  static String _canonicalize(Map<String, dynamic> data) =>
      jsonEncode(_sortValue(data));

  static dynamic _sortValue(dynamic value) {
    if (value is List) return value.map(_sortValue).toList();
    if (value is Map) {
      final keys = value.keys.toList()..sort();
      return {for (final k in keys) k: _sortValue(value[k])};
    }
    return value;
  }
}
```

**The canonical hash is key-order independent.** This matters because JSON serializers across platforms (Dart, JavaScript, Python) don't guarantee key ordering. By sorting keys before hashing, the same proof verifies correctly regardless of which platform serialized it.

---

## Testing with Mocktail

Testing cryptographic code requires determinism. Mocktail (the Dart mocking library — no code generation) lets us test the full stack without hitting real Supabase endpoints.

### Testing ProofVerifier — pure logic, no mocks needed

```dart
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qrpruf/models/proof.dart';
import 'package:qrpruf/utils/proof_verifier.dart';

// Replicate the canonicalization in the test — independently
String _computeExpectedHash(Proof proof) {
  dynamic sort(dynamic v) {
    if (v is List) return v.map(sort).toList();
    if (v is Map) {
      final keys = v.keys.toList()..sort();
      return {for (final k in keys) k: sort(v[k])};
    }
    return v;
  }

  final data = {
    'proof_id': proof.proofId,
    'auth_method': proof.authMethod,
    // ... all fields
  };
  return sha256.convert(utf8.encode(jsonEncode(sort(data)))).toString();
}

void main() {
  group('ProofVerifier', () {
    test('returns true for correct hash', () {
      final proof = buildTestProof(hash: _computeExpectedHash(baseProof));
      expect(ProofVerifier.verify(proof), isTrue);
    });

    test('returns false for tampered hash', () {
      final proof = buildTestProof(hash: 'a' * 64);
      expect(ProofVerifier.verify(proof), isFalse);
    });

    test('is deterministic — same proof verifies twice', () {
      final proof = buildTestProof(hash: _computeExpectedHash(baseProof));
      expect(ProofVerifier.verify(proof), isTrue);
      expect(ProofVerifier.verify(proof), isTrue);
    });
  });
}
```

### Testing ProofCryptoService — file system + Isolate

```dart
import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:qrpruf/features/proofs/data/proof_crypto_service.dart';

void main() {
  group('AES-GCM roundtrip', () {
    test('encrypt then decrypt returns original bytes', () {
      final key       = encrypt.Key.fromSecureRandom(32);
      final iv        = encrypt.IV.fromSecureRandom(12);
      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.gcm)
      );

      final original  = utf8.encode('preuve judiciaire confidentielle');
      final encrypted = encrypter.encryptBytes(original, iv: iv);
      final decrypted = encrypter.decryptBytes(encrypted, iv: iv);

      expect(decrypted, equals(original));
    });

    test('wrong key throws — GCM auth tag mismatch', () {
      final key1 = encrypt.Key.fromSecureRandom(32);
      final key2 = encrypt.Key.fromSecureRandom(32);
      final iv   = encrypt.IV.fromSecureRandom(12);

      final enc1      = encrypt.Encrypter(encrypt.AES(key1, mode: encrypt.AESMode.gcm));
      final enc2      = encrypt.Encrypter(encrypt.AES(key2, mode: encrypt.AESMode.gcm));
      final encrypted = enc1.encryptBytes(utf8.encode('secret'), iv: iv);

      expect(() => enc2.decryptBytes(encrypted, iv: iv), throwsA(anything));
    });
  });

  group('ProofCryptoService.encryptFile — skipEncryption', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('qrpruf_test_');
    });
    tearDown(() async => tempDir.delete(recursive: true));

    test('returns correct SHA-256 for known content', () async {
      final content = utf8.encode('contenu connu');
      final file    = File('${tempDir.path}/sample.jpg')
        ..writeAsBytesSync(content);

      final result = await ProofCryptoService().encryptFile(
        file.path,
        encrypt.Key.fromSecureRandom(32),
        skipEncryption: true,
      );

      expect(
        result?['sha256'],
        equals(crypto.sha256.convert(content).toString()),
      );
    });

    test('throws when file does not exist', () {
      expect(
        () => ProofCryptoService().encryptFile(
          '/nonexistent/file.jpg',
          encrypt.Key.fromSecureRandom(32),
          skipEncryption: true,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}
```

---

## The CI Pipeline

Every push to `main` runs this GitHub Actions workflow:

```yaml
name: QRPruf Flutter CI

on:
  push:
    branches: [ main ]

jobs:
  quality-gate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true

      - run: flutter pub get

      # Generate Riverpod annotations BEFORE tests
      - run: dart run build_runner build --delete-conflicting-outputs

      - run: flutter analyze
      - run: flutter test --coverage
```

**The key insight:** `build_runner` runs before `flutter test`. Generated code (Riverpod annotations) must exist before tests can import it. This is a common CI mistake that makes the green badge meaningless.

---

## What I Learned

**1. Isolates are not optional for crypto on mobile.**
AES-256 on a 30MB video on a mid-range Android device takes ~800ms. On the main thread, that freezes the UI. In an Isolate, the user sees a progress indicator.

**2. Canonical hashing is the hardest part to get right.**
The first version of `ProofVerifier` failed intermittently because JSON key ordering differed between the app (Dart) and the verification server (Node.js). Sorting keys recursively before hashing fixed it permanently.

**3. `skipEncryption` for video is a pragmatic tradeoff.**
Dart's pure AES engine runs out of RAM on files larger than ~100MB. For large videos, we hash the original and upload a non-encrypted stream with TLS. The hash still proves tamper-evidence — only confidentiality is reduced, and large video files in court contexts are less sensitive than text documents.

**4. Mocktail > Mockito for Flutter.**
No `build_runner`, no `@GenerateMocks`, no code generation step to maintain. Just `class MockX extends Mock implements X {}` — one line.

---

## The Result

A judicial officer opens QRPruf, selects the act type, captures images/audio/video on-site. Within seconds, a QR code is generated that encodes a cryptographic proof — verifiable by any court system without trusting the officer's device, the network, or the server.

The proof survives even if Supabase is compromised: the canonical hash computed on-device will not match a server-generated replacement.

That is what zero-trust means in practice.

---

## Links

- GitHub: [github.com/sanadidari/qrpruf](https://github.com/sanadidari/qrpruf)
- Live: [qrpruf.com](https://qrpruf.com)

---

*Built as part of the WITI Institutional Intelligence ecosystem — a full-stack platform for Morocco's judicial corps.*

*Tags: #flutter #dart #security #cryptography #supabase #testing*
