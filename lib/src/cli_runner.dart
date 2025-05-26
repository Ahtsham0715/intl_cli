// src/cli_runner.dart
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:intl_cli/intl_cli.dart' as intl_cli;
import 'package:path/path.dart' as path;
import 'utilities.dart' show PreferencesManager, detectPackageName;

// Command classes
part 'commands/scan_command.dart';
part 'commands/generate_command.dart';
part 'commands/refactor_command.dart';
part 'commands/preferences_command.dart';
part 'commands/process_all_command.dart';
// Other commands will be implemented later

/// Run the CLI with the given arguments
void run(List<String> arguments) {
  // Create the command runner
  final runner = CommandRunner(
    'intl_cli', 
    'CLI tool for Flutter internationalization management'
  );
  
  // Add all the available commands
  runner.addCommand(ScanCommand());
  runner.addCommand(GenerateCommand());
  runner.addCommand(RefactorCommand());
  runner.addCommand(PreferencesCommand());
  runner.addCommand(InternationalizeCommand());
  // More commands will be added later
  
  // Show help if no arguments provided
  if (arguments.isEmpty) {
    print('\n🌍 intl_cli - Flutter Internationalization CLI 🌍\n');
    print('This tool helps you manage internationalization in your Flutter projects.');
    print('It can scan for hardcoded strings, generate ARB files, and refactor your code.\n');
    print('Quick start:');
    print('  intl_cli scan [directory]          # Scan for hardcoded strings');
    print('  intl_cli internationalize [dir]    # Complete i18n workflow');
    print('  intl_cli i18n [dir]                # Short alias for internationalize');
    print('\nAvailable commands:');
    print(runner.usage);
    print('\nRun a specific command with --help for more information.');
    print('If no directory is specified, defaults to "lib" folder.');
    return;
  }
  
  // Run the command with the provided arguments
  runner.run(arguments).catchError((error) {
    if (error is UsageException) {
      // Properly handle command not found and usage errors
      print(error.message);
      print('');
      print(error.usage);
      exit(64); // Exit code 64 indicates command line usage error
    } else {
      // Handle other errors with a helpful message
      print('\u001b[31mError: $error\u001b[0m');
      print('\nTry running \u001b[33mintl_cli help\u001b[0m for available commands');
      exit(1); // General error exit code
    }
  });
}
