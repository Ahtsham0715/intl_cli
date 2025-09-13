import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

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

/// Class to manage user preferences for the CLI tool
class PreferencesManager {
  static const String _prefsFileName = '.intl_cli_prefs.json';
  static final Map<String, dynamic> _defaultPreferences = {
    'keyFormat': 'snake_case',
    'outputDir': 'lib/l10n',
    'useAppLocalizations': true,
    'excludePatterns': [
      r'^https?://', // URLs
      r'^www\.', // Web addresses
      r'^assets/', // Asset paths
      r'^[\w-]+\.(?:png|jpg|jpeg|svg|gif|webp|json|arb|md)$', // Image and data files
      r'^[\w/\-\.]+$', // Simple file paths with no spaces
      r'^\w+\.', // Simple file extensions
      r'^\w+://\w+', // URI schemes
      r'^[\d,.]+$', // Numbers
      r'^<[^>]+>$', // XML/HTML tags
      r'^#[0-9a-fA-F]{3,8}$', // Color hex codes
    ],
    'lastUsed': DateTime.now().toIso8601String(),
  };

  /// Get the preferences file
  static File _getPrefsFile() {
    final home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home == null) {
      throw Exception('Could not determine home directory');
    }
    return File(path.join(home, _prefsFileName));
  }

  /// Load user preferences
  static Map<String, dynamic> loadPreferences() {
    final prefsFile = _getPrefsFile();
    if (!prefsFile.existsSync()) {
      final defaultPrefs = Map<String, dynamic>.from(_defaultPreferences);
      defaultPrefs['prefsPath'] =
          prefsFile.path; // Add path for reference by other classes
      return defaultPrefs;
    }

    try {
      final content = prefsFile.readAsStringSync();
      final prefs = jsonDecode(content) as Map<String, dynamic>;
      // Update last used date
      prefs['lastUsed'] = DateTime.now().toIso8601String();
      prefs['prefsPath'] =
          prefsFile.path; // Add path for reference by other classes

      // Ensure all default keys exist
      for (final key in _defaultPreferences.keys) {
        if (!prefs.containsKey(key)) {
          prefs[key] = _defaultPreferences[key];
        }
      }

      return prefs;
    } catch (e) {
      print('\u001b[33mWarning: Failed to load preferences: $e\u001b[0m');
      final defaultPrefs = Map<String, dynamic>.from(_defaultPreferences);
      defaultPrefs['prefsPath'] =
          prefsFile.path; // Add path for reference by other classes
      return defaultPrefs;
    }
  }

  /// Save user preferences
  static void savePreferences(Map<String, dynamic> prefs) {
    final prefsFile = _getPrefsFile();
    try {
      // Update last used date
      prefs['lastUsed'] = DateTime.now().toIso8601String();
      final content = JsonEncoder.withIndent('  ').convert(prefs);
      prefsFile.writeAsStringSync(content);
      print('\u001b[32mPreferences saved to ${prefsFile.path}\u001b[0m');
    } catch (e) {
      print('\u001b[33mWarning: Failed to save preferences: $e\u001b[0m');
    }
  }

  /// Ask user if they want to use saved preferences or change them
  static Future<Map<String, dynamic>> promptForPreferences() async {
    final prefs = loadPreferences();
    final lastUsedDate = DateTime.parse(prefs['lastUsed']);
    final daysSinceLastUse = DateTime.now().difference(lastUsedDate).inDays;

    print(
        '\n\u001b[36mSaved preferences (last used: ${daysSinceLastUse > 0 ? '$daysSinceLastUse days ago' : 'today'}):\u001b[0m');
    print('- Key format: \u001b[32m${prefs['keyFormat']}\u001b[0m');
    print('- Output directory: \u001b[32m${prefs['outputDir']}\u001b[0m');

    stdout.write('\nDo you want to use these preferences? (Y/n): ');
    final response = stdin.readLineSync()?.toLowerCase() ?? 'y';

    if (response == 'n' || response == 'no') {
      // Prompt for new preferences
      return await _promptNewPreferences(prefs);
    }

    return prefs;
  }

  /// Prompt user for new preferences
  static Future<Map<String, dynamic>> _promptNewPreferences(
      Map<String, dynamic> currentPrefs) async {
    final newPrefs = Map<String, dynamic>.from(currentPrefs);

    // Key format
    stdout.write('\nSelect key format:\n');
    stdout.write('1. snake_case (example: hello_world)\n');
    stdout.write('2. camelCase (example: helloWorld)\n');
    stdout.write('3. dot.case (example: hello.world)\n');
    stdout.write('Select (1-3) [default: 1]: ');

    final formatChoice = stdin.readLineSync() ?? '1';
    switch (formatChoice) {
      case '2':
        newPrefs['keyFormat'] = 'camelCase';
        break;
      case '3':
        newPrefs['keyFormat'] = 'dot.case';
        break;
      default:
        newPrefs['keyFormat'] = 'snake_case';
    }

    // Output directory
    stdout.write('\nOutput directory [${currentPrefs['outputDir']}]: ');
    final outDir = stdin.readLineSync();
    if (outDir != null && outDir.isNotEmpty) {
      newPrefs['outputDir'] = outDir;
    }

    // Ask if user wants to manage exclude patterns
    stdout.write('\nDo you want to manage exclude patterns? (y/N): ');
    final managePatterns = stdin.readLineSync()?.toLowerCase() ?? 'n';

    if (managePatterns == 'y' || managePatterns == 'yes') {
      await _manageExcludePatterns(newPrefs);
    }

    // Save the new preferences
    savePreferences(newPrefs);

    return newPrefs;
  }

  /// Manage exclude patterns interactively
  static Future<void> _manageExcludePatterns(Map<String, dynamic> prefs) async {
    List<String> patterns = [];

    if (prefs.containsKey('excludePatterns') &&
        prefs['excludePatterns'] is List) {
      patterns = (prefs['excludePatterns'] as List).cast<String>();
    }

    // List of common pattern categories to offer to the user
    final patternCategories = {
      'URLs and Web Addresses': [
        r'^https?://', // URLs with http/https
        r'^www\.', // Web addresses starting with www
        r'^\w+://\w+', // URI schemes
      ],
      'File Paths and Assets': [
        r'^assets/', // Asset paths
        r'^[\w-]+\.(?:png|jpg|jpeg|svg|gif|webp|json|arb|md)$', // Image and data files
        r'^[\w/\-\.]+$', // Simple file paths with no spaces
        r'^\w+\.', // Simple file extensions
      ],
      'Formatting Codes': [
        r'^<[^>]+>$', // XML/HTML tags
        r'^#[0-9a-fA-F]{3,8}$', // Color hex codes
      ],
      'Numbers and IDs': [
        r'^[\d,.]+$', // Numbers and simple formatted numbers
        r'^\d+\.\d+\.\d+$', // Version numbers
        r'^\w{8}-\w{4}-\w{4}-\w{4}-\w{12}$', // UUIDs
      ],
      'Code Elements': [
        r'^[A-Z][a-zA-Z0-9]*\.[A-Za-z0-9]+', // Class references like Widget.property
        r'^@\w+', // Annotations
        r'^_\w+$', // Private variables
      ],
    };

    while (true) {
      print('\n\u001b[36mManage Exclude Patterns\u001b[0m');
      print('\nCurrent exclude patterns:');

      if (patterns.isEmpty) {
        print('  No patterns defined.');
      } else {
        for (var i = 0; i < patterns.length; i++) {
          print('  ${i + 1}. \u001b[32m${patterns[i]}\u001b[0m');
        }
      }

      print('\nOptions:');
      print('  1. Add a new pattern');
      print('  2. Add from common pattern categories');
      print('  3. Remove a pattern');
      print('  4. Test a pattern against sample text');
      print('  5. Reset to default patterns');
      print('  6. Done (save and return)');

      stdout.write('\nSelect an option (1-6): ');
      final option = stdin.readLineSync() ?? '6';

      switch (option) {
        case '1':
          stdout.write('\nEnter a new exclude pattern (regex): ');
          final newPattern = stdin.readLineSync();
          if (newPattern != null && newPattern.isNotEmpty) {
            try {
              RegExp(newPattern);

              // Check if pattern already exists
              if (patterns.contains(newPattern)) {
                print(
                    '\n\u001b[33mPattern already exists in the list\u001b[0m');
              } else {
                patterns.add(newPattern);
                prefs['excludePatterns'] = patterns;
                print('\n\u001b[32mPattern added successfully\u001b[0m');
              }
            } catch (e) {
              print('\n\u001b[31mInvalid regex pattern: $e\u001b[0m');
            }
          }
          break;

        case '2':
          // Show category options
          print('\n\u001b[36mPattern Categories:\u001b[0m');
          final categories = patternCategories.keys.toList();
          for (var i = 0; i < categories.length; i++) {
            print('  ${i + 1}. ${categories[i]}');
          }

          stdout.write('\nSelect a category (1-${categories.length}): ');
          final categoryStr = stdin.readLineSync();
          if (categoryStr != null && categoryStr.isNotEmpty) {
            try {
              final index = int.parse(categoryStr);
              if (index >= 1 && index <= categories.length) {
                final category = categories[index - 1];
                final categoryPatterns = patternCategories[category]!;

                print('\n\u001b[36mPatterns in "$category":\u001b[0m');
                for (var i = 0; i < categoryPatterns.length; i++) {
                  print(
                      '  ${i + 1}. \u001b[32m${categoryPatterns[i]}\u001b[0m');
                }

                stdout.write('\nAdd all patterns from this category? (y/N): ');
                final addAll = stdin.readLineSync()?.toLowerCase() ?? 'n';

                if (addAll == 'y' || addAll == 'yes') {
                  // Add all patterns from the category
                  for (final pattern in categoryPatterns) {
                    if (!patterns.contains(pattern)) {
                      patterns.add(pattern);
                    }
                  }
                  prefs['excludePatterns'] = patterns;
                  print('\n\u001b[32mAdded patterns from "$category"\u001b[0m');
                } else {
                  // Allow selecting individual patterns
                  stdout.write(
                      '\nEnter pattern number to add (1-${categoryPatterns.length}): ');
                  final patternStr = stdin.readLineSync();
                  if (patternStr != null && patternStr.isNotEmpty) {
                    final patternIndex = int.parse(patternStr);
                    if (patternIndex >= 1 &&
                        patternIndex <= categoryPatterns.length) {
                      final pattern = categoryPatterns[patternIndex - 1];
                      if (!patterns.contains(pattern)) {
                        patterns.add(pattern);
                        prefs['excludePatterns'] = patterns;
                        print('\n\u001b[32mAdded pattern: $pattern\u001b[0m');
                      } else {
                        print(
                            '\n\u001b[33mPattern already exists in the list\u001b[0m');
                      }
                    } else {
                      print('\n\u001b[31mInvalid pattern number\u001b[0m');
                    }
                  }
                }
              } else {
                print('\n\u001b[31mInvalid category number\u001b[0m');
              }
            } catch (e) {
              print('\n\u001b[31mInvalid input: $e\u001b[0m');
            }
          }
          break;

        case '3':
          if (patterns.isEmpty) {
            print('\n\u001b[33mNo patterns to remove.\u001b[0m');
          } else {
            stdout.write(
                '\nEnter pattern number to remove (1-${patterns.length}): ');
            final indexStr = stdin.readLineSync();
            if (indexStr != null && indexStr.isNotEmpty) {
              try {
                final index = int.parse(indexStr);
                if (index >= 1 && index <= patterns.length) {
                  final removedPattern = patterns.removeAt(index - 1);
                  prefs['excludePatterns'] = patterns;
                  print(
                      '\n\u001b[32mRemoved pattern: $removedPattern\u001b[0m');
                } else {
                  print('\n\u001b[31mInvalid pattern number\u001b[0m');
                }
              } catch (e) {
                print('\n\u001b[31mInvalid input: $e\u001b[0m');
              }
            }
          }
          break;

        case '4':
          // Test pattern against sample text
          if (patterns.isEmpty) {
            print('\n\u001b[33mNo patterns to test.\u001b[0m');
          } else {
            stdout.write(
                '\nEnter pattern number to test (1-${patterns.length}): ');
            final indexStr = stdin.readLineSync();
            if (indexStr != null && indexStr.isNotEmpty) {
              try {
                final index = int.parse(indexStr);
                if (index >= 1 && index <= patterns.length) {
                  final pattern = patterns[index - 1];
                  stdout.write('\nEnter sample text to test against: ');
                  final sampleText = stdin.readLineSync() ?? '';

                  try {
                    final regex = RegExp(pattern);
                    final matches = regex.hasMatch(sampleText);

                    if (matches) {
                      print(
                          '\n\u001b[32mPattern MATCHES the sample text\u001b[0m');
                      print(
                          'This means the text would be EXCLUDED from translation');
                    } else {
                      print(
                          '\n\u001b[33mPattern does NOT match the sample text\u001b[0m');
                      print(
                          'This means the text would be INCLUDED for translation');
                    }
                  } catch (e) {
                    print('\n\u001b[31mError testing pattern: $e\u001b[0m');
                  }
                } else {
                  print('\n\u001b[31mInvalid pattern number\u001b[0m');
                }
              } catch (e) {
                print('\n\u001b[31mInvalid input: $e\u001b[0m');
              }
            }
          }
          break;

        case '5':
          stdout.write('\nReset to default exclude patterns? (y/N): ');
          final confirm = stdin.readLineSync()?.toLowerCase() ?? 'n';
          if (confirm == 'y' || confirm == 'yes') {
            patterns = List<String>.from(
                _defaultPreferences['excludePatterns'] as List);
            prefs['excludePatterns'] = patterns;
            print('\n\u001b[32mExclude patterns reset to defaults\u001b[0m');
          }
          break;

        case '6':
        default:
          return; // Exit the management loop
      }
    }
  }
}

// Helper function to detect package name from pubspec.yaml
String detectPackageName(String directoryPath) {
  try {
    // Normalize path to make sure it doesn't end with a slash
    final normalizedPath = directoryPath.endsWith('/')
        ? directoryPath.substring(0, directoryPath.length - 1)
        : directoryPath;

    // Handle relative paths using path package for better cross-platform support
    final rootPath = normalizedPath.startsWith('lib${path.separator}')
        ? normalizedPath.replaceFirst('lib${path.separator}', '')
        : normalizedPath;

    // Try different possible locations for pubspec.yaml
    final List<String> possiblePaths = [
      path.join(rootPath, 'pubspec.yaml'),
      path.join(path.split(rootPath).first, 'pubspec.yaml'),
      'pubspec.yaml',
      path.join('..', 'pubspec.yaml'),
    ];

    File? pubspecFile;
    for (final path in possiblePaths) {
      final file = File(path);
      if (file.existsSync()) {
        pubspecFile = file;
        break;
      }
    }

    if (pubspecFile == null) {
      // If we still haven't found it, try searching up the directory tree
      var currentDir = Directory(rootPath);
      while (currentDir.path != '/' && currentDir.path.isNotEmpty) {
        final pubspec = File('${currentDir.path}/pubspec.yaml');
        if (pubspec.existsSync()) {
          pubspecFile = pubspec;
          break;
        }
        currentDir = currentDir.parent;
      }
    }

    if (pubspecFile != null) {
      final content = pubspecFile.readAsStringSync();
      
      // Try to find the package name with a more robust regex
      final nameMatch = RegExp(r'name:\s*([a-zA-Z0-9_-]+)').firstMatch(content);
      if (nameMatch != null && nameMatch.groupCount >= 1) {
        final pkgName = nameMatch.group(1)!;
        print('\u001b[36mℹ️  Detected package name: $pkgName\u001b[0m');
        return pkgName;
      }

      print('\u001b[33mWarning: Could not detect package name from pubspec.yaml\u001b[0m');
    }

    // Use directory name as fallback
    final dirName = path.basename(path.dirname(pubspecFile?.path ?? directoryPath));
    final sanitizedDirName = dirName.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    print('\u001b[33mℹ️  Using directory name as package name: $sanitizedDirName\u001b[0m');
    return sanitizedDirName;
  } catch (e) {
    print('Error detecting package name: $e');
    return 'app';
  }
}

/// Helper function to find pubspec.yaml file in various possible locations
File? _findPubspecFile(String directoryPath) {
  final possiblePaths = [
    path.join(directoryPath, 'pubspec.yaml'),
    path.join(path.dirname(directoryPath), 'pubspec.yaml'),
    'pubspec.yaml',
    '../pubspec.yaml',
  ];

  for (final possiblePath in possiblePaths) {
    final file = File(possiblePath);
    if (file.existsSync()) {
      return file;
    }
  }

  // If we still haven't found it, try searching up the directory tree
  var currentDir = Directory(directoryPath);
  while (currentDir.path != path.separator && currentDir.path.isNotEmpty) {
    final pubspec = File(path.join(currentDir.path, 'pubspec.yaml'));
    if (pubspec.existsSync()) {
      return pubspec;
    }
    final parent = currentDir.parent;
    if (parent.path == currentDir.path) break; // Reached root
    currentDir = parent;
  }

  return null;
}

/// Check if flutter_localizations dependency exists in pubspec.yaml
/// If not, add it automatically
bool ensureFlutterLocalizationsDependency(String directoryPath) {
  try {
    // Find pubspec.yaml file
    final pubspecFile = _findPubspecFile(directoryPath);

    if (pubspecFile == null) {
      print('\u001b[31mError: Could not find pubspec.yaml file\u001b[0m');
      print('\u001b[33mSearched in directory: $directoryPath\u001b[0m');
      return false;
    }

    print('\u001b[36mℹ️  Found pubspec.yaml at: ${pubspecFile.path}\u001b[0m');
    final content = pubspecFile.readAsStringSync();
    final lines = content.split('\n');
    
    // First find the dependencies section
    final dependenciesIndex = lines.indexWhere((line) => line.trim() == 'dependencies:');
    if (dependenciesIndex == -1) {
      print('\u001b[31mError: Could not find dependencies section in pubspec.yaml\u001b[0m');
      return false;
    }

    // Analyze existing dependencies - scan the entire dependencies section
    bool hasFlutter = false;
    bool hasFlutterLocalizations = false;
    bool hasIntl = false;
    int lastSdkDependencyIndex = dependenciesIndex;
    String? intlVersion;

    // Go through each line after dependencies to find existing deps
    for (var i = dependenciesIndex + 1; i < lines.length; i++) {
      final line = lines[i].trim();
      
      // Stop if we hit another top-level section (no leading spaces and ends with colon)
      if (line.isNotEmpty && !lines[i].startsWith(' ') && line.endsWith(':')) {
        break;
      }
      
      // Skip blank lines and comments
      if (line.isEmpty || line.startsWith('#')) {
        continue;
      }

      // Check for specific dependencies
      if (line.startsWith('flutter:')) {
        hasFlutter = true;
        // Check next line to verify it's an SDK dependency
        if (i + 1 < lines.length && lines[i + 1].trim() == 'sdk: flutter') {
          lastSdkDependencyIndex = i + 1;
        }
      } else if (line.startsWith('flutter_localizations:')) {
        hasFlutterLocalizations = true;
        // Check next line to verify it's an SDK dependency
        if (i + 1 < lines.length && lines[i + 1].trim() == 'sdk: flutter') {
          lastSdkDependencyIndex = i + 1;
        }
      } else if (line.startsWith('intl:')) {
        hasIntl = true;
        // Extract version if present
        final versionMatch = RegExp(r'^intl:\s*[\^~]?(\d+\.\d+\.\d+)').firstMatch(line);
        if (versionMatch != null) {
          intlVersion = versionMatch.group(1);
        }
      }
    }

    // Print current status
    print('\u001b[36mDependency status:\u001b[0m');
    print('\u001b[36m  flutter: ${hasFlutter ? "✓" : "✗"}\u001b[0m');
    print('\u001b[36m  flutter_localizations: ${hasFlutterLocalizations ? "✓" : "✗"}\u001b[0m');
    print('\u001b[36m  intl: ${hasIntl ? "✓" : "✗"}${intlVersion != null ? " (v$intlVersion)" : ""}\u001b[0m');

    bool needsWrite = false;
    final indentation = '  ';
    final sdkIndentation = '$indentation  ';
    var insertIndex = lastSdkDependencyIndex;

    // Handle Flutter SDK if missing
    if (!hasFlutter) {
      insertIndex++;
      lines.insert(insertIndex, '${indentation}flutter:');
      insertIndex++;
      lines.insert(insertIndex, '${sdkIndentation}sdk: flutter');
      lastSdkDependencyIndex = insertIndex;
      needsWrite = true;
      print('\u001b[32m✓ Added flutter SDK dependency\u001b[0m');
    }

    // Handle flutter_localizations if missing
    if (!hasFlutterLocalizations) {
      insertIndex = lastSdkDependencyIndex + 1;
      lines.insert(insertIndex, '${indentation}flutter_localizations:');
      insertIndex++;
      lines.insert(insertIndex, '${sdkIndentation}sdk: flutter');
      lastSdkDependencyIndex = insertIndex;
      needsWrite = true;
      print('\u001b[32m✓ Added flutter_localizations dependency\u001b[0m');
    }

    // Handle intl if missing or needs version update
    // Compare version numbers properly - need at least 0.18.0
    bool needsIntlUpdate = !hasIntl;
    if (hasIntl && intlVersion != null) {
      // Parse version numbers for proper comparison
      final currentVersion = _parseVersion(intlVersion);
      final minVersion = _parseVersion('0.18.0');
      needsIntlUpdate = _compareVersions(currentVersion, minVersion) < 0;
    }
    
    if (needsIntlUpdate) {
      insertIndex = lastSdkDependencyIndex + 1;
      final intlLine = '${indentation}intl: ^0.19.0  # Required for internationalization';
      if (hasIntl) {
        // Replace existing intl line
        for (var i = 0; i < lines.length; i++) {
          if (lines[i].trim().startsWith('intl:')) {
            lines[i] = intlLine;
            break;
          }
        }
      } else {
        lines.insert(insertIndex, intlLine);
      }
      needsWrite = true;
      print('\u001b[32m✓ ${hasIntl ? "Updated" : "Added"} intl dependency to v0.19.0\u001b[0m');
    }

    if (needsWrite) {
      // Write changes back to file
      try {
        pubspecFile.writeAsStringSync(lines.join('\n'));
        print('\u001b[32m✓ Dependencies updated successfully in ${pubspecFile.path}\u001b[0m');
        print('\u001b[36mℹ️  Run "flutter pub get" to update dependencies\u001b[0m');
        
        // Verify the write was successful by reading back
        final verifyContent = pubspecFile.readAsStringSync();
        final hasIntlCheck = verifyContent.contains('intl:');
        final hasFlutterLocCheck = verifyContent.contains('flutter_localizations:');
        
        if (hasIntlCheck && hasFlutterLocCheck) {
          print('\u001b[32m✓ Verified: Dependencies successfully written to file\u001b[0m');
        } else {
          print('\u001b[33m⚠️  Warning: Dependencies may not have been written correctly\u001b[0m');
          print('\u001b[33m   intl found: $hasIntlCheck, flutter_localizations found: $hasFlutterLocCheck\u001b[0m');
        }
      } catch (writeError) {
        print('\u001b[31mError writing to pubspec.yaml: $writeError\u001b[0m');
        print('\u001b[33mFile path: ${pubspecFile.path}\u001b[0m');
        return false;
      }
    } else {
      print('\u001b[32m✓ All required dependencies are already present\u001b[0m');
    }
    
    return true;
  } catch (e) {
    print('\u001b[31mError adding dependencies: $e\u001b[0m');
    print('\u001b[33mDirectory: $directoryPath\u001b[0m');
    return false;
  }
}

/// Enhanced version using yaml_edit for safer YAML manipulation
/// Checks if flutter_localizations and intl dependencies exist in pubspec.yaml
/// If not, adds them automatically using structured YAML editing
bool ensureFlutterLocalizationsDependencySafe(String directoryPath) {
  try {
    // Find pubspec.yaml file using the existing function
    final pubspecFile = _findPubspecFile(directoryPath);

    if (pubspecFile == null) {
      print('\u001b[31mError: Could not find pubspec.yaml file\u001b[0m');
      print('\u001b[33mSearched in directory: $directoryPath\u001b[0m');
      return false;
    }

    print('\u001b[36mℹ️  Found pubspec.yaml at: ${pubspecFile.path}\u001b[0m');
    
    final content = pubspecFile.readAsStringSync();
    
    // Parse the YAML content to check existing dependencies
    final yamlDoc = loadYaml(content);
    
    // Check if dependencies section exists
    if (yamlDoc is! Map || !yamlDoc.containsKey('dependencies')) {
      print('\u001b[31mError: Could not find dependencies section in pubspec.yaml\u001b[0m');
      return false;
    }

    final dependencies = yamlDoc['dependencies'] as Map<dynamic, dynamic>;

    // Check existing dependencies
    final hasFlutter = dependencies.containsKey('flutter');
    final hasFlutterLocalizations = dependencies.containsKey('flutter_localizations');
    final hasIntl = dependencies.containsKey('intl');
    
    // Check intl version if it exists
    String? intlVersion;
    if (hasIntl) {
      final intlDep = dependencies['intl'];
      if (intlDep is String) {
        final versionMatch = RegExp(r'[\^~]?(\d+\.\d+\.\d+)').firstMatch(intlDep);
        if (versionMatch != null) {
          intlVersion = versionMatch.group(1);
        }
      }
    }

    // Print current status
    print('\u001b[36mDependency status:\u001b[0m');
    print('\u001b[36m  flutter: ${hasFlutter ? "✓" : "✗"}\u001b[0m');
    print('\u001b[36m  flutter_localizations: ${hasFlutterLocalizations ? "✓" : "✗"}\u001b[0m');
    print('\u001b[36m  intl: ${hasIntl ? "✓" : "✗"}${intlVersion != null ? " (v$intlVersion)" : ""}\u001b[0m');

    bool needsWrite = false;
    
    // Create YAML editor for safe modifications
    final yamlEditor = YamlEditor(content);

    // Add flutter dependency if missing
    if (!hasFlutter) {
      yamlEditor.update(['dependencies', 'flutter'], {'sdk': 'flutter'});
      needsWrite = true;
      print('\u001b[32m✓ Added flutter SDK dependency\u001b[0m');
    }

    // Add flutter_localizations if missing
    if (!hasFlutterLocalizations) {
      yamlEditor.update(['dependencies', 'flutter_localizations'], {'sdk': 'flutter'});
      needsWrite = true;
      print('\u001b[32m✓ Added flutter_localizations dependency\u001b[0m');
    }

    // Add or update intl dependency if missing or outdated
    bool needsIntlUpdate = !hasIntl;
    if (hasIntl && intlVersion != null) {
      // Parse version numbers for proper comparison - need at least 0.18.0
      final currentVersion = _parseVersion(intlVersion);
      final minVersion = _parseVersion('0.18.0');
      needsIntlUpdate = _compareVersions(currentVersion, minVersion) < 0;
    }
    
    if (needsIntlUpdate) {
      yamlEditor.update(['dependencies', 'intl'], '^0.19.0');
      needsWrite = true;
      print('\u001b[32m✓ ${hasIntl ? "Updated" : "Added"} intl dependency to v0.19.0\u001b[0m');
    }

    if (needsWrite) {
      try {
        // Write the updated YAML content
        pubspecFile.writeAsStringSync(yamlEditor.toString());
        print('\u001b[32m✓ Dependencies updated successfully using YAML editor in ${pubspecFile.path}\u001b[0m');
        print('\u001b[36mℹ️  Run "flutter pub get" to update dependencies\u001b[0m');
        
        // Verify the write was successful by reading back and checking
        final verifyContent = pubspecFile.readAsStringSync();
        final hasIntlCheck = verifyContent.contains('intl:');
        final hasFlutterLocCheck = verifyContent.contains('flutter_localizations:');
        
        if (hasIntlCheck && hasFlutterLocCheck) {
          print('\u001b[32m✓ Verified: Dependencies successfully written to file\u001b[0m');
        } else {
          print('\u001b[33m⚠️  Warning: Dependencies may not have been written correctly\u001b[0m');
          print('\u001b[33m   intl found: $hasIntlCheck, flutter_localizations found: $hasFlutterLocCheck\u001b[0m');
        }
      } catch (writeError) {
        print('\u001b[31mError writing to pubspec.yaml with YAML editor: $writeError\u001b[0m');
        print('\u001b[33mFile path: ${pubspecFile.path}\u001b[0m');
        print('\u001b[36mℹ️  Falling back to string-based method...\u001b[0m');
        
        // Fallback to the original string-based method
        return ensureFlutterLocalizationsDependency(directoryPath);
      }
    } else {
      print('\u001b[32m✓ All required dependencies are already present\u001b[0m');
    }
    
    return true;
  } catch (e) {
    print('\u001b[31mError adding dependencies with YAML editor: $e\u001b[0m');
    print('\u001b[33mDirectory: $directoryPath\u001b[0m');
    print('\u001b[36mℹ️  Falling back to string-based method...\u001b[0m');
    
    // Fallback to the original string-based method
    return ensureFlutterLocalizationsDependency(directoryPath);
  }
}

/// Setup complete Flutter localization configuration including l10n.yaml and pubspec.yaml updates
/// This ensures the project is properly configured for Flutter's localization generation
bool setupFlutterLocalizationConfiguration(String projectRoot) {
  try {
    print('\u001b[36mℹ️  Setting up Flutter localization configuration...\u001b[0m');
    
    // 1. Find and update pubspec.yaml to ensure 'generate: true' is set
    final pubspecFile = _findPubspecFile(projectRoot);
    if (pubspecFile == null) {
      print('\u001b[31mError: Could not find pubspec.yaml file\u001b[0m');
      return false;
    }

    bool pubspecUpdated = false;
    try {
      final content = pubspecFile.readAsStringSync();
      final yamlEditor = YamlEditor(content);
      
      // Check if flutter.generate is already set to true
      final yamlDoc = loadYaml(content);
      bool hasGenerate = false;
      
      if (yamlDoc is Map && yamlDoc.containsKey('flutter')) {
        final flutterSection = yamlDoc['flutter'];
        if (flutterSection is Map && flutterSection.containsKey('generate')) {
          hasGenerate = flutterSection['generate'] == true;
        }
      }
      
      if (!hasGenerate) {
        // First ensure flutter section exists
        try {
          if (yamlDoc is! Map || !yamlDoc.containsKey('flutter')) {
            yamlEditor.update(['flutter'], {});
          }
          // Then add/update flutter.generate to true
          yamlEditor.update(['flutter', 'generate'], true);
          pubspecFile.writeAsStringSync(yamlEditor.toString());
          pubspecUpdated = true;
          print('\u001b[32m✓ Added "generate: true" to pubspec.yaml flutter section\u001b[0m');
        } catch (e) {
          // If YAML editing fails, try string-based approach
          print('\u001b[33m⚠️  YAML editor failed, trying string-based approach...\u001b[0m');
          final lines = content.split('\n');
          int flutterIndex = lines.indexWhere((line) => line.trim() == 'flutter:');
          
          // Check if generate: true already exists
          bool hasGenerate = false;
          if (flutterIndex != -1) {
            for (int i = flutterIndex + 1; i < lines.length; i++) {
              final line = lines[i].trim();
              if (line.isEmpty || line.startsWith('#')) continue;
              if (!lines[i].startsWith(' ') && line.endsWith(':')) break; // Hit another section
              if (line == 'generate: true') {
                hasGenerate = true;
                break;
              }
            }
          }
          
          if (!hasGenerate) {
            if (flutterIndex == -1) {
              lines.add('flutter:');
              lines.add('  generate: true');
            } else {
              lines.insert(flutterIndex + 1, '  generate: true');
            }
            pubspecFile.writeAsStringSync(lines.join('\n'));
            pubspecUpdated = true;
            print('\u001b[32m✓ Added "generate: true" to pubspec.yaml flutter section\u001b[0m');
          } else {
            print('\u001b[36mℹ️  "generate: true" already present in pubspec.yaml\u001b[0m');
          }
        }
      } else {
        print('\u001b[36mℹ️  "generate: true" already present in pubspec.yaml\u001b[0m');
      }
    } catch (e) {
      print('\u001b[33m⚠️  Could not update pubspec.yaml flutter section: $e\u001b[0m');
      print('\u001b[36mℹ️  Please manually add "generate: true" under the flutter section\u001b[0m');
    }

    // 2. Create l10n.yaml configuration file if it doesn't exist
    final l10nFile = File(path.join(projectRoot, 'l10n.yaml'));
    bool l10nCreated = false;
    
    if (!l10nFile.existsSync()) {
      try {
        final l10nConfig = '''arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
use-escaping: true
synthetic-package: false
''';
        l10nFile.writeAsStringSync(l10nConfig);
        l10nCreated = true;
        print('\u001b[32m✓ Created l10n.yaml configuration file\u001b[0m');
      } catch (e) {
        print('\u001b[33m⚠️  Could not create l10n.yaml: $e\u001b[0m');
        print('\u001b[36mℹ️  Please manually create l10n.yaml in your project root\u001b[0m');
      }
    } else {
      print('\u001b[36mℹ️  l10n.yaml already exists\u001b[0m');
    }

    // 3. Ensure lib/l10n directory exists
    final l10nDir = Directory(path.join(projectRoot, 'lib', 'l10n'));
    bool dirCreated = false;
    
    if (!l10nDir.existsSync()) {
      try {
        l10nDir.createSync(recursive: true);
        dirCreated = true;
        print('\u001b[32m✓ Created lib/l10n directory\u001b[0m');
      } catch (e) {
        print('\u001b[33m⚠️  Could not create lib/l10n directory: $e\u001b[0m');
      }
    } else {
      print('\u001b[36mℹ️  lib/l10n directory already exists\u001b[0m');
    }

    // 4. Provide setup summary and next steps
    if (pubspecUpdated || l10nCreated || dirCreated) {
      print('\u001b[32m✓ Flutter localization configuration setup completed\u001b[0m');
      if (pubspecUpdated) {
        print('\u001b[36mℹ️  Run "flutter pub get" to apply pubspec.yaml changes\u001b[0m');
      }
    } else {
      print('\u001b[36mℹ️  Flutter localization configuration already properly set up\u001b[0m');
    }

    return true;
  } catch (e) {
    print('\u001b[31mError setting up Flutter localization configuration: $e\u001b[0m');
    return false;
  }
}

/// Helper function to parse version string into list of integers for comparison
List<int> _parseVersion(String version) {
  // Remove any prefix characters like ^, ~, >=, etc.
  final cleanVersion = version.replaceAll(RegExp(r'^[\^~>=<]+'), '');
  
  try {
    return cleanVersion.split('.').map((part) {
      // Extract only numeric part in case there are suffixes like -beta, +build
      final numericPart = RegExp(r'^\d+').firstMatch(part);
      return numericPart != null ? int.parse(numericPart.group(0)!) : 0;
    }).toList();
  } catch (e) {
    // If parsing fails, return a very low version [0, 0, 0]
    return [0, 0, 0];
  }
}

/// Helper function to compare two version lists
/// Returns: -1 if version1 < version2, 0 if equal, 1 if version1 > version2
int _compareVersions(List<int> version1, List<int> version2) {
  final maxLength = [version1.length, version2.length].reduce((a, b) => a > b ? a : b);
  
  for (int i = 0; i < maxLength; i++) {
    final v1Part = i < version1.length ? version1[i] : 0;
    final v2Part = i < version2.length ? version2[i] : 0;
    
    if (v1Part < v2Part) return -1;
    if (v1Part > v2Part) return 1;
  }
  
  return 0; // Versions are equal
}
