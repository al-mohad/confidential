/// Compression-based obfuscation implementations.
library;

import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import '../obfuscation.dart';

/// Base class for compression-based obfuscation.
abstract class CompressionAlgorithm extends ObfuscationAlgorithm {
  const CompressionAlgorithm();

  @override
  bool get isPolymorphic => false; // Compression is deterministic, but we add polymorphic masking
}

/// Zlib compression algorithm.
class ZlibCompression extends CompressionAlgorithm {
  const ZlibCompression() : super();
  
  @override
  String get name => 'zlib';
  
  @override
  Uint8List obfuscate(Uint8List data, int nonce) {
    try {
      final compressed = ZLibEncoder().encode(data);
      return _addPolymorphicMask(Uint8List.fromList(compressed), nonce);
    } catch (e) {
      throw ObfuscationException('Zlib compression failed', e);
    }
  }
  
  @override
  Uint8List deobfuscate(Uint8List data, int nonce) {
    try {
      final unmasked = _removePolymorphicMask(data, nonce);
      final decompressed = ZLibDecoder().decodeBytes(unmasked);
      return Uint8List.fromList(decompressed);
    } catch (e) {
      throw ObfuscationException('Zlib decompression failed', e);
    }
  }
}

/// GZip compression algorithm.
class GZipCompression extends CompressionAlgorithm {
  const GZipCompression() : super();
  
  @override
  String get name => 'gzip';
  
  @override
  Uint8List obfuscate(Uint8List data, int nonce) {
    try {
      final compressed = GZipEncoder().encode(data);
      return _addPolymorphicMask(Uint8List.fromList(compressed!), nonce);
    } catch (e) {
      throw ObfuscationException('GZip compression failed', e);
    }
  }
  
  @override
  Uint8List deobfuscate(Uint8List data, int nonce) {
    try {
      final unmasked = _removePolymorphicMask(data, nonce);
      final decompressed = GZipDecoder().decodeBytes(unmasked);
      return Uint8List.fromList(decompressed);
    } catch (e) {
      throw ObfuscationException('GZip decompression failed', e);
    }
  }
}

/// BZip2 compression algorithm.
class BZip2Compression extends CompressionAlgorithm {
  const BZip2Compression() : super();
  
  @override
  String get name => 'bzip2';
  
  @override
  Uint8List obfuscate(Uint8List data, int nonce) {
    try {
      final compressed = BZip2Encoder().encode(data);
      return _addPolymorphicMask(Uint8List.fromList(compressed), nonce);
    } catch (e) {
      throw ObfuscationException('BZip2 compression failed', e);
    }
  }
  
  @override
  Uint8List deobfuscate(Uint8List data, int nonce) {
    try {
      final unmasked = _removePolymorphicMask(data, nonce);
      final decompressed = BZip2Decoder().decodeBytes(unmasked);
      return Uint8List.fromList(decompressed);
    } catch (e) {
      throw ObfuscationException('BZip2 decompression failed', e);
    }
  }
}

/// LZ4 compression algorithm (simplified implementation).
class LZ4Compression extends CompressionAlgorithm {
  const LZ4Compression() : super();
  
  @override
  String get name => 'lz4';
  
  @override
  Uint8List obfuscate(Uint8List data, int nonce) {
    try {
      // For LZ4, we'll use a simple RLE-like compression as a placeholder
      // In a real implementation, you'd use a proper LZ4 library
      final compressed = _simpleLZ4Compress(data);
      return _addPolymorphicMask(compressed, nonce);
    } catch (e) {
      throw ObfuscationException('LZ4 compression failed', e);
    }
  }
  
  @override
  Uint8List deobfuscate(Uint8List data, int nonce) {
    try {
      final unmasked = _removePolymorphicMask(data, nonce);
      final decompressed = _simpleLZ4Decompress(unmasked);
      return decompressed;
    } catch (e) {
      throw ObfuscationException('LZ4 decompression failed', e);
    }
  }
  
  Uint8List _simpleLZ4Compress(Uint8List data) {
    // Simplified compression - just use GZip as placeholder
    return Uint8List.fromList(GZipEncoder().encode(data)!);
  }
  
  Uint8List _simpleLZ4Decompress(Uint8List data) {
    // Simplified decompression - just use GZip as placeholder
    return Uint8List.fromList(GZipDecoder().decodeBytes(data));
  }
}

/// Extension methods for polymorphic masking.
extension _PolymorphicMasking on CompressionAlgorithm {
  /// Adds polymorphic masking to make compression output non-deterministic.
  Uint8List _addPolymorphicMask(Uint8List data, int nonce) {
    final random = Random(nonce);
    final mask = Uint8List(data.length);
    
    for (int i = 0; i < data.length; i++) {
      mask[i] = random.nextInt(256);
    }
    
    final masked = Uint8List(data.length + 4); // 4 bytes for length prefix
    masked.setRange(0, 4, _intToBytes(data.length));
    
    for (int i = 0; i < data.length; i++) {
      masked[i + 4] = data[i] ^ mask[i];
    }
    
    return masked;
  }
  
  /// Removes polymorphic masking to restore original compressed data.
  Uint8List _removePolymorphicMask(Uint8List data, int nonce) {
    final random = Random(nonce);
    final length = _bytesToInt(data.sublist(0, 4));
    final maskedData = data.sublist(4);
    
    final mask = Uint8List(length);
    for (int i = 0; i < length; i++) {
      mask[i] = random.nextInt(256);
    }
    
    final unmasked = Uint8List(length);
    for (int i = 0; i < length; i++) {
      unmasked[i] = maskedData[i] ^ mask[i];
    }
    
    return unmasked;
  }
  
  Uint8List _intToBytes(int value) {
    return Uint8List(4)
      ..[0] = (value >> 24) & 0xFF
      ..[1] = (value >> 16) & 0xFF
      ..[2] = (value >> 8) & 0xFF
      ..[3] = value & 0xFF;
  }
  
  int _bytesToInt(Uint8List bytes) {
    return (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
  }
}

/// Factory for creating compression algorithms.
class CompressionFactory {
  /// Creates a compression algorithm by name.
  static CompressionAlgorithm create(String name) {
    switch (name.toLowerCase()) {
      case 'zlib':
        return const ZlibCompression();
      case 'gzip':
        return const GZipCompression();
      case 'bzip2':
        return const BZip2Compression();
      case 'lz4':
        return const LZ4Compression();
      case 'lzfse':
        // LZFSE is Apple-specific, use GZip as fallback
        return const GZipCompression();
      case 'lzma':
        // LZMA not directly supported in archive package, use BZip2 as fallback
        return const BZip2Compression();
      default:
        throw ObfuscationException('Unknown compression algorithm: $name');
    }
  }
  
  /// Gets all supported compression algorithm names.
  static List<String> get supportedAlgorithms => [
    'zlib',
    'gzip',
    'bzip2',
    'lz4',
    'lzfse', // Fallback to gzip
    'lzma',  // Fallback to bzip2
  ];
}
