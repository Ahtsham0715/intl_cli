import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;

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
    return File(path.join(home, _prefsFileName));
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

/// Check if flutter_localizations dependency exists in pubspec.yaml
/// If not, add it automatically
bool ensureFlutterLocalizationsDependency(String directoryPath) {
  try {
    // Find pubspec.yaml file
    final pubspecFile = _findPubspecFile(directoryPath);
    if (pubspecFile == null) {
      print('\u001b[33mWarning: Could not find pubspec.yaml file\u001b[0m');
      return false;
    }

    final content = pubspecFile.readAsStringSync();
    
    // Check if flutter_localizations is already present
    if (content.contains('flutter_localizations:')) {
      print('\u001b[32m✓ flutter_localizations dependency already exists\u001b[0m');
      return true;
    }
    
    print('\u001b[33m📦 Adding flutter_localizations dependency to pubspec.yaml...\u001b[0m');
    
    // Find the dependencies section
    final lines = content.split('\n');
    final dependenciesIndex = lines.indexWhere((line) => line.trim() == 'dependencies:');
    
    if (dependenciesIndex == -1) {
      print('\u001b[31mError: Could not find dependencies section in pubspec.yaml\u001b[0m');
      return false;
    }
    
    // Find where to insert flutter_localizations - should be right after dependencies:
    // but before the main flutter dependency for proper ordering
    int insertIndex = dependenciesIndex + 1;
    
    // Insert flutter_localizations dependency at the beginning of dependencies
    final indentation = '  '; // Use consistent 2-space indentation
    lines.insert(insertIndex, '${indentation}flutter_localizations:');
    lines.insert(insertIndex + 1, '$indentation  sdk: flutter');
    
    // Write back to file
    final newContent = lines.join('\n');
    pubspecFile.writeAsStringSync(newContent);
    
    print('\u001b[32m✓ Added flutter_localizations dependency to pubspec.yaml\u001b[0m');
    print('\u001b[36mℹ️  You may need to run "flutter pub get" to update dependencies\u001b[0m');
    
    return true;
  } catch (e) {
    print('\u001b[31mError adding flutter_localizations dependency: $e\u001b[0m');
    return false;
  }
}

  /// Helper function to find pubspec.yaml file
File? _findPubspecFile(String directoryPath) {
  // Normalize path using path package for cross-platform compatibility
  final normalizedPath = path.normalize(directoryPath);
  
  // Handle relative paths using path package for better cross-platform support
  final rootPath = normalizedPath.startsWith('lib${path.separator}') 
      ? normalizedPath.replaceFirst('lib${path.separator}', '') 
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
    while (currentDir.path != path.rootPrefix(currentDir.path) && currentDir.path.isNotEmpty) {
      final pubspec = File(path.join(currentDir.path, 'pubspec.yaml'));
      if (pubspec.existsSync()) {
        pubspecFile = pubspec;
        break;
      }
      currentDir = currentDir.parent;
    }
  }
  
  return pubspecFile;
}

/// Automatically setup complete Flutter localization configuration
/// This ensures the project has all necessary files and configurations
bool setupFlutterLocalization(String directoryPath, {String arbDir = 'lib/l10n', String templateFile = 'intl_en.arb'}) {
  try {
    print('\u001b[36m🔧 Setting up Flutter localization configuration...\u001b[0m');
    
    // 1. Ensure flutter_localizations dependency
    if (!ensureFlutterLocalizationsDependency(directoryPath)) {
      print('\u001b[31mFailed to add flutter_localizations dependency\u001b[0m');
      return false;
    }
    
    // 2. Add generate: true to pubspec.yaml if not present
    _ensureGenerateFlag(directoryPath);
    
    // 3. Create l10n.yaml configuration file
    _createL10nYaml(directoryPath, arbDir, templateFile);
    
    // 4. Create ARB directory if it doesn't exist
    _ensureArbDirectory(directoryPath, arbDir);
    
    // 5. Setup MaterialApp configuration automatically
    _setupMaterialAppConfiguration(directoryPath);
    
    // 6. Automatically run flutter commands to complete setup
    _runFlutterCommands(directoryPath);
    
    print('\u001b[32m✅ Flutter localization setup completed!\u001b[0m');
    
    return true;
  } catch (e) {
    print('\u001b[31mError setting up Flutter localization: $e\u001b[0m');
    return false;
  }
}

/// Automatically run Flutter commands for complete setup
void _runFlutterCommands(String directoryPath) {
  try {
    print('\u001b[36m🚀 Running Flutter commands to complete setup...\u001b[0m');
    
    // Check if Flutter is available
    final flutterVersionResult = Process.runSync(
      'flutter',
      ['--version'],
      workingDirectory: directoryPath,
    );
    
    if (flutterVersionResult.exitCode != 0) {
      print('\u001b[33mWarning: Flutter command not found or not in PATH. Manual steps required.\u001b[0m');
      print('\u001b[36mℹ️  Please run these commands manually in your project directory:\u001b[0m');
      print('\u001b[36m   - flutter pub get\u001b[0m');
      print('\u001b[36m   - flutter gen-l10n\u001b[0m');
      return;
    }
    
    // Check if pubspec.lock needs updating by comparing timestamps with pubspec.yaml
    final pubspecYamlFile = File(path.join(directoryPath, 'pubspec.yaml'));
    final pubspecLockFile = File(path.join(directoryPath, 'pubspec.lock'));
    bool needsPubGet = true;
    
    if (pubspecYamlFile.existsSync() && pubspecLockFile.existsSync()) {
      final yamlStat = pubspecYamlFile.statSync();
      final lockStat = pubspecLockFile.statSync();
      
      // If pubspec.lock is newer than pubspec.yaml, we don't need to run pub get
      if (lockStat.modified.isAfter(yamlStat.modified)) {
        print('\u001b[36mℹ️  pubspec.lock is up to date. Skipping flutter pub get.\u001b[0m');
        needsPubGet = false;
      }
    }
    
    // Run flutter pub get only if needed
    if (needsPubGet) {
      print('\u001b[33m📦 Running flutter pub get...\u001b[0m');
      final pubGetResult = Process.runSync(
        'flutter',
        ['pub', 'get'],
        workingDirectory: directoryPath,
      );
      
      if (pubGetResult.exitCode == 0) {
        print('\u001b[32m✓ flutter pub get completed successfully\u001b[0m');
      } else {
        final errorMessage = pubGetResult.stderr.toString().trim();
        print('\u001b[33mWarning: flutter pub get failed:\u001b[0m');
        if (errorMessage.contains('Could not resolve')) {
          print('\u001b[31m  - Dependency resolution error. Check your internet connection and pubspec.yaml file.\u001b[0m');
        } else if (errorMessage.contains('conflict')) {
          print('\u001b[31m  - Dependency conflict detected. There may be incompatible package versions.\u001b[0m');
        } else {
          print('\u001b[31m  - Error: ${errorMessage.split('\n').take(3).join('\n  ')}\u001b[0m');
        }
        print('\u001b[36mℹ️  Please run "flutter pub get" manually to resolve the issue\u001b[0m');
      }
    }
    
    // Create a basic template ARB file if none exists
    final arbDir = _createBasicTemplateArbFile(directoryPath);
    bool arbFilesExist = false;
    
    // Check if ARB files exist
    if (arbDir != null) {
      final arbFiles = arbDir.listSync().where((e) => e is File && e.path.endsWith('.arb')).toList();
      arbFilesExist = arbFiles.isNotEmpty;
      
      if (!arbFilesExist) {
        print('\u001b[33m⚠️  No ARB files found in ${arbDir.path}\u001b[0m');
        print('\u001b[36mℹ️  Creating a sample ARB file with common strings...\u001b[0m');
        
        // Create a sample ARB file
        final sampleFile = File(path.join(arbDir.path, 'intl_en.arb'));
        final sampleContent = '''{
  "@@locale": "en",
  "appTitle": "My App",
  "@appTitle": {
    "description": "The title of the application"
  },
  "welcome": "Welcome",
  "@welcome": {
    "description": "Welcome message"
  },
  "hello": "Hello",
  "@hello": {
    "description": "Hello greeting"
  },
  "cancel": "Cancel",
  "@cancel": {
    "description": "Cancel button label"
  },
  "save": "Save",
  "@save": {
    "description": "Save button label"
  }
}''';
        sampleFile.writeAsStringSync(sampleContent);
        print('\u001b[32m✓ Created sample ARB file at ${sampleFile.path}\u001b[0m');
        arbFilesExist = true;
      }
    }
    
    // Run flutter gen-l10n if l10n.yaml exists and ARB files are available
    final l10nFile = File(path.join(directoryPath, 'l10n.yaml'));
    if (l10nFile.existsSync() && arbFilesExist) {
      print('\u001b[33m🌍 Running flutter gen-l10n...\u001b[0m');
      final genL10nResult = Process.runSync(
        'flutter',
        ['gen-l10n'],
        workingDirectory: directoryPath,
      );
      
      if (genL10nResult.exitCode == 0) {
        print('\u001b[32m✓ flutter gen-l10n completed successfully\u001b[0m');
        print('\u001b[36mℹ️  Localization files have been generated. You can now use AppLocalizations.of(context) in your code.\u001b[0m');
      } else {
        final errorMessage = genL10nResult.stderr.toString().trim();
        print('\u001b[33mWarning: flutter gen-l10n failed:\u001b[0m');
        
        if (errorMessage.contains('No ARB files found')) {
          print('\u001b[31m  - No ARB files found in the specified directory.\u001b[0m');
          print('\u001b[36mℹ️  Make sure to create at least one ARB file in the specified arb-dir before running gen-l10n\u001b[0m');
        } else if (errorMessage.contains('invalid format')) {
          print('\u001b[31m  - ARB file format error. Check that your ARB files are valid JSON.\u001b[0m');
        } else {
          print('\u001b[31m  - Error: ${errorMessage.split('\n').take(3).join('\n  ')}\u001b[0m');
        }
        
        print('\u001b[36mℹ️  Next steps:\u001b[0m');
        print('\u001b[36m   1. Create or fix your ARB file(s) in lib/l10n/\u001b[0m');
        print('\u001b[36m   2. Run "flutter gen-l10n" manually\u001b[0m');
      }
    } else if (!l10nFile.existsSync()) {
      print('\u001b[33m⚠️  l10n.yaml file not found\u001b[0m');
      print('\u001b[36mℹ️  To complete setup, create l10n.yaml file and run "flutter gen-l10n"\u001b[0m');
    }
    
    print('\u001b[36m\n✨ Setup completed! Here are your next steps:\u001b[0m');
    print('\u001b[36m 1. Edit your ARB files in lib/l10n/ to add your translations\u001b[0m');
    print('\u001b[36m 2. Run "flutter gen-l10n" after updating ARB files\u001b[0m');
    print('\u001b[36m 3. Use AppLocalizations.of(context)!.keyName in your code\u001b[0m');
    print('\u001b[36m 4. For more languages, create additional ARB files like intl_es.arb\u001b[0m');
    
  } catch (e) {
    print('\u001b[33mWarning: Error running Flutter commands: $e\u001b[0m');
    print('\u001b[36mℹ️  Please run these commands manually in your project directory:\u001b[0m');
    print('\u001b[36m   - flutter pub get\u001b[0m');
    print('\u001b[36m   - flutter gen-l10n\u001b[0m');
  }
}
/// Create a basic template ARB file with common strings if none exists
/// Returns the ARB directory (whether it exists or was created)
Directory? _createBasicTemplateArbFile(String directoryPath) {
  try {
    final arbDir = Directory(path.join(directoryPath, 'lib', 'l10n'));
    if (!arbDir.existsSync()) {
      return null;
    }
    
    final templateFile = File(path.join(arbDir.path, 'intl_en.arb'));
    if (templateFile.existsSync()) {
      print('\u001b[32m✓ Template ARB file already exists\u001b[0m');
      return arbDir;
    }
    
    print('\u001b[33m📝 Creating basic template ARB file...\u001b[0m');
    
    final basicContent = '''{
  "@@locale": "en",
  "appTitle": "My App",
  "@appTitle": {
    "description": "The title of the application"
  },
  "welcome": "Welcome",
  "@welcome": {
    "description": "Welcome message"
  },
  "hello": "Hello",
  "@hello": {
    "description": "Hello greeting"
  },
  "cancel": "Cancel",
  "@cancel": {
    "description": "Cancel button label"
  },
  "save": "Save",
  "@save": {
    "description": "Save button label"
  }
}''';
    
    templateFile.writeAsStringSync(basicContent);
    print('\u001b[32m✓ Created basic template ARB file at ${templateFile.path}\u001b[0m');
    return arbDir;
  } catch (e) {
    print('\u001b[33mWarning: Could not create template ARB file: $e\u001b[0m');
    return null;
  }
}

/// Ensure generate: true flag exists in pubspec.yaml
void _ensureGenerateFlag(String directoryPath) {
  try {
    final pubspecFile = _findPubspecFile(directoryPath);
    if (pubspecFile == null) return;

    final content = pubspecFile.readAsStringSync();
    
    // Check if generate flag already exists in the flutter section
    if (RegExp(r'flutter:\s*[\s\S]*?generate:\s*true').hasMatch(content)) {
      return;
    }
    
    print('\u001b[33m📝 Adding generate: true to pubspec.yaml...\u001b[0m');
    
    final lines = content.split('\n');
    
    // Find the flutter section (not the dependency) - must be at start of line
    int flutterIndex = -1;
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      // Look for flutter: at the beginning of a line (top-level section)
      if (line.trim() == 'flutter:' && !line.startsWith('  ') && !line.startsWith('\t')) {
        flutterIndex = i;
        break;
      }
    }
    
    if (flutterIndex != -1) {
      // Find the last property in the flutter section or the first line after flutter:
      int insertIndex = flutterIndex + 1;
      
      // Find the end of the flutter section by looking for either:
      // 1. A line that's not indented (next top-level section)
      // 2. End of file
      for (int i = flutterIndex + 1; i < lines.length; i++) {
        final line = lines[i];
        
        // If this is a top-level section (not indented and ends with :), we've reached the end
        if (line.trim().isNotEmpty && !line.startsWith('  ') && !line.startsWith('\t') && line.trim().endsWith(':')) {
          insertIndex = i;
          break;
        }
        
        // If this is a property in the flutter section, update the insert position
        if (line.trim().isNotEmpty && (line.startsWith('  ') || line.startsWith('\t'))) {
          insertIndex = i + 1;
        }
        
        // If we've reached the end of the file
        if (i == lines.length - 1) {
          insertIndex = lines.length;
          break;
        }
      }
      
      // Insert generate: true with proper indentation
      lines.insert(insertIndex, '  generate: true');
      
      pubspecFile.writeAsStringSync(lines.join('\n'));
      print('\u001b[32m✓ Added generate: true to pubspec.yaml\u001b[0m');
    }
  } catch (e) {
    print('\u001b[33mWarning: Could not add generate flag: $e\u001b[0m');
  }
}

/// Create l10n.yaml configuration file
void _createL10nYaml(String directoryPath, String arbDir, String templateFile) {
  try {
    final l10nFile = File(path.join(directoryPath, 'l10n.yaml'));
    
    if (l10nFile.existsSync()) {
      print('\u001b[32m✓ l10n.yaml already exists\u001b[0m');
      return;
    }
    
    print('\u001b[33m📝 Creating l10n.yaml configuration...\u001b[0m');
    
    final l10nConfig = '''arb-dir: $arbDir
template-arb-file: $templateFile
output-localization-file: app_localizations.dart
output-dir: lib/generated/l10n
''';
    
    l10nFile.writeAsStringSync(l10nConfig);
    print('\u001b[32m✓ Created l10n.yaml\u001b[0m');
  } catch (e) {
    print('\u001b[33mWarning: Could not create l10n.yaml: $e\u001b[0m');
  }
}

/// Ensure ARB directory exists
void _ensureArbDirectory(String directoryPath, String arbDir) {
  try {
    final arbDirectory = Directory(path.join(directoryPath, arbDir));
    
    if (!arbDirectory.existsSync()) {
      print('\u001b[33m📁 Creating ARB directory: $arbDir...\u001b[0m');
      arbDirectory.createSync(recursive: true);
      print('\u001b[32m✓ Created ARB directory\u001b[0m');
    } else {
      print('\u001b[32m✓ ARB directory already exists\u001b[0m');
    }
  } catch (e) {
    print('\u001b[33mWarning: Could not create ARB directory: $e\u001b[0m');
  }
}

/// Automatically setup MaterialApp/GetMaterialApp localization configuration
void _setupMaterialAppConfiguration(String directoryPath) {
  try {
    final mainFile = File(path.join(directoryPath, 'lib', 'main.dart'));
    
    if (!mainFile.existsSync()) {
      print('\u001b[33mWarning: main.dart not found\u001b[0m');
      return;
    }
    
    final content = mainFile.readAsStringSync();
    
    // Check for existing localization configuration
    bool hasLocalizationDelegates = content.contains('localizationsDelegates');
    bool hasAppLocalizations = content.contains('AppLocalizations.delegate');
    bool hasSupportedLocales = content.contains('supportedLocales');
    
    if (hasLocalizationDelegates && hasAppLocalizations && hasSupportedLocales) {
      print('\u001b[32m✓ App localization configuration already exists\u001b[0m');
      return;
    }
    
    print('\u001b[33m🔧 Setting up App localization configuration...\u001b[0m');
    
    // 1. Add required imports first
    String updatedContent = _addRequiredImports(content);
    
    // 2. Determine app type and update configuration
    final isGetMaterialApp = content.contains('GetMaterialApp');
    final appType = isGetMaterialApp ? 'GetMaterialApp' : 'MaterialApp';
    print('\u001b[36mℹ️  Found $appType widget in main.dart\u001b[0m');
    
    // 3. Add localization configuration preserving existing config
    updatedContent = _addMaterialAppConfiguration(updatedContent, isGetMaterialApp);
    
    // Write back to file only if changes were made
    if (updatedContent != content) {
      mainFile.writeAsStringSync(updatedContent);
      print('\u001b[32m✓ $appType localization configuration updated successfully\u001b[0m');
    } else {
      print('\u001b[36mℹ️  No changes needed to $appType configuration\u001b[0m');
    }
  } catch (e) {
    print('\u001b[33mWarning: Could not setup App configuration: $e\u001b[0m');
    print('\u001b[36mℹ️  Please update your MaterialApp/GetMaterialApp configuration manually\u001b[0m');
  }
}

/// Add required imports for localization
String _addRequiredImports(String content) {
  final imports = [
    "import 'package:flutter_localizations/flutter_localizations.dart';",
    "import 'package:flutter_gen/gen_l10n/app_localizations.dart';",
  ];
  
  String updatedContent = content;
  
  for (final import in imports) {
    if (!updatedContent.contains(import)) {
      // Find the last import statement
      final lines = updatedContent.split('\n');
      int lastImportIndex = -1;
      
      for (int i = 0; i < lines.length; i++) {
        if (lines[i].trim().startsWith('import ')) {
          lastImportIndex = i;
        }
      }
      
      if (lastImportIndex != -1) {
        lines.insert(lastImportIndex + 1, import);
        updatedContent = lines.join('\n');
      }
    }
  }
  
  return updatedContent;
}

/// Add MaterialApp/GetMaterialApp localization configuration while preserving existing settings
String _addMaterialAppConfiguration(String content, bool isGetMaterialApp) {
  // Find MaterialApp or GetMaterialApp
  final materialAppRegex = RegExp(isGetMaterialApp ? r'GetMaterialApp\s*\(' : r'MaterialApp\s*\(');
  final match = materialAppRegex.firstMatch(content);
  
  if (match == null) {
    print('\u001b[33mWarning: ${isGetMaterialApp ? "GetMaterialApp" : "MaterialApp"} not found in main.dart\u001b[0m');
    return content;
  }
  
  // Extract existing configuration
  final startPos = match.end;
  int bracketCount = 1;
  int insertionPoint = -1;
  String existingConfig = '';
  
  // Scan through constructor to find insertion point and existing config
  for (int i = startPos; i < content.length && bracketCount > 0; i++) {
    final char = content[i];
    if (char == '(') {
      bracketCount++;
    } else if (char == ')') {
      bracketCount--;
      if (bracketCount == 0) {
        insertionPoint = i;
        existingConfig = content.substring(startPos, i).trim();
        break;
      }
    }
  }
  
  if (insertionPoint == -1) {
    print('\u001b[33mWarning: Could not find app widget closing bracket\u001b[0m');
    return content;
  }
  
  // Determine what configuration is missing
  bool needsLocalizationDelegates = !existingConfig.contains('localizationsDelegates');
  bool needsSupportedLocales = !existingConfig.contains('supportedLocales');
  
  if (!needsLocalizationDelegates && !needsSupportedLocales) {
    return content;
  }
  
  // Build new configuration preserving existing settings
  String localizationConfig = '';
  bool needsComma = existingConfig.trim().isNotEmpty && !existingConfig.trimRight().endsWith(',');
  
  if (needsLocalizationDelegates) {
    localizationConfig += '''${needsComma ? ',' : ''}
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],''';
  }
  
  if (needsSupportedLocales) {
    localizationConfig += '''${needsComma || localizationConfig.isNotEmpty ? ',' : ''}
      supportedLocales: const [
        Locale('en', ''), // English
      ],''';
  }
  
  // Insert configuration preserving indentation
  final currentIndentation = RegExp(r'^\s*').firstMatch(existingConfig)?.group(0) ?? '';
  final indentedConfig = localizationConfig.split('\n').map((line) => 
    line.isEmpty ? line : currentIndentation + line).join('\n');
  
  return content.substring(0, insertionPoint) + indentedConfig + content.substring(insertionPoint);
}
