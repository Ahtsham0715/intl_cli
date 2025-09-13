// src/commands/refactor_command.dart
part of '../cli_runner.dart';

class RefactorCommand extends Command {
  @override
  final name = 'refactor';

  @override
  final description = 'Refactor hardcoded strings to use localization';

  @override
  final String invocation = 'intl_cli refactor [directory] [options]';

  RefactorCommand() {
    argParser.addOption('dir',
        abbr: 'd',
        help:
            'The directory to scan and refactor (defaults to "lib" if not specified)');
    argParser.addFlag('dry-run',
        abbr: 'n', help: 'Preview changes without modifying files');
    argParser.addFlag('use-app-localizations',
        abbr: 'a',
        defaultsTo: true,
        help: 'Use AppLocalizations.of(context) pattern');
    argParser.addOption('package',
        abbr: 'p',
        help:
            'Package name for import statements (autodetected if not specified)');
    argParser.addFlag('preserve-const',
        help: 'Preserve const modifiers where possible');
    argParser.addFlag('confirm',
        abbr: 'c',
        defaultsTo: false,
        help: 'Skip confirmation prompt (USE WITH CAUTION)');
  }

  @override
  void run() async {
    // Determine the directory to scan - check positional args first, then --dir flag
    var dir = argResults!.rest.isNotEmpty
        ? argResults!.rest.first
        : argResults!['dir'] as String?;

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

    // Ensure flutter_localizations dependency is present
    print(
        '\u001b[36mChecking for flutter_localizations dependency...\u001b[0m');
    ensureFlutterLocalizationsDependencySafe(dir);

    final dryRun = argResults!['dry-run'] as bool;
    var useAppLocalizations = argResults!['use-app-localizations'] as bool;
    var packageName = argResults!['package'] as String? ?? "";
    final preserveConst = argResults!['preserve-const'] as bool;
    final skipConfirmation = argResults!['confirm'] as bool;

    try {
      print('Scanning directory: $dir');
      final extractedStrings = await intl_cli.scanDirectory(dir);

      if (extractedStrings.isEmpty) {
        print('No translatable strings found in $dir. Nothing to refactor.');
        return;
      }

      int totalStrings = 0;
      extractedStrings
          .forEach((file, strings) => totalStrings += strings.length);
      print(
          '\nFound $totalStrings translatable strings in \u001b[32m${extractedStrings.length}\u001b[0m files.');

      // Always show what will be refactored
      for (final file in extractedStrings.keys) {
        print(
            '- ${file.replaceAll(dir, '')} (${extractedStrings[file]!.length} strings)');
      }

      // If not explicitly confirmed, ask for confirmation
      if (!skipConfirmation && !dryRun) {
        stdout.write(
            '\nThis will refactor $totalStrings strings across ${extractedStrings.length} files. Continue? (y/N): ');
        final response = stdin.readLineSync()?.toLowerCase() ?? '';
        if (response != 'y' && response != 'yes') {
          print('Refactoring cancelled.');
          return;
        }
      }

      // Perform the refactoring
      // Detect package name automatically if not specified
      final effectivePackageName =
          packageName.isEmpty ? detectPackageName(dir) : packageName;
      if (packageName.isEmpty) {
        print('📦 Detected package name: $effectivePackageName');
      }

      intl_cli.refactorFiles(
        extractedStrings,
        dryRun: dryRun,
        useAppLocalizations: useAppLocalizations,
        packageName: effectivePackageName,
        preserveConst: preserveConst,
      );

      if (dryRun) {
        print('\n\u001b[33mDRY RUN: No files were modified.\u001b[0m');
        print('Run without --dry-run to apply the changes.');
      } else {
        print('\n\u001b[32m✓ Refactoring completed successfully!\u001b[0m');
      }
    } on FileSystemException catch (e) {
      stderr.writeln('\u001b[31mError: ${e.message}: ${e.path}\u001b[0m');
      // Try to recover by creating the directory
      if (e.message.contains('Directory not found') ||
          e.message.contains('No such file')) {
        stderr.writeln('Creating directory and trying again...');
        try {
          // Get the directory path from the error
          final dirPath = e.path ?? dir;
          final directory = Directory(path.dirname(dirPath));
          if (!directory.existsSync()) {
            directory.createSync(recursive: true);
          }

          // Try the operation again
          final newExtractedStrings = await intl_cli.scanDirectory(dirPath);

          // Perform the refactoring
          // Detect package name automatically if not specified
          final effectivePackageNameForRecovery =
              packageName.isEmpty ? detectPackageName(dirPath) : packageName;

          intl_cli.refactorFiles(
            newExtractedStrings,
            dryRun: dryRun,
            useAppLocalizations: useAppLocalizations,
            packageName: effectivePackageNameForRecovery,
            preserveConst: preserveConst,
          );

          if (dryRun) {
            print('\n\u001b[33mDRY RUN: No files were modified.\u001b[0m');
            print('Run without --dry-run to apply the changes.');
          } else {
            print('\n\u001b[32m✓ Refactoring completed successfully!\u001b[0m');
          }
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
