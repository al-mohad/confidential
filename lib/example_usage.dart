// Example usage of dart-confidential
// Generated for flutter project

import 'generated/confidential.dart';

void main() {
  // Access obfuscated secrets
  print('API Key: ${Secrets.apiKey.substring(0, 10)}...');
  print('Database Password: ${Secrets.databasePassword.substring(0, 5)}...');
  
  // Use with platform-aware handling
  final platformAware = Secrets.apiKey.withWebWarnings('apiKey');
  print('Platform-aware access: ${platformAware.value.substring(0, 10)}...');
}
