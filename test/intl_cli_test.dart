import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import 'package:intl_cli/intl_cli.dart';

void main() {
  
  group('FileScanner', () {
    test('should find only dart files', () {
      var tempDir = Directory.systemTemp.createTempSync();
      // Create a dart file and a non-dart file
      var dartFile = File('${tempDir.path}/test.dart')
        ..writeAsStringSync('void main() {}');
      var txtFile = File('${tempDir.path}/test.txt')
        ..writeAsStringSync('Hello');
      var scanner = FileScanner(tempDir.path);
      var files = scanner.scan();
      expect(files, contains(dartFile.path));
      expect(files, isNot(contains(txtFile.path)));
      tempDir.deleteSync(recursive: true);
    });
  });

  group('StringExtractor', () {
    test('should extract quoted strings', () {
      var source = 'print("Hello"), print(\'World\');';
      var extractor = StringExtractor(source);
      var strings = extractor.extract();
      expect(strings, containsAll(['Hello', 'World']));
    });
  });

  group('Translator', () {
    test('should return same text', () {
      var text = 'Test';
      expect(Translator.translate(text), equals(text));
    });
  });

  group('ArbGenerator', () {
    test('should generate valid arb file', () {
      var arbData = {'key1': 'value1'};
      var tempFile = File('${Directory.systemTemp.path}/test.arb');
      ArbGenerator.generate(arbData, tempFile.path);
      var content = tempFile.readAsStringSync();
      var decoded = jsonDecode(content);
      expect(decoded, equals(arbData));
      tempFile.deleteSync();
    });
  });

  group('LocalizationRefactorer', () {
    test('should replace hard-coded strings with localization keys', () {
      var content = 'Text "Hello" and \'World\'.';
      var refactored = LocalizationRefactorer.refactor(content, "Hello", "key1");
      refactored = LocalizationRefactorer.refactor(refactored, "World", "key2");
      expect(refactored, contains('tr("key1")'));
      expect(refactored, contains("tr('key2')"));
    });
  });
}
