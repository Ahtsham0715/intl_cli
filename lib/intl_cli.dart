library intl_cli;

// Fix the export paths to correctly reference files in the src directory
export 'src/file_scanner.dart';
export 'src/string_extractor.dart';
export 'src/translator.dart';
export 'src/arb_generator.dart';
export 'src/localization_refactorer.dart';
export 'src/utilities.dart';
import 'dart:io';

import 'package:intl_cli/src/arb_generator.dart';
import 'package:intl_cli/src/file_scanner.dart';
import 'package:intl_cli/src/localization_refactorer.dart';
import 'package:intl_cli/src/string_extractor.dart';
import 'package:intl_cli/src/utilities.dart';

/// Scan directory and return a map of files and their translatable strings
Map<String, List<String>> scanDirectory(String directoryPath, {List<String>? excludePatterns}) {
  print('Scanning directory: $directoryPath');
  var directory = Directory(directoryPath);
  if (!directory.existsSync()) {
    throw FileSystemException('Directory does not exist', directoryPath);
  }
  
  // If no exclude patterns provided, try to load from preferences
  if (excludePatterns == null) {
    try {
      final prefs = PreferencesManager.loadPreferences();
      if (prefs.containsKey('excludePatterns')) {
        final patterns = prefs['excludePatterns'];
        if (patterns is List) {
          excludePatterns = patterns.cast<String>();
        }
      }
    } catch (e) {
      // Just use default patterns if preferences can't be loaded
      print('\u001b[33mWarning: Could not load exclude patterns from preferences: $e\u001b[0m');
    }
  }
  
  try {
    var scanner = FileScanner(directory.path);
    var dartFiles = scanner.scan();
    var result = <String, List<String>>{};
    
    print('Found ${dartFiles.length} Dart files.');
    print('Scanning files for translatable strings...');
    int processed = 0;
    
    for (var filePath in dartFiles) {
      processed++;
      if (processed % 10 == 0 || processed == dartFiles.length) {
        print('Processed $processed of ${dartFiles.length} files...');
      }
      
      try {
        var file = File(filePath);
        var content = file.readAsStringSync();
        var extractor = StringExtractor(content, customExcludePatterns: excludePatterns);
        var strings = extractor.extract();
        if (strings.isNotEmpty) {
          result[filePath] = strings;
        }
      } catch (e) {
        print('Error processing file $filePath: $e');
        // Continue with the next file
        continue;
      }
    }
    
    return result;
  } catch (e) {
    throw FileSystemException('Error scanning directory: ${e.toString()}', directoryPath);
  }
}

/// Generate ARB file from extracted strings
String generateArbFile(Map<String, List<String>> extractedStrings, String outputPath, {String keyFormat = 'snake_case'}) {
  var newStrings = <String, String>{};
  for (var entry in extractedStrings.entries) {
    for (var string in entry.value) {
      // Use the string itself as the value, key will be suggested
      newStrings[string] = string;
    }
  }
  ArbGenerator.generateOrMerge(
    newStrings: newStrings,
    filePath: outputPath,
    suggestMeaningfulKeys: true,
    keyFormat: keyFormat,
  );
  return outputPath;
}

/// Refactor code to use localization keys with meaningful key names
Map<String, String> refactorFiles(
  Map<String, List<String>> extractedStrings, {
  bool dryRun = false,
  bool useAppLocalizations = true,
  String packageName = 'app',
  bool preserveOriginalImports = true,
  bool preserveConst = false,
}) {
  var arbData = <String, String>{};
  
  // First, generate meaningful keys from strings
  for (var entry in extractedStrings.entries) {
    for (var string in entry.value) {
      // Create a meaningful key based on the content
      String key = _generateMeaningfulKey(string);
      
      // Make sure key is unique by adding number if needed
      int suffix = 1;
      String baseKey = key;
      while (arbData.containsKey(key)) {
        key = '${baseKey}_$suffix';
        suffix++;
      }
      
      // Store in ARB data map
      arbData[key] = string;
    }
  }
  
  // Now refactor each file with the consistent keys
  for (var entry in extractedStrings.entries) {
    var filePath = entry.key;
    var file = File(filePath);
    
    try {
      print('Processing ${file.path}...');
      var content = file.readAsStringSync();
      var originalContent = content;
      var fileChanged = false;
      
      // Process each string in the file
      for (var string in entry.value) {
        // Find the key that was assigned to this string
        var key = arbData.entries.firstWhere((e) => e.value == string).key;
        
        // Apply the refactoring
        final result = LocalizationRefactorer.refactorWithContext(
          content: content,
          original: string,
          key: key,
          useAppLocalizations: useAppLocalizations,
          dryRun: dryRun,
          preserveConst: preserveConst,
        );
        
        content = result['content'];
        
        // Track if this string caused a change
        if (result['changed'] == true) {
          fileChanged = true;
        }
      }
      
      // Only add import if file was changed and using AppLocalizations
      if (fileChanged && useAppLocalizations && !dryRun) {
        content = LocalizationRefactorer.addLocalizationImport(content, packageName);
      }
      
      if (dryRun) {
        if (fileChanged) {
          print('--- DRY RUN: ${file.path} ---');
          print('Changes would be made to this file.');
        }
      } else if (fileChanged && content != originalContent) {
        file.writeAsStringSync(content);
        print('✅ Updated file: ${file.path}');
      } else {
        print('ℹ️ No changes needed in: ${file.path}');
      }
    } catch (e) {
      print('❌ Error processing ${file.path}: $e');
    }
  }
  
  // Return the ARB data for potential use
  return arbData;
}

/// Generate a meaningful key from a string
String _generateMeaningfulKey(String text) {
  // Convert to lowercase, replace non-alphanumeric with spaces, trim spaces
  var base = text
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
      
  // Take first 5 words max
  var words = base.split(' ').take(5).toList();
  
  // Create camelCase key
  if (words.isEmpty) return 'emptyString';
  
  String key = words[0];
  for (var i = 1; i < words.length; i++) {
    if (words[i].isNotEmpty) {
      key += words[i][0].toUpperCase() + words[i].substring(1);
    }
  }
  
  // Ensure key isn't too long
  if (key.length > 30) {
    key = key.substring(0, 30);
  }
  
  return key;
}
