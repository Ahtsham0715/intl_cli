#!/usr/bin/env dart

// Main entry point for the intl_cli command
import 'package:intl_cli/src/cli_runner.dart' as cli;
import 'dart:io';

// Debug file to help diagnose issues
final _debugFile = File('${Directory.current.path}/intl_cli_debug.log');

void main(List<String> arguments) {
  try {
    // Enable minimal logging for debugging - only in debug mode
    final debugMode = Platform.environment['INTL_CLI_DEBUG'] == 'true';
    if (debugMode) {
      _logDebug('Current directory: ${Directory.current.path}');
      _logDebug('Original arguments: $arguments');
      _logDebug('OS: ${Platform.operatingSystem}');
      _logDebug('Platform version: ${Platform.operatingSystemVersion}');
    }

    // If we're running the internationalize command, we need to make sure
    // we're not trying to look for a directory called "internationalize"
    if (arguments.isNotEmpty &&
        (arguments[0] == 'internationalize' || arguments[0] == 'i18n')) {
      if (debugMode) _logDebug('Intercepting internationalize command');

      // Create a complete new arguments list with explicit directory
      List<String> newArgs = [arguments[0]];

      // If the second argument exists and isn't an option flag, use it as the directory
      // Otherwise, insert 'lib' as the default directory
      if (arguments.length > 1 && !arguments[1].startsWith('-')) {
        newArgs.add(arguments[1]); // Use the provided directory
        if (arguments.length > 2) {
          newArgs.addAll(arguments.sublist(2)); // Add any remaining args
        }
      } else {
        newArgs.add('lib'); // Add default directory
        if (arguments.length > 1) {
          newArgs.addAll(arguments.sublist(1)); // Add any options
        }
      }

      if (debugMode) _logDebug('Modified arguments: $newArgs');

      // Run the modified command
      cli.run(newArgs);
    } else {
      // For all other commands, run as normal
      cli.run(arguments);
    }
  } catch (e, stacktrace) {
    final debugMode = Platform.environment['INTL_CLI_DEBUG'] == 'true';
    if (debugMode) {
      _logDebug('Error: $e\nStacktrace: $stacktrace');
    }
    stderr.writeln('Error running command: $e');
    exit(1);
  }
}

// Helper function to log debug information (only when debug mode is enabled)
void _logDebug(String message) {
  final debugMode = Platform.environment['INTL_CLI_DEBUG'] == 'true';
  if (!debugMode) return;

  final timestamp = DateTime.now().toIso8601String();
  final logMessage = '[$timestamp] $message\n';

  try {
    _debugFile.writeAsStringSync(logMessage, mode: FileMode.append);
    stderr.writeln('[DEBUG] $message'); // Use stderr for debug info
  } catch (e) {
    // If we can't write to the debug file, just print to stderr
    stderr.writeln('[DEBUG] Failed to write to debug log: $e');
    stderr.writeln('[DEBUG] $message');
  }
}
