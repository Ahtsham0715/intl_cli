// src/commands/process_all_command.dart
part of '../cli_runner.dart';

class InternationalizeCommand extends Command<void> {
  @override
  final String name = 'internationalize';

  @override
  final String description =
      'Complete internationalization workflow: scan, extract strings, refactor code, and generate ARB files';

  @override
  List<String> get aliases => ['i18n'];

  @override
  final String invocation = 'intl_cli internationalize [directory] [options]';

  InternationalizeCommand() {
    argParser.addOption('dir',
        abbr: 'd',
        help:
            'The root directory to process (defaults to "lib" if not specified)');
    argParser.addOption('output',
        abbr: 'o',
        help: 'Output ARB file path (defaults to saved preferences)');
    argParser.addOption('key-format',
        abbr: 'k',
        allowed: ['snake_case', 'camelCase', 'dot.case'],
        help:
            'Key naming convention: snake_case, camelCase, dot.case (defaults to saved preferences)');
    argParser.addFlag('use-app-localizations',
        abbr: 'a',
        defaultsTo: true,
        help: 'Use AppLocalizations.of(context) pattern');
    argParser.addFlag('confirm',
        abbr: 'c', defaultsTo: false, help: 'Skip confirmation prompt');
  }

  @override
  Future<void> run() async {
    // Determine the directory to process - check positional args first, then --dir flag
    var dir = argResults!.rest.isNotEmpty
        ? argResults!.rest.first
        : argResults!['dir'] as String?;

    if (dir == null || dir.isEmpty) {
      // Default to 'lib' if no directory specified
      dir = 'lib';
      print('No directory specified, defaulting to: \u001b[32m$dir\u001b[0m');
    }

    // Make sure we're not treating the command name as a directory
    if (dir == name || dir == aliases.first) {
      dir = 'lib';
      print(
          'Command name detected as directory, defaulting to: \u001b[32m$dir\u001b[0m');
    }

    // Validate directory exists
    if (!Directory(dir).existsSync()) {
      print('\u001b[31mError: Directory "$dir" does not exist.\u001b[0m');
      exit(1);
    }

    // Step 1: Ensure all required dependencies are present
    print('\u001b[36mStep 1: Checking and setting up dependencies...\u001b[0m');
    final depResult = ensureFlutterLocalizationsDependencySafe(dir);
    if (!depResult) {
      print('\u001b[31mError: Failed to setup required dependencies\u001b[0m');
      print('\u001b[36mℹ️  Please make sure both flutter_localizations and intl are added to pubspec.yaml\u001b[0m');
      exit(1);
    }
    print('\u001b[32m✓ Dependencies configured successfully\u001b[0m');

    // Step 2: Setup complete Flutter localization configuration
    print('\n\u001b[36mStep 2: Setting up Flutter localization configuration...\u001b[0m');
    final projectRoot = dir == 'lib' ? Directory.current.path : dir;
    print('\u001b[36mℹ️  Project root directory: $projectRoot\u001b[0m');
    final setupResult = setupFlutterLocalizationConfiguration(projectRoot);
    if (!setupResult) {
      print('\u001b[31mError: Failed to setup Flutter localization configuration\u001b[0m');
      exit(1);
    }
    print('\u001b[32m✓ Flutter localization configuration completed successfully\u001b[0m');

    var output = argResults!['output'] as String?;
    var keyFormat = argResults!['key-format'] as String?;
    var useAppLocalizations = argResults!['use-app-localizations'] as bool;
    final skipConfirmation = argResults!['confirm'] as bool;

    // Load user preferences if options weren't explicitly provided
    if (keyFormat == null || output == null) {
      final prefs = await PreferencesManager.promptForPreferences();

      keyFormat ??= prefs['keyFormat'] as String;

      if (output == null) {
        final baseDir = 'lib/l10n';
        // Create the l10n directory if it doesn't exist
        final l10nDir = Directory(path.join(projectRoot, baseDir));
        if (!l10nDir.existsSync()) {
          l10nDir.createSync(recursive: true);
          print('✓ Created l10n directory at: $baseDir');
        }

        output = '$baseDir/app_en.arb';
        
        // Clean up any old intl_*.arb files to avoid conflicts
        final existingFiles = l10nDir.listSync().whereType<File>().where(
          (f) => path.basename(f.path).startsWith('intl_') && f.path.endsWith('.arb')
        );
        
        for (final file in existingFiles) {
          try {
            file.deleteSync();
            print('✓ Removed old ARB file: ${path.basename(file.path)}');
          } catch (e) {
            print('\u001b[33m⚠️  Could not remove old ARB file ${path.basename(file.path)}: $e\u001b[0m');
          }
        }
      }

      print('\n\u001b[36mUsing preferences:\u001b[0m');
      print('- Key format: \u001b[32m$keyFormat\u001b[0m');
      print('- Output file: \u001b[32m$output\u001b[0m\n');

      // Save the current values as preferences
      prefs['keyFormat'] = keyFormat;
      prefs['outputDir'] = path.dirname(output);
      PreferencesManager.savePreferences(prefs);
    } else {
      // If output is explicitly provided, ensure its directory exists
      final outputDir = Directory(path.dirname(path.join(projectRoot, output)));
      if (!outputDir.existsSync()) {
        outputDir.createSync(recursive: true);
        print('✓ Created directory: ${outputDir.path}');
      }
    }

    try {
      // Step 3: Scan directory for strings
      print('\n📝 Step 3: Scanning directory for strings...');
      final extractedStrings = await intl_cli.scanDirectory(dir);

      if (extractedStrings.isEmpty) {
        print('No translatable strings found in $dir. Nothing to process.');
        return;
      }

      var totalStrings = 0;
      extractedStrings
          .forEach((file, strings) => totalStrings += strings.length);
      print(
          '\nFound $totalStrings translatable strings in ${extractedStrings.length} files:');
      extractedStrings.forEach((file, strings) {
        print(
            '- ${path.relative(file, from: dir)} (${strings.length} strings)');
      });

      // Ask for confirmation if not skipped
      if (!skipConfirmation) {
        stdout.write(
            '\nThis will process $totalStrings strings across ${extractedStrings.length} files. Continue? (y/N): ');
        final response = stdin.readLineSync()?.toLowerCase() ?? '';
        if (response != 'y' && response != 'yes') {
          print('Processing cancelled.');
          return;
        }
      }

      // Step 4: Generate ARB file
      print('\n📦 Step 4: Generating ARB file...');
      intl_cli.generateArbFile(extractedStrings, output, keyFormat: keyFormat);
      print('✅ Generated ARB file: $output');

      // Step 5: Refactor code to use localization
      print('\n🔄 Step 5: Refactoring code to use localization...');

      // Detect package name from the directory structure
      final packageName = detectPackageName(dir);
      print('📦 Detected package name: $packageName');

      final refactoredFiles = intl_cli.refactorFiles(
        extractedStrings,
        useAppLocalizations: useAppLocalizations,
        packageName: packageName,
      );

      // Step 6: Run flutter pub get
      print('\n📦 Step 6: Running flutter pub get...');
      final pubGetResult = Process.runSync('flutter', ['pub', 'get'], workingDirectory: projectRoot);
      if (pubGetResult.exitCode != 0) {
        print('\u001b[31mError running flutter pub get:\u001b[0m');
        print(pubGetResult.stderr);
        exit(1);
      }
      print('✅ Dependencies updated');

      // Step 7: Run flutter gen-l10n
      print('\n📦 Step 7: Generating localization files...');
      final genResult = Process.runSync('flutter', ['gen-l10n'], workingDirectory: projectRoot);
      if (genResult.exitCode != 0) {
        print('\u001b[31mError running flutter gen-l10n:\u001b[0m');
        print(genResult.stderr);
        exit(1);
      }
      print('✅ Localization files generated');

      // Step 8: Update MaterialApp with localizations
      print('\n📝 Step 8: Adding localization support to MaterialApp...');
      final mainDart = File(path.join(projectRoot, 'lib', 'main.dart'));
      if (mainDart.existsSync()) {
        var content = mainDart.readAsStringSync();
        if (!content.contains('flutter_localizations')) {
          content = content.replaceAll(
            'import \'package:flutter/material.dart\';',
            '''import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';''');
        }
 //import 'package:flutter_localizations/flutter_localizations.dart';
        if (!content.contains('localizationsDelegates:')) {
          content = content.replaceAll(
            'MaterialApp(',
            '''MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'), // English
      ],''');
        }

        mainDart.writeAsStringSync(content);
        print('✅ Added localization support to MaterialApp');
      }

      print('\n✨ All done! Summary:');
      print('- Scanned ${extractedStrings.length} files');
      print('- Found $totalStrings strings');
      print('- Generated ARB file at $output');
      print('- Set up Flutter localization configuration');
      print('- Refactored ${refactoredFiles.length} files');
      print('- Updated dependencies with flutter pub get');
      print('- Generated localization files with flutter gen-l10n');
      print('- Added localization support to MaterialApp');
      
      print('\n\u001b[32m✓ Your app is now ready for localization!\u001b[0m');
      print('\nTo add a new language:');
      print('1. Create a new ARB file (e.g., \u001b[33mintl_es.arb\u001b[0m for Spanish)');
      print('2. Add the locale to supportedLocales in MaterialApp');
      print('3. Run \u001b[33mflutter gen-l10n\u001b[0m to generate the new language files');
    } catch (e) {
      print('\n\u001b[31mError: ${e.toString()}\u001b[0m');
      exit(1);
    }
  }
}
