import 'dart:io';

class FileScanner {
  final String directory;
  FileScanner(this.directory);

  List<String> scan() {
    var files = <String>[];
    Directory(directory)
        .listSync(recursive: true)
        .whereType<File>()
        .forEach((f) {
      if (f.path.endsWith('.dart')) files.add(f.path);
    });
    return files;
  }
}
