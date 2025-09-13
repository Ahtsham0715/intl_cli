/// Command-line interface runner for the intl_cli tool.
/// 
/// This module provides the main CLI interface for the Flutter internationalization
/// automation tool. It sets up and manages all available commands including scanning,
/// generation, refactoring, and preferences management.
/// 
/// The CLI supports:
/// * Scanning projects for translatable strings using ML-based extraction
/// * Generating ARB files with meaningful keys
/// * Refactoring code to use localization
/// * Managing preferences and settings
/// * Complete internationalization workflows
library;

// src/cli_runner.dart
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:intl_cli/intl_cli.dart' as intl_cli;
import 'package:path/path.dart' as path;

// Import directly from source files to avoid circular dependency issues
import 'arb_generator.dart';
import 'utilities.dart';

// Command classes
part 'commands/scan_command.dart';
part 'commands/generate_command.dart';
part 'commands/refactor_command.dart';
part 'commands/preferences_command.dart';
part 'commands/process_all_command.dart';
part 'commands/clean_command.dart';

/// Run the CLI with the given arguments.
/// 
/// Main entry point for the command-line interface. Sets up the command runner
/// with all available commands and handles argument parsing and execution.
/// 
/// Parameters:
/// * [arguments] - Command line arguments passed to the application
/// 
/// Available commands:
/// * `scan` - Scan project for translatable strings using ML
/// * `generate` - Generate ARB files from extracted strings
/// * `refactor` - Refactor code to use localization keys
/// * `preferences` - Manage CLI preferences and settings
/// * `internationalize` - Complete end-to-end internationalization
/// * `clean` - Clean generated files and reset state
/// 
/// Example usage:
/// ```
/// intl_cli scan --directory /path/to/project
/// intl_cli generate --input strings.json --output intl_en.arb
/// intl_cli internationalize --directory /path/to/project
/// ```
void run(List<String> arguments) {
  // Create the command runner
  final runner = CommandRunner(
      'intl_cli', 'CLI tool for Flutter internationalization management');

  // Add all the available commands
  runner.addCommand(ScanCommand());
  runner.addCommand(GenerateCommand());
  runner.addCommand(RefactorCommand());
  runner.addCommand(PreferencesCommand());
  runner.addCommand(InternationalizeCommand());
  runner.addCommand(CleanCommand());

  // Log arguments for debugging
  print('CLI runner received arguments: $arguments');

  // Show help if no arguments provided
  if (arguments.isEmpty) {
    print('\n🌍 intl_cli - Flutter Internationalization CLI 🌍\n');
    print(
        'This tool helps you manage internationalization in your Flutter projects.');
    print(
        'It can scan for hardcoded strings, generate ARB files, and refactor your code.\n');
    print('Quick start:');
    print('  intl_cli scan [directory]          # Scan for hardcoded strings');
    print('  intl_cli internationalize [dir]    # Complete i18n workflow');
    print(
        '  intl_cli i18n [dir]                # Short alias for internationalize');
    print('  intl_cli clean                     # Clean ARB files of invalid ICU syntax');
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
      print(
          '\nTry running \u001b[33mintl_cli help\u001b[0m for available commands');
      exit(1); // General error exit code
    }
  });
}
