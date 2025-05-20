library intl_cli;

// Fix the export paths to correctly reference files in the src directory
export 'src/file_scanner.dart';
export 'src/string_extractor.dart';
export 'src/translator.dart';
export 'src/arb_generator.dart';
export 'src/localization_refactorer.dart';
import 'dart:io';

import 'package:intl_cli/src/arb_generator.dart';
import 'package:intl_cli/src/file_scanner.dart';
import 'package:intl_cli/src/localization_refactorer.dart';
import 'package:intl_cli/src/string_extractor.dart';
import 'package:intl_cli/src/translator.dart';

/// Scan directory and return a map of files and their translatable strings
Map<String, List<String>> scanDirectory(String directoryPath) {
  print('Scanning directory: $directoryPath');
  var directory = Directory(directoryPath);
  if (!directory.existsSync()) {
    throw FileSystemException('Directory does not exist', directoryPath);
  }
  
  var scanner = FileScanner(directory.path);
  var dartFiles = scanner.scan();
  var result = <String, List<String>>{};
  
  print('Found ${dartFiles.length} Dart files.');
  for (var filePath in dartFiles) {
    var file = File(filePath);
    var content = file.readAsStringSync();
    var extractor = StringExtractor(content);
    var strings = extractor.extract();
    if (strings.isNotEmpty) {
      result[filePath] = strings;
    }
  }
  
  return result;
}

/// Generate ARB file from extracted strings
String generateArbFile(Map<String, List<String>> extractedStrings, String outputPath) {
  var arbData = <String, String>{};
  var index = 0;
  
  for (var entry in extractedStrings.entries) {
    for (var string in entry.value) {
      var key = 'translation_$index';
      var translated = Translator.translate(string);
      arbData[key] = translated;
      index++;
    }
  }
  
  ArbGenerator.generate(arbData, outputPath);
  return outputPath;
}

/// Refactor code to use localization keys
void refactorFiles(Map<String, List<String>> extractedStrings) {
  // var arbData = <String, String>{};
  var index = 0;
  
  for (var entry in extractedStrings.entries) {
    var filePath = entry.key;
    var file = File(filePath);
    var content = file.readAsStringSync();
    
    for (var string in entry.value) {
      var key = 'translation_$index';
      content = LocalizationRefactorer.refactor(content, string, key);
      index++;
    }
    
    file.writeAsStringSync(content);
    print('Updated file: $filePath');
  }
}
