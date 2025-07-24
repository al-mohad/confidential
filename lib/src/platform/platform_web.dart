/// Platform detection implementation for web environments.
library;

import 'platform_support.dart';

/// Detects the platform in web environments (always web).
ConfidentialPlatform detectPlatform() {
  return ConfidentialPlatform.web;
}
