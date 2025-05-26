import 'dart:io';
import 'dart:async';

class FileScanner {
  final String directory;
  final int maxParallelOperations;

  FileScanner(this.directory, {this.maxParallelOperations = 10});

  Future<List<String>> scanAsync() async {
    final files = <String>[];
    final dir = Directory(directory);
    
    if (!dir.existsSync()) {
      throw FileSystemException('Directory not found: $directory');
    }

    await for (final entity in dir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        files.add(entity.path);
      }
    }
    return files;
  }

  // Keep the sync version for backward compatibility
  List<String> scan() {
    final files = <String>[];
    final dir = Directory(directory);
    
    if (!dir.existsSync()) {
      throw FileSystemException('Directory not found: $directory');
    }
    
    dir.listSync(recursive: true)
        .whereType<File>()
        .forEach((f) {
      if (f.path.endsWith('.dart')) files.add(f.path);
    });
    return files;
  }
}
