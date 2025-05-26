// src/commands/process_all_command.dart
part of '../cli_runner.dart';

class InternationalizeCommand extends Command<void> {
  @override
  final String name = 'internationalize';
  
  @override
  final String description = 'Complete internationalization workflow: scan, extract strings, refactor code, and generate ARB files';
  
  @override
  List<String> get aliases => ['i18n'];
  
  @override
  final String invocation = 'intl_cli internationalize [directory] [options]';
  
  InternationalizeCommand() {
    argParser.addOption('dir',
        abbr: 'd',
        help: 'The root directory to process (defaults to "lib" if not specified)');
    argParser.addOption('output',
        abbr: 'o',
        help: 'Output ARB file path (defaults to saved preferences)');
    argParser.addOption('key-format',
        abbr: 'k',
        allowed: ['snake_case', 'camelCase', 'dot.case'],
        help: 'Key naming convention: snake_case, camelCase, dot.case (defaults to saved preferences)');
    argParser.addFlag('use-app-localizations',
        abbr: 'a',
        defaultsTo: true,
        help: 'Use AppLocalizations.of(context) pattern');
    argParser.addFlag('confirm',
        abbr: 'c',
        defaultsTo: false,
        help: 'Skip confirmation prompt');
  }
  
  @override
  Future<void> run() async {
    // Determine the directory to process - check positional args first, then --dir flag
    var dir = argResults!.rest.isNotEmpty ? argResults!.rest.first : argResults!['dir'] as String?;
    
    if (dir == null || dir.isEmpty) {
      // Default to 'lib' if no directory specified
      dir = 'lib';
      print('No directory specified, defaulting to: \u001b[32m$dir\u001b[0m');
    }
    
    // Validate directory exists
    if (!Directory(dir).existsSync()) {
      print('\u001b[31mError: Directory "$dir" does not exist.\u001b[0m');
      exit(1);
    }

    var output = argResults!['output'] as String?;
    var keyFormat = argResults!['key-format'] as String?;
    var useAppLocalizations = argResults!['use-app-localizations'] as bool;
    final skipConfirmation = argResults!['confirm'] as bool;

    // Load user preferences if options weren't explicitly provided
    if (keyFormat == null || output == null) {
      final prefs = await PreferencesManager.promptForPreferences();
      
      keyFormat ??= prefs['keyFormat'] as String;
      
      if (output == null) {
        final baseDir = prefs['outputDir'] as String;
        output = '$baseDir/intl_en.arb';
      }
      
      print('\n\u001b[36mUsing preferences:\u001b[0m');
      print('- Key format: \u001b[32m$keyFormat\u001b[0m');
      print('- Output file: \u001b[32m$output\u001b[0m\n');
      
      // Save the current values as preferences
      prefs['keyFormat'] = keyFormat;
      prefs['outputDir'] = path.dirname(output);
      PreferencesManager.savePreferences(prefs);
    }

    try {
      // Step 1: Scan directory for strings
      print('📝 Step 1: Scanning directory for strings...');
      final extractedStrings = intl_cli.scanDirectory(dir);
      
      if (extractedStrings.isEmpty) {
        print('No translatable strings found in $dir. Nothing to process.');
        return;
      }
      
      var totalStrings = 0;
      extractedStrings.forEach((file, strings) => totalStrings += strings.length);
      print('\nFound $totalStrings translatable strings in ${extractedStrings.length} files:');
      extractedStrings.forEach((file, strings) {
        print('- ${path.relative(file, from: dir)} (${strings.length} strings)');
      });

      // Ask for confirmation if not skipped
      if (!skipConfirmation) {
        stdout.write('\nThis will process $totalStrings strings across ${extractedStrings.length} files. Continue? (y/N): ');
        final response = stdin.readLineSync()?.toLowerCase() ?? '';
        if (response != 'y' && response != 'yes') {
          print('Processing cancelled.');
          return;
        }
      }

      // Step 2: Generate ARB file
      print('\n📦 Step 2: Generating ARB file...');
      intl_cli.generateArbFile(extractedStrings, output, keyFormat: keyFormat);
      print('✅ Generated ARB file: $output');

      // Step 3: Refactor code to use localization
      print('\n🔄 Step 3: Refactoring code to use localization...');
      
      // Detect package name from the directory structure
      final packageName = detectPackageName(dir);
      print('📦 Detected package name: $packageName');
      
      final refactoredFiles = intl_cli.refactorFiles(
        extractedStrings,
        useAppLocalizations: useAppLocalizations,
        packageName: packageName,
      );

      print('\n✨ All done! Summary:');
      print('- Scanned ${extractedStrings.length} files');
      print('- Found $totalStrings strings');
      print('- Generated ARB file at $output');
      print('- Refactored ${refactoredFiles.length} files');
      
    } catch (e) {
      print('\n\u001b[31mError: ${e.toString()}\u001b[0m');
      exit(1);
    }
  }
}