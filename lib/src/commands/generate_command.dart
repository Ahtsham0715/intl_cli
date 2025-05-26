// src/commands/generate_command.dart
part of '../cli_runner.dart';

class GenerateCommand extends Command {
  @override
  final name = 'generate';
  
  @override
  final description = 'Generate ARB files from hardcoded strings';
  
  @override
  final String invocation = 'intl_cli generate [directory] [options]';
  
  GenerateCommand() {
    argParser.addOption('dir',
        abbr: 'd',
        help: 'The directory to scan (defaults to "lib" if not specified)');
    argParser.addOption('output',
        abbr: 'o',
        help: 'Output ARB file path (defaults to saved preferences)');
    argParser.addOption('key-format',
        abbr: 'k',
        allowed: ['snake_case', 'camelCase', 'dot.case'],
        help: 'Key naming convention: snake_case, camelCase, dot.case (defaults to saved preferences)');
    argParser.addOption('scope',
        help: 'Feature/module name for scoped ARB file (e.g., login -> lib/l10n/feature_login.arb)');
    argParser.addFlag('confirm',
        abbr: 'c',
        defaultsTo: false,
        help: 'Skip confirmation prompt');
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

    var output = argResults!['output'] as String?;
    var keyFormat = argResults!['key-format'] as String?;
    final scope = argResults!['scope'] as String?;
    final skipConfirmation = argResults!['confirm'] as bool;
    
    // Load user preferences if options weren't explicitly provided
    bool usedSavedPrefs = false;
    if (keyFormat == null || output == null) {
      final prefs = await PreferencesManager.promptForPreferences();
      
      // Only use the saved preferences if not explicitly provided
      keyFormat ??= prefs['keyFormat'] as String;
      usedSavedPrefs = true;
      
      if (output == null) {
        final baseDir = prefs['outputDir'] as String;
        // Hard-code English locale since we're only generating English for now
        output = '$baseDir/intl_en.arb';
        usedSavedPrefs = true;
      }
      
      if (usedSavedPrefs) {
        print('\n\u001b[36mUsing preferences:\u001b[0m');
        print('- Key format: \u001b[32m$keyFormat\u001b[0m');
        print('- Output file: \u001b[32m$output\u001b[0m\n');
      }
      
      // Save the current values as preferences
      prefs['keyFormat'] = keyFormat;
      prefs['outputDir'] = path.dirname(output);
      PreferencesManager.savePreferences(prefs);
    }
    
    // Ensure values are not null at this point
    final finalOutput = output;
    final finalKeyFormat = keyFormat;
    
    String arbPath = finalOutput;
    if (scope != null && scope.isNotEmpty) {
      final base = finalOutput.replaceAll(RegExp(r'intl_[a-z]+.arb'), 'feature_$scope.arb');
      arbPath = base;
    }
    
    // Declare this at a higher scope so it's available in the error handling blocks
    Map<String, List<String>> extractedStrings = {};
    
    try {
      print('Scanning directory: $dir');
      extractedStrings = intl_cli.scanDirectory(dir);
      
      if (extractedStrings.isEmpty) {
        print('No translatable strings found in $dir. Nothing to generate.');
        return;
      }
      
      int totalStrings = 0;
      extractedStrings.forEach((file, strings) => totalStrings += strings.length);
      print('\nFound $totalStrings translatable strings in \u001b[32m${extractedStrings.length}\u001b[0m files.');
      
      // If not explicitly confirmed, ask for confirmation
      if (!skipConfirmation) {
        stdout.write('\nThis will generate an ARB file with $totalStrings strings at $arbPath. Continue? (y/N): ');
        final response = stdin.readLineSync()?.toLowerCase() ?? '';
        if (response != 'y' && response != 'yes') {
          print('ARB generation cancelled.');
          return;
        }
      }
      
      try {
        // Generate the ARB file
        intl_cli.generateArbFile(extractedStrings, arbPath, keyFormat: finalKeyFormat);
        print('\n\u001b[32m✓ ARB file generated successfully at $arbPath\u001b[0m');
      } catch (e) {
        stderr.writeln('\u001b[31mError creating ARB file: $e\u001b[0m');
        stderr.writeln('Creating directory structure and trying again...');
        
        // Ensure directory exists
        final directory = Directory(path.dirname(arbPath));
        if (!directory.existsSync()) {
          directory.createSync(recursive: true);
        }
        
        // Try again after creating directory
        intl_cli.generateArbFile(extractedStrings, arbPath, keyFormat: finalKeyFormat);
        print('\n\u001b[32m✓ ARB file generated successfully at $arbPath\u001b[0m');
      }
    } on FileSystemException catch (e) {
      stderr.writeln('\u001b[31mError: ${e.message}: ${e.path}\u001b[0m');
      // Try to recover by creating the directory
      if (e.message.contains('Directory not found') || e.message.contains('No such file')) {
        stderr.writeln('Creating directory and trying again...');
        try {
          // Get the directory path from the error
          final dirPath = e.path ?? arbPath;
          final dir = Directory(path.dirname(dirPath));
          dir.createSync(recursive: true);
          
          // Try the operation again
          if (dirPath == dir.path) {
            // If the scan directory was the problem, scan again
            final newExtractedStrings = intl_cli.scanDirectory(dir.path);
            intl_cli.generateArbFile(newExtractedStrings, arbPath, keyFormat: finalKeyFormat);
          } else {
            // Otherwise, use the existing extracted strings but with the new directory
            intl_cli.generateArbFile(extractedStrings, arbPath, keyFormat: finalKeyFormat);
          }
          print('\n\u001b[32m✓ ARB file generated successfully at $arbPath\u001b[0m');
        } catch (innerError) {
          stderr.writeln('\u001b[31mFailed to recover: $innerError\u001b[0m');
          exit(2);
        }
      } else {
        exit(2);
      }
    } catch (e) {
      stderr.writeln('\u001b[31mUnexpected error: $e\u001b[0m');
      exit(1);
    }
  }
}
