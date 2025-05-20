import 'dart:io';
import 'package:intl_cli/intl_cli.dart' as intl_cli;
import 'package:args/command_runner.dart';

void main(List<String> arguments) {
  final runner = CommandRunner('intl_cli', 
      'CLI tool for Flutter internationalization management')
    ..addCommand(ScanCommand())
    ..addCommand(GenerateCommand())
    ..addCommand(RefactorCommand())
    ..addCommand(HelpCommand());

  runner.run(arguments).catchError((error) {
    if (error is! UsageException) {
      print('Error: $error');
    }
    exit(64); // Exit code 64 indicates command line usage error
  });
}

class ScanCommand extends Command {
  @override
  final name = 'scan';
  
  @override
  final description = 'Scan project for hardcoded strings that can be internationalized';
  
  ScanCommand() {
    argParser.addOption('dir',
        abbr: 'd',
        defaultsTo: 'lib',
        help: 'The directory to scan');
    argParser.addFlag('verbose',
        abbr: 'v',
        help: 'Display detailed information about found strings');
  }
  
  @override
  void run() {
    final dir = argResults!['dir'] as String;
    final verbose = argResults!['verbose'] as bool;
    
    try {
      final extractedStrings = intl_cli.scanDirectory(dir);
      
      if (extractedStrings.isEmpty) {
        print('No translatable strings found in $dir.');
        return;
      }
      
      int totalStrings = 0;
      extractedStrings.forEach((file, strings) => totalStrings += strings.length);
      
      print('\nFound $totalStrings translatable strings in ${extractedStrings.length} files:');
      
      if (verbose) {
        extractedStrings.forEach((file, strings) {
          print('\n${file.replaceAll(dir, '')}:');
          for (var i = 0; i < strings.length; i++) {
            print('  ${i + 1}. "${strings[i]}"');
          }
        });
      } else {
        extractedStrings.keys.forEach((file) {
          print('- ${file.replaceAll(dir, '')} (${extractedStrings[file]!.length} strings)');
        });
      }
      
      print('\nRun "intl_cli generate" to create ARB files');
      print('Run "intl_cli refactor" to replace hardcoded strings with localized ones');
    } catch (e) {
      print('Error scanning directory: $e');
      exit(1);
    }
  }
}

class GenerateCommand extends Command {
  @override
  final name = 'generate';
  
  @override
  final description = 'Generate ARB files from hardcoded strings';
  
  GenerateCommand() {
    argParser.addOption('dir',
        abbr: 'd',
        defaultsTo: 'lib',
        help: 'The directory to scan');
    argParser.addOption('output',
        abbr: 'o',
        defaultsTo: 'lib/l10n/intl_en.arb',
        help: 'Output ARB file path');
  }
  
  @override
  void run() {
    final dir = argResults!['dir'] as String;
    final output = argResults!['output'] as String;
    
    try {
      print('Scanning directory: $dir');
      final extractedStrings = intl_cli.scanDirectory(dir);
      
      if (extractedStrings.isEmpty) {
        print('No translatable strings found. ARB file not generated.');
        return;
      }
      
      int totalStrings = 0;
      extractedStrings.forEach((file, strings) => totalStrings += strings.length);
      
      print('Found $totalStrings translatable strings in ${extractedStrings.length} files.');
      
      stdout.write('Generate ARB file at "$output"? (y/N): ');
      final response = stdin.readLineSync()?.toLowerCase();
      
      if (response == 'y' || response == 'yes') {
        final outputFile = intl_cli.generateArbFile(extractedStrings, output);
        print('ARB file generated: $outputFile');
      } else {
        print('ARB file generation cancelled.');
      }
    } catch (e) {
      print('Error generating ARB file: $e');
      exit(1);
    }
  }
}

class RefactorCommand extends Command {
  @override
  final name = 'refactor';
  
  @override
  final description = 'Refactor code to use localized strings';
  
  RefactorCommand() {
    argParser.addOption('dir',
        abbr: 'd',
        defaultsTo: 'lib',
        help: 'The directory to scan and refactor');
    argParser.addFlag('dry-run',
        help: 'Show what would be changed without making actual changes');
    argParser.addFlag('backup',
        defaultsTo: true,
        help: 'Create backup files before making changes');
  }
  
  @override
  void run() {
    final dir = argResults!['dir'] as String;
    final dryRun = argResults!['dry-run'] as bool;
    final backup = argResults!['backup'] as bool;
    
    try {
      print('Scanning directory: $dir');
      final extractedStrings = intl_cli.scanDirectory(dir);
      
      if (extractedStrings.isEmpty) {
        print('No translatable strings found. Nothing to refactor.');
        return;
      }
      
      int totalStrings = 0;
      extractedStrings.forEach((file, strings) => totalStrings += strings.length);
      
      print('Found $totalStrings translatable strings in ${extractedStrings.length} files:');
      extractedStrings.keys.forEach((file) {
        print('- ${file.replaceAll(dir, '')} (${extractedStrings[file]!.length} strings)');
      });
      
      if (dryRun) {
        print('\nDry run completed. No changes were made.');
        return;
      }
      
      stdout.write('\nThis will modify your source files to use localized strings. Continue? (y/N): ');
      final response = stdin.readLineSync()?.toLowerCase();
      
      if (response == 'y' || response == 'yes') {
        if (backup) {
          print('Creating backups...');
          for (var filePath in extractedStrings.keys) {
            var file = File(filePath);
            var backupPath = '$filePath.bak';
            file.copySync(backupPath);
            print('Created backup: $backupPath');
          }
        }
        
        print('Refactoring files...');
        intl_cli.refactorFiles(extractedStrings);
        print('Refactoring completed successfully.');
      } else {
        print('Refactoring cancelled.');
      }
    } catch (e) {
      print('Error refactoring code: $e');
      exit(1);
    }
  }
}

class HelpCommand extends Command {
  @override
  final name = 'help';
  
  @override
  final description = 'Display help information for intl_cli commands';

  HelpCommand() {
    argParser.addOption('command',
        abbr: 'c',
        help: 'The command to display help for');
  }
  
  @override
  String get invocation => '${runner!.executableName} help [command]';

  @override
  void run() {
    // Check if a specific command was requested
    String? commandName = argResults?['command'] ?? (argResults?.rest.isNotEmpty == true ? argResults!.rest.first : null);
    
    if (commandName != null) {
      // Display help for the specific command
      Command? command = runner!.commands[commandName];
      if (command != null) {
        print(command.usage);
      } else {
        print('Unknown command: $commandName');
        print('Run "${runner!.executableName} help" to see all available commands.');
      }
    } else {
      // Display general help
      print(runner!.usage);
    }
  }
}
