// src/commands/clean_command.dart
part of '../cli_runner.dart';

class CleanCommand extends Command {
  @override
  final name = 'clean';

  @override
  final description = 'Clean ARB files by removing entries with invalid ICU syntax';

  @override
  final String invocation = 'intl_cli clean [options]';

  CleanCommand() {
    argParser.addOption('file',
        abbr: 'f',
        help: 'Specific ARB file to clean (if not provided, cleans all .arb files in lib/l10n)');
    argParser.addOption('dir',
        abbr: 'd',
        help: 'Directory containing ARB files (defaults to lib/l10n)');
  }

  @override
  void run() async {
    final specificFile = argResults!['file'] as String?;
    final dir = argResults!['dir'] as String? ?? 'lib/l10n';

    if (specificFile != null) {
      // Clean specific file
      print('🧹 Cleaning specific ARB file: $specificFile');
      ArbGenerator.cleanInvalidEntries(specificFile);
    } else {
      // Clean all ARB files in directory
      final arbDir = Directory(dir);
      
      if (!arbDir.existsSync()) {
        print('❌ Directory does not exist: $dir');
        exit(1);
      }

      print('🧹 Cleaning all ARB files in: $dir');
      
      final arbFiles = arbDir
          .listSync()
          .where((entity) => entity is File && entity.path.endsWith('.arb'))
          .cast<File>()
          .toList();

      if (arbFiles.isEmpty) {
        print('No ARB files found in $dir');
        return;
      }

      print('Found ${arbFiles.length} ARB files to clean:');
      for (final file in arbFiles) {
        print('- ${file.path}');
      }
      print('');

      for (final file in arbFiles) {
        print('Cleaning ${file.path}...');
        ArbGenerator.cleanInvalidEntries(file.path);
        print('');
      }

      print('✅ ARB file cleaning completed!');
    }
  }
}
