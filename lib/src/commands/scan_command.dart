// src/commands/scan_command.dart
part of '../cli_runner.dart';

class ScanCommand extends Command {
  @override
  final name = 'scan';
  
  @override
  final description = 'Scan project for hardcoded strings that can be internationalized';
  
  @override
  final String invocation = 'intl_cli scan [directory] [options]';
  
  ScanCommand() {
    argParser.addOption('dir',
        abbr: 'd',
        help: 'The directory to scan (defaults to "lib" if not specified)');
    argParser.addFlag('verbose',
        abbr: 'v',
        help: 'Display detailed information about found strings');
    argParser.addFlag('use-preferences',
        abbr: 'p',
        defaultsTo: true,
        help: 'Use saved preferences for exclude patterns');
  }
  
  @override
  void run() async {
    // Determine the directory to scan - check positional args first, then --dir flag
    var dir = argResults!.rest.isNotEmpty ? argResults!.rest.first : argResults!['dir'] as String?;
    
    if (dir == null || dir.isEmpty) {
      // Default to 'lib' if no directory specified
      dir = 'lib';
      print('No directory specified, defaulting to: \u001b[32m$dir\u001b[0m\n');
    }
    
    // Validate directory exists
    if (!Directory(dir).existsSync()) {
      print('\u001b[31mError: Directory "$dir" does not exist.\u001b[0m');
      exit(1);
    }

    final verbose = argResults!['verbose'] as bool;
    final usePrefs = argResults!['use-preferences'] as bool;
    
    List<String>? excludePatterns;
    
    // Use saved preferences if requested
    if (usePrefs) {
      final prefs = await PreferencesManager.promptForPreferences();
      if (prefs.containsKey('excludePatterns')) {
        final patterns = prefs['excludePatterns'];
        if (patterns is List) {
          excludePatterns = patterns.cast<String>();
          print('\n\u001b[36mUsing exclude patterns from preferences:\u001b[0m');
          
          // Group patterns by type for better readability
          final patternTypes = {
            'URLs and Web': [r'^https?://', r'^www\.', r'^\w+://\w+'],
            'Files and Assets': [r'^assets/', r'^[\w-]+\.(?:png|jpg|jpeg|svg|gif|webp|json|arb|md)$', r'^[\w/\-\.]+$', r'^\w+\.'],
            'Code Elements': [r'^[A-Z][a-zA-Z0-9]*\.[A-Za-z0-9]+', r'^@\w+', r'^_\w+$'],
            'Formatting': [r'^<[^>]+>$', r'^#[0-9a-fA-F]{3,8}$'],
            'Numbers and IDs': [r'^[\d,.]+$', r'^\d+\.\d+\.\d+$', r'^\w{8}-\w{4}-\w{4}-\w{4}-\w{12}$'],
            'Other': [],
          };
          
          // Categorize patterns
          final categorizedPatterns = <String, List<String>>{};
          for (final key in patternTypes.keys) {
            categorizedPatterns[key] = [];
          }
          
          for (final pattern in excludePatterns) {
            bool found = false;
            for (final type in patternTypes.keys) {
              if (patternTypes[type]!.contains(pattern)) {
                categorizedPatterns[type]!.add(pattern);
                found = true;
                break;
              }
            }
            if (!found) {
              categorizedPatterns['Other']!.add(pattern);
            }
          }
          
          // Display categorized patterns
          for (final type in categorizedPatterns.keys) {
            final typePatterns = categorizedPatterns[type]!;
            if (typePatterns.isNotEmpty) {
              print('  \u001b[33m$type:\u001b[0m');
              for (var i = 0; i < typePatterns.length; i++) {
                print('    - \u001b[32m${typePatterns[i]}\u001b[0m');
              }
            }
          }
          
          print('');
        }
      }
    }
    try {
      final extractedStrings = intl_cli.scanDirectory(dir, excludePatterns: excludePatterns);
      if (extractedStrings.isEmpty) {
        print('No translatable strings found in $dir.');
        return;
      }
      int totalStrings = 0;
      extractedStrings.forEach((file, strings) => totalStrings += strings.length);
      
      // Create a non-null variable for string operations
      final nonNullDir = dir;
      
      print('\nFound $totalStrings translatable strings in \u001b[32m${extractedStrings.length}\u001b[0m files:');
      if (verbose) {
        extractedStrings.forEach((file, strings) {
          final shortPath = file.replaceAll(nonNullDir, '');
          print('\n\u001b[36m$shortPath\u001b[0m:');
          for (var i = 0; i < strings.length; i++) {
            print('  ${i + 1}. "\u001b[33m${strings[i]}\u001b[0m"');
          }
        });
      } else {
        for (final file in extractedStrings.keys) {
          final shortPath = file.replaceAll(nonNullDir, '');
          print('- \u001b[36m$shortPath\u001b[0m (${extractedStrings[file]!.length} strings)');
        }
      }
    } on FileSystemException catch (e) {
      stderr.writeln('\u001b[31mError: Directory not found: ${e.path}\u001b[0m');
      stderr.writeln('Please make sure the directory exists and try again.');
      exit(2);
    } catch (e) {
      stderr.writeln('\u001b[31mUnexpected error: $e\u001b[0m');
      exit(1);
    }
  }
}
