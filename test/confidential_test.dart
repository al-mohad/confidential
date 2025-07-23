import 'dart:convert';
import 'dart:typed_data';

import 'package:confidential/confidential.dart';
import 'package:confidential/src/configuration/configuration.dart';
import 'package:confidential/src/obfuscation/secret.dart';
import 'package:test/test.dart';

void main() {
  group('Obfuscation Tests', () {
    test('Secret creation and basic operations', () {
      final data = Uint8List.fromList([1, 2, 3, 4, 5]);
      final secret = Secret(data: data, nonce: 12345);

      expect(secret.data, equals(data));
      expect(secret.nonce, equals(12345));
    });

    test('Secret from list creation', () {
      final secret = Secret.fromList([1, 2, 3, 4, 5], 12345);

      expect(secret.data, equals(Uint8List.fromList([1, 2, 3, 4, 5])));
      expect(secret.nonce, equals(12345));
    });

    test('Secret hex conversion', () {
      final secret = Secret.fromHex('deadbeef', 12345);

      expect(secret.data, equals(Uint8List.fromList([0xde, 0xad, 0xbe, 0xef])));
      expect(secret.toHex(), equals('deadbeef'));
    });

    test('Secret equality', () {
      final secret1 = Secret.fromList([1, 2, 3], 123);
      final secret2 = Secret.fromList([1, 2, 3], 123);
      final secret3 = Secret.fromList([1, 2, 4], 123);

      expect(secret1, equals(secret2));
      expect(secret1, isNot(equals(secret3)));
    });
  });

  group('Encryption Tests', () {
    test('AES-GCM encryption/decryption', () {
      final algorithm = const AesGcmEncryption(256);
      final data = Uint8List.fromList(utf8.encode('Hello, World!'));
      final nonce = 12345;

      final encrypted = algorithm.obfuscate(data, nonce);
      final decrypted = algorithm.deobfuscate(encrypted, nonce);

      expect(decrypted, equals(data));
      expect(utf8.decode(decrypted), equals('Hello, World!'));
    });

    test('ChaCha20-Poly1305 encryption/decryption', () {
      final algorithm = const ChaCha20Poly1305Encryption();
      final data = Uint8List.fromList(utf8.encode('Secret message'));
      final nonce = 54321;

      final encrypted = algorithm.obfuscate(data, nonce);
      final decrypted = algorithm.deobfuscate(encrypted, nonce);

      expect(decrypted, equals(data));
      expect(utf8.decode(decrypted), equals('Secret message'));
    });

    test('Encryption is polymorphic', () async {
      final algorithm = const AesGcmEncryption(256);
      final data = Uint8List.fromList(utf8.encode('Test'));
      final nonce = 12345;

      final encrypted1 = algorithm.obfuscate(data, nonce);

      // Small delay to ensure different timestamp
      await Future.delayed(Duration(milliseconds: 1));

      final encrypted2 = algorithm.obfuscate(data, nonce);

      // Different encrypted outputs for same input (polymorphic)
      expect(encrypted1, isNot(equals(encrypted2)));

      // But both decrypt to same result
      final decrypted1 = algorithm.deobfuscate(encrypted1, nonce);
      final decrypted2 = algorithm.deobfuscate(encrypted2, nonce);

      expect(decrypted1, equals(data));
      expect(decrypted2, equals(data));
    });
  });

  group('Compression Tests', () {
    test('Zlib compression/decompression', () {
      final algorithm = const ZlibCompression();
      final data = Uint8List.fromList(
        utf8.encode('This is a test string for compression'),
      );
      final nonce = 12345;

      final compressed = algorithm.obfuscate(data, nonce);
      final decompressed = algorithm.deobfuscate(compressed, nonce);

      expect(decompressed, equals(data));
      expect(
        utf8.decode(decompressed),
        equals('This is a test string for compression'),
      );
    });

    test('GZip compression/decompression', () {
      final algorithm = const GZipCompression();
      final data = Uint8List.fromList(utf8.encode('Another test string'));
      final nonce = 54321;

      final compressed = algorithm.obfuscate(data, nonce);
      final decompressed = algorithm.deobfuscate(compressed, nonce);

      expect(decompressed, equals(data));
      expect(utf8.decode(decompressed), equals('Another test string'));
    });
  });

  group('Randomization Tests', () {
    test('Data shuffling', () {
      final algorithm = const DataShuffler();
      final data = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
      final nonce = 12345;

      final shuffled = algorithm.obfuscate(data, nonce);
      final unshuffled = algorithm.deobfuscate(shuffled, nonce);

      expect(unshuffled, equals(data));
    });

    test('XOR randomization', () {
      final algorithm = const XorRandomization();
      final data = Uint8List.fromList(utf8.encode('XOR test'));
      final nonce = 12345;

      final randomized = algorithm.obfuscate(data, nonce);
      final derandomized = algorithm.deobfuscate(randomized, nonce);

      expect(derandomized, equals(data));
      expect(utf8.decode(derandomized), equals('XOR test'));
    });
  });

  group('Configuration Tests', () {
    test('Parse simple configuration', () {
      const yamlContent = '''
algorithm:
  - encrypt using aes-256-gcm
  - shuffle

secrets:
  - name: testSecret
    value: "test value"
''';

      final config = ConfidentialConfiguration.fromYaml(yamlContent);

      expect(
        config.algorithm,
        equals(['encrypt using aes-256-gcm', 'shuffle']),
      );
      expect(config.secrets.length, equals(1));
      expect(config.secrets.first.name, equals('testSecret'));
      expect(config.secrets.first.value, equals('test value'));
    });

    test('Parse configuration with list values', () {
      const yamlContent = '''
algorithm:
  - compress using zlib

secrets:
  - name: testList
    value:
      - "item1"
      - "item2"
      - "item3"
''';

      final config = ConfidentialConfiguration.fromYaml(yamlContent);

      expect(config.secrets.first.value, equals(['item1', 'item2', 'item3']));
      expect(config.secrets.first.dartType, equals('List<String>'));
    });
  });

  group('Factory Tests', () {
    test('Encryption factory creates correct algorithms', () {
      expect(EncryptionFactory.create('aes-128-gcm'), isA<AesGcmEncryption>());
      expect(EncryptionFactory.create('aes-192-gcm'), isA<AesGcmEncryption>());
      expect(EncryptionFactory.create('aes-256-gcm'), isA<AesGcmEncryption>());
      expect(
        EncryptionFactory.create('chacha20-poly1305'),
        isA<ChaCha20Poly1305Encryption>(),
      );
    });

    test('Compression factory creates correct algorithms', () {
      expect(CompressionFactory.create('zlib'), isA<ZlibCompression>());
      expect(CompressionFactory.create('gzip'), isA<GZipCompression>());
      expect(CompressionFactory.create('bzip2'), isA<BZip2Compression>());
      expect(CompressionFactory.create('lz4'), isA<LZ4Compression>());
    });

    test('Randomization factory creates correct algorithms', () {
      expect(RandomizationFactory.create('shuffle'), isA<DataShuffler>());
      expect(RandomizationFactory.create('xor'), isA<XorRandomization>());
    });
  });
}
