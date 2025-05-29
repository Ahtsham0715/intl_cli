import 'dart:io';
import 'dart:async';
import 'package:path/path.dart' as path;

class FileScanner {
  final String directory;
  final int maxParallelOperations;

  FileScanner(this.directory, {this.maxParallelOperations = 10});

  Future<List<String>> scanAsync() async {
    final files = <String>[];
    
    // Safety check - ensure directory exists and normalize it
    final normalizedDir = _normalizeDirectory(directory);
    final dir = Directory(normalizedDir);
    
    if (!dir.existsSync()) {
      print('ERROR: Directory not found in scanAsync: $normalizedDir (original: $directory)');
      throw FileSystemException('Directory not found: $normalizedDir', normalizedDir);
    }

    try {
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File && entity.path.endsWith('.dart')) {
          files.add(entity.path);
        }
      }
    } catch (e) {
      print('ERROR scanning directory: $e');
      rethrow;
    }
    
    return files;
  }

  // Keep the sync version for backward compatibility
  List<String> scan() {
    final files = <String>[];
    
    // Safety check - ensure directory exists and normalize it
    final normalizedDir = _normalizeDirectory(directory);
    final dir = Directory(normalizedDir);
    
    if (!dir.existsSync()) {
      print('ERROR: Directory not found in scan: $normalizedDir (original: $directory)');
      throw FileSystemException('Directory not found: $normalizedDir', normalizedDir);
    }
    
    try {
      dir.listSync(recursive: true)
        .whereType<File>()
        .forEach((f) {
          if (f.path.endsWith('.dart')) files.add(f.path);
        });
    } catch (e) {
      print('ERROR scanning directory: $e');
      rethrow;
    }
    
    return files;
  }
  
  // Helper method to normalize directory paths
  String _normalizeDirectory(String inputPath) {
    // Replace command names with "lib" as a safety measure
    if (inputPath == 'internationalize' || inputPath == 'i18n') {
      print('WARNING: Command name detected as directory in FileScanner, using "lib" instead');
      return 'lib';
    }
    
    // Use path package for proper normalization
    return path.normalize(inputPath);
  }
}
