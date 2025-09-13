// src/commands/preferences_command.dart
part of '../cli_runner.dart';

class PreferencesCommand extends Command {
  @override
  final name = 'preferences';

  @override
  final description = 'View and manage user preferences';

  PreferencesCommand() {
    argParser.addFlag('reset',
        abbr: 'r',
        defaultsTo: false,
        help: 'Reset preferences to default values');
    argParser.addFlag('view',
        abbr: 'v', defaultsTo: true, help: 'View current preferences');
    argParser.addFlag('edit',
        abbr: 'e', defaultsTo: false, help: 'Edit preferences');
    argParser.addFlag('patterns',
        abbr: 'p', defaultsTo: false, help: 'Manage exclude patterns');
  }

  @override
  void run() async {
    final reset = argResults!['reset'] as bool;
    final view = argResults!['view'] as bool;
    final edit = argResults!['edit'] as bool;
    final patterns = argResults!['patterns'] as bool;

    if (reset) {
      _resetPreferences();
      return;
    }

    if (edit) {
      await _editPreferences();
      return;
    }

    if (patterns) {
      await _manageExcludePatterns();
      return;
    }

    if (view) {
      _viewPreferences();
    }
  }

  void _resetPreferences() {
    stdout.write(
        'Are you sure you want to reset all preferences to default values? (y/N): ');
    final response = stdin.readLineSync()?.toLowerCase() ?? 'n';

    if (response == 'y' || response == 'yes') {
      try {
        final prefsFile =
            File(PreferencesManager.loadPreferences()['prefsPath'] as String);
        if (prefsFile.existsSync()) {
          prefsFile.deleteSync();
        }
        print('\n\u001b[32mPreferences reset to default values\u001b[0m');

        // Show the default preferences
        _viewPreferences();
      } catch (e) {
        stderr.writeln('\u001b[31mError resetting preferences: $e\u001b[0m');
        exit(1);
      }
    } else {
      print('Operation cancelled.');
    }
  }

  Future<void> _editPreferences() async {
    final currentPrefs = PreferencesManager.loadPreferences();

    // Key format
    stdout.write('\nSelect key format:\n');
    stdout.write('1. snake_case (example: hello_world)\n');
    stdout.write('2. camelCase (example: helloWorld)\n');
    stdout.write('3. dot.case (example: hello.world)\n');
    stdout.write('Select (1-3) [default: 1]: ');

    final prefs = Map<String, dynamic>.from(currentPrefs);
    final formatChoice = stdin.readLineSync() ?? '1';
    switch (formatChoice) {
      case '2':
        prefs['keyFormat'] = 'camelCase';
        break;
      case '3':
        prefs['keyFormat'] = 'dot.case';
        break;
      default:
        prefs['keyFormat'] = 'snake_case';
    }

    // Output directory
    stdout.write('\nOutput directory [${currentPrefs['outputDir']}]: ');
    final outDir = stdin.readLineSync();
    if (outDir != null && outDir.isNotEmpty) {
      prefs['outputDir'] = outDir;
    }

    // Ask if user wants to manage exclude patterns
    stdout.write('\nDo you want to manage exclude patterns? (y/N): ');
    final managePatterns = stdin.readLineSync()?.toLowerCase() ?? 'n';

    if (managePatterns == 'y' || managePatterns == 'yes') {
      // Save current preferences before pattern management
      PreferencesManager.savePreferences(prefs);
      await _manageExcludePatterns();
    } else {
      // Save the preferences
      PreferencesManager.savePreferences(prefs);
    }

    print('\n\u001b[32mPreferences updated:\u001b[0m');
    _displayPreferences(prefs);
  }

  void _viewPreferences() {
    final prefs = PreferencesManager.loadPreferences();
    print('\n\u001b[36mCurrent preferences:\u001b[0m');
    _displayPreferences(prefs);

    final prefsFile = File(prefs['prefsPath'] ?? '~/.intl_cli_prefs.json');
    print('\nPreferences are stored at: \u001b[33m${prefsFile.path}\u001b[0m');
    print(
        'To edit preferences, run: \u001b[33mintl_cli preferences --edit\u001b[0m');
    print(
        'To manage exclude patterns, run: \u001b[33mintl_cli preferences --patterns\u001b[0m');
    print(
        'Documentation for exclude patterns: \u001b[33mlib/src/docs/exclude_patterns.md\u001b[0m');
  }

  void _displayPreferences(Map<String, dynamic> prefs) {
    // Display basic preferences
    print('- Key format: \u001b[32m${prefs['keyFormat']}\u001b[0m');
    print('- Output directory: \u001b[32m${prefs['outputDir']}\u001b[0m');

    // Display exclude patterns
    if (prefs.containsKey('excludePatterns') &&
        prefs['excludePatterns'] is List) {
      final patterns = (prefs['excludePatterns'] as List).cast<String>();
      print('- Exclude patterns:');
      for (var i = 0; i < patterns.length; i++) {
        print('  ${i + 1}. \u001b[32m${patterns[i]}\u001b[0m');
      }
    }

    // Display last used date
    if (prefs.containsKey('lastUsed')) {
      try {
        final lastUsed = DateTime.parse(prefs['lastUsed']);
        final now = DateTime.now();
        final difference = now.difference(lastUsed);

        String timeAgo;
        if (difference.inDays > 0) {
          timeAgo = '${difference.inDays} days ago';
        } else if (difference.inHours > 0) {
          timeAgo = '${difference.inHours} hours ago';
        } else if (difference.inMinutes > 0) {
          timeAgo = '${difference.inMinutes} minutes ago';
        } else {
          timeAgo = 'just now';
        }

        print('- Last used: \u001b[32m$timeAgo\u001b[0m');
      } catch (e) {
        // Ignore date parsing errors
      }
    }
  }

  Future<void> _manageExcludePatterns() async {
    final prefs = PreferencesManager.loadPreferences();
    List<String> patterns = [];

    if (prefs.containsKey('excludePatterns') &&
        prefs['excludePatterns'] is List) {
      patterns = (prefs['excludePatterns'] as List).cast<String>();
    }

    // List of common pattern categories to offer to the user
    final patternCategories = {
      'URLs and Web': [
        r'^https?://', // URLs with http/https
        r'^www\.', // Web addresses starting with www
        r'^\w+://\w+', // URI schemes
      ],
      'Files and Assets': [
        r'^assets/', // Asset paths
        r'^[\w-]+\.(?:png|jpg|jpeg|svg|gif|webp|json|arb|md)$', // Image and data files
        r'^[\w/\-\.]+$', // Simple file paths with no spaces
        r'^\w+\.', // Simple file extensions
      ],
      'Code Elements': [
        r'^[A-Z][a-zA-Z0-9]*\.[A-Za-z0-9]+', // Class references like Widget.property
        r'^@\w+', // Annotations
        r'^_\w+$', // Private variables
      ],
      'Formatting': [
        r'^<[^>]+>$', // XML/HTML tags
        r'^#[0-9a-fA-F]{3,8}$', // Color hex codes
      ],
      'Numbers and IDs': [
        r'^[\d,.]+$', // Numbers and simple formatted numbers
        r'^\d+\.\d+\.\d+$', // Version numbers
        r'^\w{8}-\w{4}-\w{4}-\w{4}-\w{12}$', // UUIDs
      ],
    };

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
    print('  6. View pattern documentation');
    print('  7. Back to preferences');

    stdout.write('\nSelect an option (1-7): ');
    final option = stdin.readLineSync() ?? '7';

    switch (option) {
      case '1':
        stdout.write('\nEnter a new exclude pattern (regex): ');
        final newPattern = stdin.readLineSync();
        if (newPattern != null && newPattern.isNotEmpty) {
          // Validate the pattern is a valid regex
          try {
            RegExp(newPattern);

            // Check if pattern already exists
            if (patterns.contains(newPattern)) {
              print('\n\u001b[33mPattern already exists in the list\u001b[0m');
            } else {
              patterns.add(newPattern);
              prefs['excludePatterns'] = patterns;
              PreferencesManager.savePreferences(prefs);
              print('\n\u001b[32mPattern added successfully\u001b[0m');
            }
          } catch (e) {
            print('\n\u001b[31mInvalid regex pattern: $e\u001b[0m');
          }
        }
        await _manageExcludePatterns(); // Return to the pattern management menu
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
                PreferencesManager.savePreferences(prefs);
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
                      PreferencesManager.savePreferences(prefs);
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
        await _manageExcludePatterns(); // Return to pattern management
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
                PreferencesManager.savePreferences(prefs);
                print('\n\u001b[32mRemoved pattern: $removedPattern\u001b[0m');
              } else {
                print('\n\u001b[31mInvalid pattern number\u001b[0m');
              }
            } catch (e) {
              print('\n\u001b[31mInvalid input: $e\u001b[0m');
            }
          }
        }
        await _manageExcludePatterns(); // Return to the pattern management menu
        break;

      case '4':
        // Test pattern against sample text
        if (patterns.isEmpty) {
          print('\n\u001b[33mNo patterns to test.\u001b[0m');
        } else {
          stdout
              .write('\nEnter pattern number to test (1-${patterns.length}): ');
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
        await _manageExcludePatterns(); // Return to pattern management
        break;

      case '5':
        stdout.write('\nReset to default exclude patterns? (y/N): ');
        final confirm = stdin.readLineSync()?.toLowerCase() ?? 'n';
        if (confirm == 'y' || confirm == 'yes') {
          // Default patterns
          final defaultPatterns = [
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
          ];

          prefs['excludePatterns'] = defaultPatterns;
          PreferencesManager.savePreferences(prefs);
          print('\n\u001b[32mExclude patterns reset to defaults\u001b[0m');
        }
        await _manageExcludePatterns(); // Return to pattern management
        break;

      case '6':
        print('\n\u001b[36mExclude Patterns Documentation\u001b[0m');
        print('\nThe documentation for exclude patterns is available at:');
        print('\u001b[33mlib/src/docs/exclude_patterns.md\u001b[0m');
        print('\nThis documentation includes:');
        print('- Explanation of exclude patterns and their purpose');
        print('- Default patterns included with the tool');
        print('- Examples of custom patterns for different scenarios');
        print('- Tips for creating effective patterns');
        print('- Best practices for pattern management');
        print('\nPress Enter to return to pattern management...');
        stdin.readLineSync();
        await _manageExcludePatterns(); // Return to pattern management
        break;

      case '7':
      default:
        // Go back to preferences view
        _viewPreferences();
        break;
    }
  }
}
