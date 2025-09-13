import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import 'package:intl_cli/intl_cli.dart';

void main() {
  group('FileScanner', () {
    test('should find only dart files', () async {
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

  group('MLStringExtractor', () {
    test('should extract widget text strings', () async {
      var source = '''
        Text("Simple Text"),
        MyCustomText('Custom Widget'),
        const Text('Const Text'),
        Text(
          "Multi-line Text",
        ),
      ''';
      
      // Initialize the ML extractor
      await StringExtractorFactory.initializeML();
      var strings = await StringExtractorFactory.extractStrings(source);
      
      expect(strings, containsAll([
        'Simple Text',
        'Custom Widget', 
        'Const Text',
        'Multi-line Text',
      ]));
    });

    test('should extract property strings', () async {
      var source = '''
        Widget build(BuildContext context) {
          return Scaffold(
            appBar: AppBar(
              title: Text('AppBar Title'),
              tooltip: 'Tooltip Text',
            ),
            body: TextField(
              hint: 'Enter text',
              label: 'Input Label',
              placeholder: 'Placeholder',
              description: 'Field Description',
            ),
          );
        }
      ''';
      
      await StringExtractorFactory.initializeML();
      var strings = await StringExtractorFactory.extractStrings(source);
      
      expect(strings, containsAll([
        'AppBar Title',
        'Tooltip Text',
        'Enter text',
        'Input Label',
        'Placeholder',
        'Field Description',
      ]));
    });

    test('should extract constructor parameter strings', () async {
      var source = '''
        MyWidget(
          title: 'Widget Title',
          label: 'Widget Label',
          text: 'Widget Text',
        )
      ''';
      
      await StringExtractorFactory.initializeML();
      var strings = await StringExtractorFactory.extractStrings(source);
      
      expect(strings, containsAll([
        'Widget Title',
        'Widget Label',
        'Widget Text',
      ]));
    });

    test('should extract variable strings', () async {
      var source = '''
        final String title = 'Page Title';
        const message = 'Welcome Message';
        var prompt = "Enter your name";
        String label = 'Submit Button';
      ''';
      
      await StringExtractorFactory.initializeML();
      var strings = await StringExtractorFactory.extractStrings(source);
      
      expect(strings, containsAll([
        'Page Title',
        'Welcome Message',
        'Enter your name',
        'Submit Button',
      ]));
    });

    test('should ignore excluded patterns', () async {
      var source = '''
        final url = 'https://example.com';
        const asset = 'assets/images/logo.png';
        final hex = '#FF5733';
        final version = '1.0.0';
        final uuid = '550e8400-e29b-41d4-a716-446655440000';
        final constant = 'MY_CONSTANT';
        final scheme = 'file:///path';
        ''';
      
      await StringExtractorFactory.initializeML();
      var strings = await StringExtractorFactory.extractStrings(source);
      
      expect(strings, isEmpty);
    });

    test('should extract quoted strings', () async {
      // This test now matches widget-aware extraction logic
      var source = 'Text("Hello"), MyText(\'World\');';
      
      await StringExtractorFactory.initializeML();
      var strings = await StringExtractorFactory.extractStrings(source);
      
      expect(strings, containsAll(['Hello', 'World']));
    });

    test('should extract all translation patterns comprehensively', () async {
      var source = '''
        Text('Widget Text'),
        tr('tr_key'),
        'extension_key'.tr,
        Get.tr('get_key'),
        AppLocalizations.of(context)!.appMethod,
      ''';

      await StringExtractorFactory.initializeML();
      var strings = await StringExtractorFactory.extractStrings(source);

      expect(strings, contains('Widget Text'));
      expect(strings, contains('tr_key'));
      expect(strings, contains('extension_key'));
      expect(strings, contains('get_key'));
      expect(strings, contains('appMethod'));
      expect(strings.length, equals(5));
    });
  });

  group('Translator', () {
    test('should return same text', () async {
      var text = 'Test';
      expect(Translator.translate(text), equals(text));
    });
  });

  group('ArbGenerator', () {
    test('should generate valid arb file', () async {
      var arbData = {'key1': 'value1'};
      var tempFile = File('${Directory.systemTemp.path}/test.arb');
      ArbGenerator.generateOrMerge(
        newStrings: arbData,
        filePath: tempFile.path,
        suggestMeaningfulKeys: false,
      );
      var content = tempFile.readAsStringSync();
      var decoded = jsonDecode(content);
      expect(decoded, equals(arbData));
      tempFile.deleteSync();
    });

    test('should not pluralize text without explicit indicators', () async {
      var input = {'youHavePushedTheButton': 'You have pushed the button'};
      var tempFile = File('${Directory.systemTemp.path}/test_no_plural.arb');
      ArbGenerator.generateOrMerge(
        newStrings: input,
        filePath: tempFile.path,
        suggestMeaningfulKeys: true,
      );
      var content = tempFile.readAsStringSync();
      var decoded = jsonDecode(content) as Map<String, dynamic>;
      expect(decoded['youHavePushedTheButton'], equals('You have pushed the button'));
      tempFile.deleteSync();
    });

    test('should handle explicit pluralization', () async {
      var input = {'itemCount': 'You have {count} item(s)'};
      var tempFile = File('${Directory.systemTemp.path}/test_plural.arb');
      ArbGenerator.generateOrMerge(
        newStrings: input,
        filePath: tempFile.path,
        suggestMeaningfulKeys: true,
      );
      var content = tempFile.readAsStringSync();
      var decoded = jsonDecode(content) as Map<String, dynamic>;
      expect(decoded['itemCount'], isA<Map>());
      expect(decoded['itemCount']['one'], equals('You have {count} item'));
      expect(decoded['itemCount']['other'], equals('You have {count} items'));
      tempFile.deleteSync();
    });
  });

  group('LocalizationRefactorer', () {
    test('should replace hard-coded strings with localization keys', () async {
      var content = 'Text("Hello") Text(\'World\')';
      final result = LocalizationRefactorer.batchRefactor(
        content: content,
        replacements: {
          'Hello': 'key1',
          'World': 'key2',
        },
        useAppLocalizations: true,
      );
      expect(result['content'], contains('AppLocalizations.of(context).key1'));
      expect(result['content'], contains('AppLocalizations.of(context).key2'));
      expect(result['changed'], isTrue);
    });
  });

  group('KeyPreservation', () {
    test('should preserve full key when converting', () async {
      final input = 'Join us and start your journey';
      final key = input.toValidKey(format: 'camelCase');
      expect(key, equals('joinUsAndStartYourJourney'));
      expect(key.length, equals('joinUsAndStartYourJourney'.length));
    });

    test('should preserve long keys during refactoring', () async {
      final content = 'Text("Join us and start your journey")';
      final key = 'joinUsAndStartYourJourney';
      final result = LocalizationRefactorer.batchRefactor(
        content: content,
        replacements: {'Join us and start your journey': key},
        useAppLocalizations: true,
      );
      
      expect(result['content'], contains('AppLocalizations.of(context).joinUsAndStartYourJourney'));
      expect(result['changed'], isTrue);
    });

    test('should preserve long keys during batch refactoring', () async {
      final content = 'Text("Join us and start your journey")';
      final key = 'joinUsAndStartYourJourney';
      final result = LocalizationRefactorer.batchRefactor(
        content: content,
        replacements: {'Join us and start your journey': key},
        useAppLocalizations: true,
      );
      
      expect(result['content'], contains('AppLocalizations.of(context).joinUsAndStartYourJourney'));
      expect(result['changed'], isTrue);
    });
  });
}
