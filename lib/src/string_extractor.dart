import 'dart:convert';
import 'dart:io';

class StringExtractor {
  final String content;
  final List<String>? customExcludePatterns;
  late final Set<int> _ignoreLines;
  late final Set<int> _textRichLines;
  late final Set<String> _textRichContexts;
  
  StringExtractor(this.content, {this.customExcludePatterns}) {
    _ignoreLines = {};
    _textRichLines = {};
    _textRichContexts = {};
    _preprocessContent();
  }

  void _preprocessContent() {
    final lines = content.split('\n');
    final textRichRegex = RegExp('Text\\.rich\\s*\\(\\s*TextSpan\\s*\\(', multiLine: true);
    
    // Process ignore tags and Text.rich instances in a single pass
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.contains('// i18n-ignore')) {
        _ignoreLines.add(i);
        if (i < lines.length - 1) _ignoreLines.add(i + 1);
      }
      if (line.contains('Text.rich')) {
        _textRichLines.add(i);
        if (i < lines.length - 1) _textRichLines.add(i + 1);
      }
    }

    // Process Text.rich contexts more efficiently
    final allTextRichMatches = textRichRegex.allMatches(content);
    for (final richMatch in allTextRichMatches) {
      final lineNumber = content.substring(0, richMatch.start).split('\n').length - 1;
      _textRichLines.add(lineNumber);
      
      // Get text spans within this Text.rich context
      final endPos = richMatch.start + 300 < content.length ? richMatch.start + 300 : content.length;
      final richContext = content.substring(richMatch.start, endPos);
      
      RegExp("text:\\s*['\"]([^'\"]*)['\"]").allMatches(richContext)
        .map((m) => m.group(1))
        .where((text) => text != null && text.isNotEmpty)
        .forEach((text) => _textRichContexts.add(text!));
    }
  }

  List<String> extract() {
    final extracted = <String>{};  // Using Set for faster lookups
    final excludePatterns = _compileExcludePatterns();

    _processTextWidgets(extracted, excludePatterns);
    _processCustomTextWidgets(extracted, excludePatterns);
    _processNamedParameters(extracted, excludePatterns);
    _processLocalizedStrings(extracted);  // Added to find existing localized strings

    return extracted.difference(_textRichContexts).toList();
  }

  RegExp _compileExcludePatterns() {
    final patterns = customExcludePatterns ?? [
      r'^https?://',
      r'^www\.',
      r'^assets/',
      r'^[\w-]+\.(?:png|jpg|jpeg|svg|gif|webp|json|arb|md)$',
      r'^\d+(\.\d+)?$', // Only match pure numbers, not words
      r'^#[0-9a-fA-F]{3,8}$',
      r'^\d+\.\d+\.\d+$',
      r'^\w{8}-\w{4}-\w{4}-\w{4}-\w{12}$', // UUID pattern
      r'^[A-Z][a-zA-Z0-9]*\.[A-Za-z0-9]+', // Class.property pattern
      r'^@\w+',
      r'^_\w+$',
    ];
    return RegExp(patterns.join('|'));
  }

  void _processTextWidgets(Set<String> extracted, RegExp excludePattern) {
    // More flexible pattern to match Text widgets, with or without const
    // Enhanced to catch more text patterns including nested ones
    RegExp('(?:const\\s+)?Text\\(\\s*([\'"])([^\\1]*?)\\1', multiLine: true)
      .allMatches(content)
      .where((match) => !_shouldSkipMatch(match))
      .map((match) => match.group(2))
      .where((string) => string != null && string.isNotEmpty && !excludePattern.hasMatch(string))
      .forEach((string) => extracted.add(string!));
      
    // Second pattern to catch title: Text(AppLocalizations.of(context).title) patterns
    RegExp('title:\\s*(?:const\\s+)?Text\\(\\s*([\'"])([^\\1]*?)\\1', multiLine: true)
      .allMatches(content)
      .where((match) => !_shouldSkipMatch(match))
      .map((match) => match.group(2))
      .where((string) => string != null && string.isNotEmpty && !excludePattern.hasMatch(string))
      .forEach((string) => extracted.add(string!));
      
    // Pattern for Text inside other widgets with const
    RegExp('(?:const|final)\\s+[A-Za-z0-9_]+\\([^)]*\\bText\\(\\s*([\'"])([^\\1]*?)\\1', multiLine: true)
      .allMatches(content)
      .where((match) => !_shouldSkipMatch(match))
      .map((match) => match.group(2))
      .where((string) => string != null && string.isNotEmpty && !excludePattern.hasMatch(string))
      .forEach((string) => extracted.add(string!));
  }

  void _processCustomTextWidgets(Set<String> extracted, RegExp excludePattern) {
    // Improved pattern for custom text widgets
    RegExp('(?:const\\s+)?(?:MyText|CustomText|Label|Button|Title|AppText|Header|Subtitle|Caption|Message)\\(\\s*([\'"])([^\\1]*?)\\1', multiLine: true)
      .allMatches(content)
      .where((match) => !_shouldSkipMatch(match))
      .map((match) => match.group(2))
      .where((string) => string != null && string.isNotEmpty && !excludePattern.hasMatch(string))
      .forEach((string) => extracted.add(string!));
  }

  void _processNamedParameters(Set<String> extracted, RegExp excludePattern) {
    // Match named parameters like text: "Value" or child: Text(AppLocalizations.of(context).value)
    RegExp('(text|label|title|message|description|hint|labelText|hintText|placeholder|tooltip|content|header|subtitle|caption):\\s*([\'"])([^\\2]*?)\\2', multiLine: true)
      .allMatches(content)
      .where((match) => !_shouldSkipMatch(match))
      .map((match) => match.group(3))
      .where((string) => string != null && string.isNotEmpty && !excludePattern.hasMatch(string))
      .forEach((string) => extracted.add(string!));
      
    // Match buttons with Text children - improved pattern
    RegExp('(?:ElevatedButton|TextButton|OutlinedButton|IconButton)\\([^\\)]*child:\\s*(?:const\\s+)?Text\\(\\s*([\'"])([^\\1]*?)\\1', multiLine: true)
      .allMatches(content)
      .where((match) => !_shouldSkipMatch(match))
      .map((match) => match.group(2))
      .where((string) => string != null && string.isNotEmpty && !excludePattern.hasMatch(string))
      .forEach((string) => extracted.add(string!));
      
    // Match BottomNavigationBarItem labels
    RegExp('BottomNavigationBarItem\\([^\\)]*label:\\s*([\'"])([^\\1]*?)\\1', multiLine: true)
      .allMatches(content)
      .where((match) => !_shouldSkipMatch(match))
      .map((match) => match.group(2))
      .where((string) => string != null && string.isNotEmpty && !excludePattern.hasMatch(string))
      .forEach((string) => extracted.add(string!));
      
    // Match ListTile titles and subtitles
    RegExp('ListTile\\([^\\)]*(?:title|subtitle):\\s*(?:const\\s+)?Text\\(\\s*([\'"])([^\\1]*?)\\1', multiLine: true)
      .allMatches(content)
      .where((match) => !_shouldSkipMatch(match))
      .map((match) => match.group(2))
      .where((string) => string != null && string.isNotEmpty && !excludePattern.hasMatch(string))
      .forEach((string) => extracted.add(string!));
      
    // Match Radio and CheckboxListTile titles
    RegExp('(?:Radio|Checkbox)ListTile\\([^\\)]*title:\\s*(?:const\\s+)?Text\\(\\s*([\'"])([^\\1]*?)\\1', multiLine: true)
      .allMatches(content)
      .where((match) => !_shouldSkipMatch(match))
      .map((match) => match.group(2))
      .where((string) => string != null && string.isNotEmpty && !excludePattern.hasMatch(string))
      .forEach((string) => extracted.add(string!));
      
    // Match AppBar titles with const Text
    RegExp('AppBar\\([^\\)]*title:\\s*const\\s+Text\\(\\s*([\'"])([^\\1]*?)\\1', multiLine: true)
      .allMatches(content)
      .where((match) => !_shouldSkipMatch(match))
      .map((match) => match.group(2))
      .where((string) => string != null && string.isNotEmpty && !excludePattern.hasMatch(string))
      .forEach((string) => extracted.add(string!));
      
    // Match raw strings in various widget parameters
    RegExp('(label|title|subtitle|text|hint|tooltip):\\s*([\'"])([^\\2]*?)\\2', multiLine: true)
      .allMatches(content)
      .where((match) => !_shouldSkipMatch(match))
      .map((match) => match.group(3))
      .where((string) => string != null && string.isNotEmpty && !excludePattern.hasMatch(string))
      .forEach((string) => extracted.add(string!));
  }

  // Process strings that are already using AppLocalizations
  void _processLocalizedStrings(Set<String> extracted) {
    // Find the pattern: AppLocalizations.of(context).keyName
    final appLocalizationRegex = RegExp(r'AppLocalizations\.of\(context\)\.(\w+)', multiLine: true);
    final matches = appLocalizationRegex.allMatches(content);

    // For each key found, try to get the corresponding string from the ARB file
    for (final match in matches) {
      if (match.groupCount >= 1) {
        final keyName = match.group(1);
        if (keyName != null && keyName.isNotEmpty) {
          // Look up the key in the ARB file if available
          _tryLookupArbValue(keyName, extracted);
        }
      }
    }
  }

  // Try to lookup the key in the ARB file to get the original string
  void _tryLookupArbValue(String key, Set<String> extracted) {
    try {
      // First, try direct paths
      final arbPaths = [
        'lib/l10n/intl_en.arb',
        'assets/l10n/intl_en.arb',
        'l10n/intl_en.arb',
        'test_app/lib/l10n/intl_en.arb',  // For test app directory
      ];

      // Try direct paths first
      for (final arbPath in arbPaths) {
        final arbFile = File(arbPath);
        if (arbFile.existsSync()) {
          _processArbFile(arbFile, key, extracted);
          return;
        }
      }

      // If not found, search recursively starting from current directory
      final rootDir = Directory('.');
      _findArbFileRecursively(rootDir, key, extracted);
    } catch (e) {
      // Silently ignore errors in ARB lookup
    }
  }

  // Process ARB file and extract values
  void _processArbFile(File arbFile, String key, Set<String> extracted) {
    final content = arbFile.readAsStringSync();
    final Map<String, dynamic> arbData = jsonDecode(content);
    
    // Find the value for the key
    if (arbData.containsKey(key)) {
      final value = arbData[key];
      if (value is String) {
        extracted.add(value);
      } else if (value is Map) {
        // Handle complex values like gender/plural
        value.forEach((k, v) {
          if (v is String) {
            extracted.add(v);
          }
        });
      }
    }
  }

  // Recursively search for ARB files
  void _findArbFileRecursively(Directory dir, String key, Set<String> extracted) {
    try {
      for (final entity in dir.listSync()) {
        if (entity is File && entity.path.endsWith('.arb')) {
          _processArbFile(entity, key, extracted);
          return;  // Exit after finding first ARB file
        } else if (entity is Directory && 
                 !entity.path.contains('/.git/') && 
                 !entity.path.contains('/build/') &&
                 !entity.path.contains('/.dart_tool/')) {
          _findArbFileRecursively(entity, key, extracted);
        }
      }
    } catch (e) {
      // Ignore directory access errors
    }
  }

  bool _shouldSkipMatch(RegExpMatch match) {
    final lineNumber = content.substring(0, match.start).split('\n').length - 1;
    return _ignoreLines.contains(lineNumber) || 
           _textRichLines.contains(lineNumber) || 
           _isInTextRichContext(match);
  }

  bool _isInTextRichContext(RegExpMatch match) {
    final contextStart = match.start > 50 ? match.start - 50 : 0;
    final contextEnd = match.end + 20 < content.length ? match.end + 20 : content.length;
    return content.substring(contextStart, contextEnd).contains('Text.rich');
  }
}
