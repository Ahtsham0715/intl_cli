import 'dart:io';
import 'dart:convert';

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
    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home == null) {
      throw Exception('Could not determine home directory');
    }
    return File('$home/$_prefsFileName');
  }

  /// Load user preferences
  static Map<String, dynamic> loadPreferences() {
    final prefsFile = _getPrefsFile();
    if (!prefsFile.existsSync()) {
      final defaultPrefs = Map<String, dynamic>.from(_defaultPreferences);
      defaultPrefs['prefsPath'] = prefsFile.path; // Add path for reference by other classes
      return defaultPrefs;
    }

    try {
      final content = prefsFile.readAsStringSync();
      final prefs = jsonDecode(content) as Map<String, dynamic>;
      // Update last used date
      prefs['lastUsed'] = DateTime.now().toIso8601String();
      prefs['prefsPath'] = prefsFile.path; // Add path for reference by other classes
      
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
      defaultPrefs['prefsPath'] = prefsFile.path; // Add path for reference by other classes
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
    
    print('\n\u001b[36mSaved preferences (last used: ${daysSinceLastUse > 0 ? '$daysSinceLastUse days ago' : 'today'}):\u001b[0m');
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
  static Future<Map<String, dynamic>> _promptNewPreferences(Map<String, dynamic> currentPrefs) async {
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
    
    if (prefs.containsKey('excludePatterns') && prefs['excludePatterns'] is List) {
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
                print('\n\u001b[33mPattern already exists in the list\u001b[0m');
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
                  print('  ${i + 1}. \u001b[32m${categoryPatterns[i]}\u001b[0m');
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
                  stdout.write('\nEnter pattern number to add (1-${categoryPatterns.length}): ');
                  final patternStr = stdin.readLineSync();
                  if (patternStr != null && patternStr.isNotEmpty) {
                    final patternIndex = int.parse(patternStr);
                    if (patternIndex >= 1 && patternIndex <= categoryPatterns.length) {
                      final pattern = categoryPatterns[patternIndex - 1];
                      if (!patterns.contains(pattern)) {
                        patterns.add(pattern);
                        prefs['excludePatterns'] = patterns;
                        print('\n\u001b[32mAdded pattern: $pattern\u001b[0m');
                      } else {
                        print('\n\u001b[33mPattern already exists in the list\u001b[0m');
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
            stdout.write('\nEnter pattern number to remove (1-${patterns.length}): ');
            final indexStr = stdin.readLineSync();
            if (indexStr != null && indexStr.isNotEmpty) {
              try {
                final index = int.parse(indexStr);
                if (index >= 1 && index <= patterns.length) {
                  final removedPattern = patterns.removeAt(index - 1);
                  prefs['excludePatterns'] = patterns;
                  print('\n\u001b[32mRemoved pattern: $removedPattern\u001b[0m');
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
            stdout.write('\nEnter pattern number to test (1-${patterns.length}): ');
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
                      print('\n\u001b[32mPattern MATCHES the sample text\u001b[0m');
                      print('This means the text would be EXCLUDED from translation');
                    } else {
                      print('\n\u001b[33mPattern does NOT match the sample text\u001b[0m');
                      print('This means the text would be INCLUDED for translation');
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
            patterns = List<String>.from(_defaultPreferences['excludePatterns'] as List);
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
    
    // Handle relative paths
    final rootPath = normalizedPath.startsWith('lib/') 
        ? normalizedPath.replaceFirst('lib/', '') 
        : normalizedPath;
    
    // Try different possible locations for pubspec.yaml
    final List<String> possiblePaths = [
      '$rootPath/pubspec.yaml',
      '${rootPath.split('/').first}/pubspec.yaml',
      'pubspec.yaml',
      '../pubspec.yaml',
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
      final nameMatch = RegExp(r'name:\s*([a-zA-Z0-9_]+)').firstMatch(content);
      if (nameMatch != null && nameMatch.groupCount >= 1) {
        return nameMatch.group(1)!;
      }
    }
    
    // Default fallback
    return 'app';
  } catch (e) {
    print('Error detecting package name: $e');
    return 'app';
  }
}
