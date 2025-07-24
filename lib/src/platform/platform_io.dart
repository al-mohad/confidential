/// Platform detection implementation for dart:io environments.
library;

import 'dart:io' show Platform;
import 'platform_support.dart';

/// Detects the platform using dart:io.
ConfidentialPlatform detectPlatform() {
  if (Platform.isAndroid) return ConfidentialPlatform.android;
  if (Platform.isIOS) return ConfidentialPlatform.ios;
  if (Platform.isMacOS) return ConfidentialPlatform.macos;
  if (Platform.isWindows) return ConfidentialPlatform.windows;
  if (Platform.isLinux) return ConfidentialPlatform.linux;
  
  // Default to server for other dart:io environments
  return ConfidentialPlatform.server;
}
