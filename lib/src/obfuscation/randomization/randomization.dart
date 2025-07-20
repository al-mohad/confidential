/// Randomization-based obfuscation implementations.
library;

import 'dart:typed_data';
import 'dart:math';
import '../obfuscation.dart';

/// Base class for randomization-based obfuscation.
abstract class RandomizationAlgorithm extends ObfuscationAlgorithm {
  const RandomizationAlgorithm();

  @override
  bool get isPolymorphic => true;
}

/// Data shuffling algorithm.
class DataShuffler extends RandomizationAlgorithm {
  const DataShuffler() : super();
  
  @override
  String get name => 'shuffle';
  
  @override
  Uint8List obfuscate(Uint8List data, int nonce) {
    try {
      if (data.isEmpty) return data;
      
      final random = Random(nonce);
      final indices = List.generate(data.length, (i) => i);
      
      // Fisher-Yates shuffle
      for (int i = indices.length - 1; i > 0; i--) {
        final j = random.nextInt(i + 1);
        final temp = indices[i];
        indices[i] = indices[j];
        indices[j] = temp;
      }
      
      // Create shuffled data with index map
      final shuffled = Uint8List(data.length);
      for (int i = 0; i < data.length; i++) {
        shuffled[i] = data[indices[i]];
      }
      
      // Encode the shuffle pattern and data
      return _encodeShuffledData(shuffled, indices, nonce);
    } catch (e) {
      throw ObfuscationException('Data shuffling failed', e);
    }
  }
  
  @override
  Uint8List deobfuscate(Uint8List data, int nonce) {
    try {
      if (data.isEmpty) return data;
      
      // Decode the shuffle pattern and data
      final decoded = _decodeShuffledData(data, nonce);
      final shuffledData = decoded.data;
      final indices = decoded.indices;
      
      // Restore original order
      final restored = Uint8List(shuffledData.length);
      for (int i = 0; i < shuffledData.length; i++) {
        restored[indices[i]] = shuffledData[i];
      }
      
      return restored;
    } catch (e) {
      throw ObfuscationException('Data unshuffling failed', e);
    }
  }
  
  /// Encodes shuffled data with its index pattern.
  Uint8List _encodeShuffledData(Uint8List shuffledData, List<int> indices, int nonce) {
    final dataLength = shuffledData.length;
    
    if (dataLength <= 256) {
      // For small data, store indices as bytes
      final encoded = Uint8List(4 + 1 + dataLength + dataLength);
      encoded.setRange(0, 4, _intToBytes(dataLength));
      encoded[4] = 1; // Format indicator: 1 = byte indices
      encoded.setRange(5, 5 + dataLength, shuffledData);
      
      for (int i = 0; i < dataLength; i++) {
        encoded[5 + dataLength + i] = indices[i];
      }
      
      return encoded;
    } else if (dataLength <= 65536) {
      // For medium data, store indices as 16-bit values
      final encoded = Uint8List(4 + 1 + dataLength + (dataLength * 2));
      encoded.setRange(0, 4, _intToBytes(dataLength));
      encoded[4] = 2; // Format indicator: 2 = 16-bit indices
      encoded.setRange(5, 5 + dataLength, shuffledData);
      
      for (int i = 0; i < dataLength; i++) {
        final index = indices[i];
        encoded[5 + dataLength + (i * 2)] = (index >> 8) & 0xFF;
        encoded[5 + dataLength + (i * 2) + 1] = index & 0xFF;
      }
      
      return encoded;
    } else {
      // For large data, store indices as 32-bit values
      final encoded = Uint8List(4 + 1 + dataLength + (dataLength * 4));
      encoded.setRange(0, 4, _intToBytes(dataLength));
      encoded[4] = 4; // Format indicator: 4 = 32-bit indices
      encoded.setRange(5, 5 + dataLength, shuffledData);
      
      for (int i = 0; i < dataLength; i++) {
        final indexBytes = _intToBytes(indices[i]);
        encoded.setRange(5 + dataLength + (i * 4), 5 + dataLength + (i * 4) + 4, indexBytes);
      }
      
      return encoded;
    }
  }
  
  /// Decodes shuffled data and its index pattern.
  ({Uint8List data, List<int> indices}) _decodeShuffledData(Uint8List encoded, int nonce) {
    final dataLength = _bytesToInt(encoded.sublist(0, 4));
    final format = encoded[4];
    final shuffledData = encoded.sublist(5, 5 + dataLength);
    
    final indices = <int>[];
    
    switch (format) {
      case 1: // Byte indices
        for (int i = 0; i < dataLength; i++) {
          indices.add(encoded[5 + dataLength + i]);
        }
        break;
      case 2: // 16-bit indices
        for (int i = 0; i < dataLength; i++) {
          final high = encoded[5 + dataLength + (i * 2)];
          final low = encoded[5 + dataLength + (i * 2) + 1];
          indices.add((high << 8) | low);
        }
        break;
      case 4: // 32-bit indices
        for (int i = 0; i < dataLength; i++) {
          final indexBytes = encoded.sublist(5 + dataLength + (i * 4), 5 + dataLength + (i * 4) + 4);
          indices.add(_bytesToInt(indexBytes));
        }
        break;
      default:
        throw ObfuscationException('Unknown shuffle format: $format');
    }
    
    return (data: shuffledData, indices: indices);
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

/// XOR-based randomization algorithm.
class XorRandomization extends RandomizationAlgorithm {
  const XorRandomization() : super();
  
  @override
  String get name => 'xor';
  
  @override
  Uint8List obfuscate(Uint8List data, int nonce) {
    try {
      final random = Random(nonce);
      final result = Uint8List(data.length);
      
      for (int i = 0; i < data.length; i++) {
        final mask = random.nextInt(256);
        result[i] = data[i] ^ mask;
      }
      
      return result;
    } catch (e) {
      throw ObfuscationException('XOR randomization failed', e);
    }
  }
  
  @override
  Uint8List deobfuscate(Uint8List data, int nonce) {
    // XOR is symmetric, so deobfuscation is the same as obfuscation
    return obfuscate(data, nonce);
  }
}

/// Factory for creating randomization algorithms.
class RandomizationFactory {
  /// Creates a randomization algorithm by name.
  static RandomizationAlgorithm create(String name) {
    switch (name.toLowerCase()) {
      case 'shuffle':
        return const DataShuffler();
      case 'xor':
        return const XorRandomization();
      default:
        throw ObfuscationException('Unknown randomization algorithm: $name');
    }
  }
  
  /// Gets all supported randomization algorithm names.
  static List<String> get supportedAlgorithms => [
    'shuffle',
    'xor',
  ];
}
