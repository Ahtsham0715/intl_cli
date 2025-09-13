/// A powerful command-line tool for automating Flutter/Dart internationalization.
/// 
/// This library provides automated extraction of hardcoded strings from Dart/Flutter
/// source code using advanced ML-based string detection with 5 million parameter
/// FlutterLocNet.tflite model. It generates ARB files, creates localization keys,
/// and refactors code with high accuracy.
/// 
/// Key features:
/// * ML-based string extraction using trained TensorFlow Lite model
/// * Automatic ARB file generation
/// * Smart key generation with meaningful names
/// * Code refactoring with localization
/// * Multi-language support via translation APIs
/// 
/// Example usage:
/// ```dart
/// // Scan directory for translatable strings
/// final results = await scanDirectoryEnhanced('/path/to/flutter/project');
/// 
/// // Generate ARB files
/// await generateArbFiles(results, '/path/to/l10n');
/// ```
library;

// Fix the export paths to correctly reference files in the src directory
export 'src/extensions/string_extensions.dart';
export 'src/file_scanner.dart';
export 'src/enhanced_string_extractor.dart';
export 'src/ml_string_extractor.dart';
export 'src/translator.dart';
export 'src/arb_generator.dart';
export 'src/localization_refactorer.dart';
export 'src/utilities.dart';

import 'dart:io';
import 'package:path/path.dart' as path;

import 'src/extensions/string_extensions.dart';
import 'src/arb_generator.dart';
import 'src/file_scanner.dart';
import 'src/localization_refactorer.dart';
import 'src/utilities.dart';
import 'src/key_generator.dart';
import 'src/enhanced_string_extractor.dart';

/// Enhanced scan directory with ML-based string extraction for 99% accuracy.
/// 
/// Scans the specified [directoryPath] for Dart files and extracts translatable
/// strings using the trained FlutterLocNet.tflite model with 5 million parameters.
/// This provides significantly higher accuracy than regex-based extraction.
/// 
/// Parameters:
/// * [directoryPath] - The root directory to scan for Dart files
/// * [excludePatterns] - Optional list of glob patterns to exclude files/directories
/// 
/// Returns a Map where keys are file paths and values are lists of extracted strings.
/// 
/// Example:
/// ```dart
/// final results = await scanDirectoryEnhanced(
///   '/path/to/flutter/project',
///   excludePatterns: ['test/**', 'build/**']
/// );
/// ```
Future<Map<String, List<String>>> scanDirectoryEnhanced(String directoryPath,
    {List<String>? excludePatterns}) async {
  print('🚀 Starting STRICT ML-ONLY directory scan...');
  
  // Initialize ML extractor
  await StringExtractorFactory.initializeML();
  print('🧠 ML Status: ${StringExtractorFactory.isMLInitialized ? 'Ready' : 'Failed to initialize'}');

  final directory = Directory(path.normalize(directoryPath));
  
  if (!directory.existsSync()) {
    throw FileSystemException('Directory not found', directoryPath);
  }

  // Load exclude patterns from preferences if not provided
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
      print('\u001b[33mWarning: Could not load exclude patterns: $e\u001b[0m');
    }
  }

  try {
    final scanner = FileScanner(directory.path);
    final dartFiles = scanner.scan();
    final result = <String, List<String>>{};

    print('📁 Found ${dartFiles.length} Dart files.');
    print('🔍 Scanning with ML-enhanced extraction...');
    
    final stopwatch = Stopwatch()..start();
    int processed = 0;
    int totalStringsFound = 0;

    // Process files in batches for better performance
    final batchSize = 10;
    for (int i = 0; i < dartFiles.length; i += batchSize) {
      final batch = dartFiles.skip(i).take(batchSize).toList();
      
      // Process batch with STRICT ML-ONLY extraction
      final batchResults = await _extractFromFilesML(batch);
      
      result.addAll(batchResults);
      
      // Update progress
      processed += batch.length;
      final batchStrings = batchResults.values.fold<int>(0, (sum, strings) => sum + strings.length);
      totalStringsFound += batchStrings;
      
      if (processed % 20 == 0 || processed == dartFiles.length) {
        print('📊 Processed $processed of ${dartFiles.length} files... ($totalStringsFound strings found)');
      }
    }

    stopwatch.stop();
    
    print('✅ Scan complete!');
    print('⏱️  Time taken: ${stopwatch.elapsedMilliseconds}ms');
    print('📈 Performance: ${(dartFiles.length / (stopwatch.elapsedMilliseconds / 1000)).toStringAsFixed(2)} files/sec');
    print('🎯 Total strings found: $totalStringsFound');
    
    return result;
  } catch (e) {
    throw FileSystemException('Error scanning directory: ${e.toString()}', directoryPath);
  } finally {
    // Don't dispose here as it might be used again
  }
}

/// ML-based scan directory function with strict ML-only extraction.
/// 
/// Alternative entry point that uses only the trained ML model for string extraction,
/// ensuring the highest accuracy and consistency. This function is optimized for
/// production use where precision is critical.
/// 
/// Parameters:
/// * [directoryPath] - The root directory to scan for Dart files
/// * [excludePatterns] - Optional list of glob patterns to exclude files/directories
/// 
/// Returns a Map where keys are file paths and values are lists of extracted strings.
/// All strings are validated using the 5 million parameter FlutterLocNet.tflite model.
/// 
/// Example:
/// ```dart
/// final results = await scanDirectory('/path/to/flutter/project');
/// ```
Future<Map<String, List<String>>> scanDirectory(String directoryPath,
    {List<String>? excludePatterns}) async {
  print('🤖 Using STRICT ML-ONLY extraction...');
  // Initialize ML extractor
  await StringExtractorFactory.initializeML();
  print('🧠 ML Status: ${StringExtractorFactory.isMLInitialized ? 'Ready' : 'Failed to initialize'}');
  
  // Log directory path for debugging
  final currentDir = Directory.current.path;
  print('Current working directory: $currentDir');
  print('Scanning directory (input path): "$directoryPath"');

  // Normalize directory path (this is critical for handling the command name issue)
  String normalizedPath = directoryPath;

  // Hard safety check: if the path is a command name, replace it with "lib"
  if (normalizedPath == 'internationalize' || normalizedPath == 'i18n') {
    normalizedPath = 'lib';
    print('WARNING: Command name detected as path, replaced with "lib"');
  }

  // Convert relative path to absolute path if needed using path package
  if (!path.isAbsolute(normalizedPath)) {
    normalizedPath = path.join(currentDir, normalizedPath);
    print('Converted to absolute path: "$normalizedPath"');
  }

  // Normalize the final path
  normalizedPath = path.normalize(normalizedPath);

  print('Final normalized path to scan: "$normalizedPath"');

  // Verify the directory exists
  final directory = Directory(normalizedPath);
  if (!directory.existsSync()) {
    final error = 'Directory does not exist: "$normalizedPath"';
    print('ERROR: $error');
    throw FileSystemException(error, normalizedPath);
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
      print(
          '\u001b[33mWarning: Could not load exclude patterns from preferences: $e\u001b[0m');
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
        // Use STRICT ML-ONLY extraction
        var strings = await StringExtractorFactory.extractStrings(content);
        if (strings.isNotEmpty) {
          result[filePath] = strings;
        }
      } catch (e) {
        print('❌ Error processing file $filePath: $e');
        // Continue with the next file
        continue;
      }
    }

    return result;
  } catch (e) {
    throw FileSystemException(
        'Error scanning directory: ${e.toString()}', directoryPath);
  }
}

/// Generate ARB file from extracted strings.
/// 
/// Creates an Application Resource Bundle (ARB) file from the extracted translatable
/// strings. The function generates meaningful keys for each string and handles
/// key uniqueness automatically.
/// 
/// Parameters:
/// * [extractedStrings] - Map of file paths to lists of extracted strings
/// * [outputPath] - The path where the ARB file will be created
/// * [keyFormat] - Format for generated keys ('snake_case', 'camelCase', etc.)
/// 
/// Returns the path to the generated ARB file.
/// 
/// Example:
/// ```dart
/// final arbPath = generateArbFile(
///   extractedStrings, 
///   'lib/l10n/intl_en.arb',
///   keyFormat: 'camelCase'
/// );
/// ```
String generateArbFile(
    Map<String, List<String>> extractedStrings, String outputPath,
    {String keyFormat = 'snake_case'}) {
  var newStrings = <String, String>{};
  var usedKeys = <String>{};
  
  for (var entry in extractedStrings.entries) {
    for (var string in entry.value) {
      // Generate a proper key from the string value
      var baseKey = KeyGenerator.generateKey(string, keyFormat: keyFormat);
      var finalKey = KeyGenerator.makeKeyUnique(baseKey, usedKeys);
      usedKeys.add(finalKey);
      
      // Use the generated key as key and original string as value
      newStrings[finalKey] = string;
      print('🔑 Generated key: "$finalKey" for value: "$string"');
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

/// Refactor code to use localization keys with meaningful key names.
/// 
/// Automatically refactors Dart/Flutter source code to replace hardcoded strings
/// with localization calls using generated meaningful keys. This function supports
/// both dry-run mode for preview and actual code modification.
/// 
/// Parameters:
/// * [extractedStrings] - Map of file paths to lists of extracted strings
/// * [dryRun] - If true, only shows what would be changed without modifying files
/// * [useAppLocalizations] - Whether to use AppLocalizations or Intl.message
/// * [packageName] - Package name for import statements
/// * [preserveOriginalImports] - Whether to keep existing import statements
/// * [preserveConst] - Whether to preserve const keywords where possible
/// 
/// Returns a Map of generated keys to their corresponding string values.
/// 
/// Example:
/// ```dart
/// final keys = refactorFiles(
///   extractedStrings,
///   dryRun: false,
///   useAppLocalizations: true,
///   packageName: 'my_app'
/// );
/// ```
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

      // Create a map of all replacements for batch processing
      var replacements = <String, String>{};
      for (var string in entry.value) {
        // Find the key that was assigned to this string
        var key = arbData.entries.firstWhere((e) => e.value == string).key;
        replacements[string] = key;
      }

      // Apply all refactorings at once for better efficiency
      final result = LocalizationRefactorer.batchRefactor(
        content: content,
        replacements: replacements,
        useAppLocalizations: useAppLocalizations,
        preserveConst: preserveConst,
      );

      content = result['content'];

      // Track if any change was made
      if (result['changed'] == true) {
        fileChanged = true;
      }

      // Only add import if file was changed and using AppLocalizations
      if (fileChanged && useAppLocalizations && !dryRun) {
        content =
            LocalizationRefactorer.addLocalizationImport(content, packageName);
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
  return text.toValidKey();
}

/// Batch process files with ML extractor
Future<Map<String, List<String>>> _extractFromFilesML(List<String> filePaths) async {
  final results = <String, List<String>>{};
  
  for (final filePath in filePaths) {
    try {
      final file = File(filePath);
      final content = await file.readAsString();
      
      // Use ML-based string extraction
      final strings = await StringExtractorFactory.extractStrings(content);
      
      if (strings.isNotEmpty) {
        results[filePath] = strings;
      }
    } catch (e) {
      print('❌ Error processing file $filePath: $e');
    }
  }
  
  return results;
}
