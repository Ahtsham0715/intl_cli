import 'dart:io';
import 'package:intl_cli/src/string_extractor.dart';

void main() {
  // Test multiple files
  final files = [
    '/Users/apple/Documents/flutterProjects/intl_cli/test_app/lib/screens/home_screen.dart',
    '/Users/apple/Documents/flutterProjects/intl_cli/test_app/lib/screens/profile_screen.dart',
    '/Users/apple/Documents/flutterProjects/intl_cli/test_app/lib/screens/settings_screen.dart',
  ];
  
  int totalStrings = 0;
  
  for (final filePath in files) {
    final content = File(filePath).readAsStringSync();
    final extractor = StringExtractor(content);
    final strings = extractor.extract();
    totalStrings += strings.length;
    
    print('\nFound ${strings.length} strings in ${filePath.split('/').last}:');
    for (final string in strings) {
      print('- "$string"');
    }
  }
  
  print('\nTotal strings found: $totalStrings');
}
