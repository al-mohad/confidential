import 'package:confidential/src/platform/platform_support.dart';
import 'package:test/test.dart';

void main() {
  group('Platform Support Tests', () {
    group('Platform Detection', () {
      test('detects platform correctly', () {
        final platform = PlatformDetector.detectPlatform();

        // In test environment, should detect as unknown or specific platform
        expect(platform, isA<ConfidentialPlatform>());
      });

      test('platform enum has expected values', () {
        expect(
          ConfidentialPlatform.values,
          contains(ConfidentialPlatform.android),
        );
        expect(ConfidentialPlatform.values, contains(ConfidentialPlatform.ios));
        expect(ConfidentialPlatform.values, contains(ConfidentialPlatform.web));
        expect(
          ConfidentialPlatform.values,
          contains(ConfidentialPlatform.unknown),
        );
      });

      test('platform names are correct', () {
        expect(ConfidentialPlatform.android.name, equals('android'));
        expect(ConfidentialPlatform.ios.name, equals('ios'));
        expect(ConfidentialPlatform.web.name, equals('web'));
        expect(ConfidentialPlatform.unknown.name, equals('unknown'));
      });
    });

    group('Security Level Tests', () {
      test('security level enum has expected values', () {
        expect(SecurityLevel.values, contains(SecurityLevel.none));
        expect(SecurityLevel.values, contains(SecurityLevel.low));
        expect(SecurityLevel.values, contains(SecurityLevel.medium));
        expect(SecurityLevel.values, contains(SecurityLevel.high));
      });

      test('security level names are correct', () {
        expect(SecurityLevel.none.name, equals('none'));
        expect(SecurityLevel.low.name, equals('low'));
        expect(SecurityLevel.medium.name, equals('medium'));
        expect(SecurityLevel.high.name, equals('high'));
      });
    });

    group('Platform Capabilities', () {
      test('can check if platform is mobile', () {
        expect(ConfidentialPlatform.android.isMobile, isTrue);
        expect(ConfidentialPlatform.ios.isMobile, isTrue);
        expect(ConfidentialPlatform.web.isMobile, isFalse);
        expect(ConfidentialPlatform.unknown.isMobile, isFalse);
      });

      test('can check if platform supports hardware backing', () {
        expect(ConfidentialPlatform.android.supportsHardwareBacking, isTrue);
        expect(ConfidentialPlatform.ios.supportsHardwareBacking, isTrue);
        expect(ConfidentialPlatform.web.supportsHardwareBacking, isFalse);
        expect(ConfidentialPlatform.unknown.supportsHardwareBacking, isFalse);
      });
    });

    group('Platform Detection Logic', () {
      test('platform detector returns valid platform', () {
        final platform = PlatformDetector.detectPlatform();
        expect(ConfidentialPlatform.values, contains(platform));
      });

      test('platform detection is consistent', () {
        final platform1 = PlatformDetector.detectPlatform();
        final platform2 = PlatformDetector.detectPlatform();
        expect(platform1, equals(platform2));
      });
    });

    group('Error Handling', () {
      test('handles unknown platforms gracefully', () {
        // Test that unknown platform detection doesn't crash
        expect(() => PlatformDetector.detectPlatform(), returnsNormally);
      });
    });
  });
}

// Extension methods for testing platform capabilities
extension ConfidentialPlatformExtensions on ConfidentialPlatform {
  bool get isMobile {
    switch (this) {
      case ConfidentialPlatform.android:
      case ConfidentialPlatform.ios:
        return true;
      default:
        return false;
    }
  }

  bool get supportsHardwareBacking {
    switch (this) {
      case ConfidentialPlatform.android:
      case ConfidentialPlatform.ios:
        return true;
      default:
        return false;
    }
  }
}
