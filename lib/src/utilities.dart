import 'dart:io';

// Helper function for displaying progress
void printProgress(String message) {
  stdout.write('\r$message');
}

// Helper function for tr implementation
String tr(String key) {
  // This is where you would implement actual translation lookup
  // For now, just return the key
  return key;
}
