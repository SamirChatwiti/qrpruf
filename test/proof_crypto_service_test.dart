import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:qrpruf/features/proofs/data/proof_crypto_service.dart';

void main() {
  group('SHA-256 Hashing — determinism & correctness', () {
    test('same content produces identical hash', () {
      final bytes = utf8.encode('preuve judiciaire');
      final h1 = crypto.sha256.convert(bytes).toString();
      final h2 = crypto.sha256.convert(bytes).toString();
      expect(h1, equals(h2));
    });

    test('different content produces different hash', () {
      final h1 = crypto.sha256.convert(utf8.encode('fichier A')).toString();
      final h2 = crypto.sha256.convert(utf8.encode('fichier B')).toString();
      expect(h1, isNot(equals(h2)));
    });

    test('known vector: empty input matches RFC 6234', () {
      const expected =
          'e3b0c44298fc1c149afbf4c8996fb924'
          '27ae41e4649b934ca495991b7852b855';
      expect(crypto.sha256.convert([]).toString(), equals(expected));
    });

    test('hash length is always 64 hex characters (256 bits)', () {
      final hash = crypto.sha256.convert(utf8.encode('qrpruf')).toString();
      expect(hash.length, equals(64));
    });
  });

  group('AES-GCM Encryption — roundtrip integrity', () {
    late encrypt.Key key;
    late encrypt.IV iv;
    late encrypt.Encrypter encrypter;

    setUp(() {
      key = encrypt.Key.fromSecureRandom(32);
      iv = encrypt.IV.fromSecureRandom(12);
      encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.gcm));
    });

    test('encrypt → decrypt returns original bytes', () {
      final original = utf8.encode('contenu confidentiel du procès-verbal');
      final encrypted = encrypter.encryptBytes(original, iv: iv);
      final decrypted = encrypter.decryptBytes(encrypted, iv: iv);
      expect(decrypted, equals(original));
    });

    test('ciphertext is not equal to plaintext', () {
      final plain = utf8.encode('données sensibles');
      final encrypted = encrypter.encryptBytes(plain, iv: iv);
      expect(encrypted.bytes, isNot(equals(plain)));
    });

    test('wrong key fails to decrypt (GCM authentication tag mismatch)', () {
      final wrongKey = encrypt.Key.fromSecureRandom(32);
      final wrongEncrypter =
          encrypt.Encrypter(encrypt.AES(wrongKey, mode: encrypt.AESMode.gcm));
      final encrypted = encrypter.encryptBytes(utf8.encode('secret'), iv: iv);
      expect(
        () => wrongEncrypter.decryptBytes(encrypted, iv: iv),
        throwsA(anything),
      );
    });

    test('different IVs produce different ciphertexts for same plaintext', () {
      final plain = utf8.encode('même contenu');
      final iv2 = encrypt.IV.fromSecureRandom(12);
      final c1 = encrypter.encryptBytes(plain, iv: iv);
      final c2 = encrypter.encryptBytes(plain, iv: iv2);
      expect(c1.bytes, isNot(equals(c2.bytes)));
    });
  });

  group('ProofCryptoService.encryptFile — skipEncryption (hash-only mode)', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('qrpruf_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test('returns correct sha256 for known content', () async {
      final content = utf8.encode('contenu connu pour test unitaire');
      final file = File('${tempDir.path}/sample.jpg')
        ..writeAsBytesSync(content);
      final expectedHash =
          crypto.sha256.convert(content).toString();

      final result = await ProofCryptoService().encryptFile(
        file.path,
        encrypt.Key.fromSecureRandom(32),
        skipEncryption: true,
      );

      expect(result?['sha256'], equals(expectedHash));
      expect(result?['size'], equals(content.length));
    });

    test('throws Exception when file does not exist', () {
      expect(
        () => ProofCryptoService().encryptFile(
          '/nonexistent/path/fichier.jpg',
          encrypt.Key.fromSecureRandom(32),
          skipEncryption: true,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('hash changes when file content changes', () async {
      final key = encrypt.Key.fromSecureRandom(32);
      final f1 = File('${tempDir.path}/v1.jpg')
        ..writeAsBytesSync(utf8.encode('version 1'));
      final f2 = File('${tempDir.path}/v2.jpg')
        ..writeAsBytesSync(utf8.encode('version 2'));

      final r1 =
          await ProofCryptoService().encryptFile(f1.path, key, skipEncryption: true);
      final r2 =
          await ProofCryptoService().encryptFile(f2.path, key, skipEncryption: true);

      expect(r1?['sha256'], isNot(equals(r2?['sha256'])));
    });

    test('same content hashed twice gives same result', () async {
      final content = utf8.encode('idempotence check');
      final file = File('${tempDir.path}/idem.jpg')
        ..writeAsBytesSync(content);
      final key = encrypt.Key.fromSecureRandom(32);

      final r1 =
          await ProofCryptoService().encryptFile(file.path, key, skipEncryption: true);
      final r2 =
          await ProofCryptoService().encryptFile(file.path, key, skipEncryption: true);

      expect(r1?['sha256'], equals(r2?['sha256']));
    });
  });
}
