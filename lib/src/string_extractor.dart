import 'dart:io';

class StringExtractor {
  // Static patterns for different translation formats
  static final _appLocalizationsPattern = RegExp(
    r'AppLocalizations\.of\(context\)!?\.(\w+)',
    multiLine: true,
  );
  
  static final _trPattern = RegExp(
    r'''tr\(['"]([^'"]+)['"]\)''',
    multiLine: true,
  );
  
  static final _trExtensionPattern = RegExp(
    r'''['"]([^'"]+)['"]\.tr''',
    multiLine: true,
  );
  
  static final _getTrPattern = RegExp(
    r'''Get\.tr\(['"]([^'"]+)['"]\)''',
    multiLine: true,
  );

  // Pattern for widget text strings (Text, MyText, etc.)
  static final _widgetTextPattern = RegExp(
    r'''\b(?:Text|.*Text)\s*\(\s*['"]([^'"]+)['"]\s*\)''',
    multiLine: true,
  );

  final String content;
  final RegExp _excludePattern;
  
  StringExtractor(this.content, {List<String>? customExcludePatterns}) 
      : _excludePattern = _buildExcludePattern(customExcludePatterns);
  
  static RegExp _buildExcludePattern([List<String>? customPatterns]) {
    final patterns = [
      r'https?://',           // URLs
      r'www\.',               // www
      r'assets/',             // Asset paths
      r'[\w-]+\.(png|jpg|jpeg|svg|gif|webp|json|arb|md)$',  // File extensions
      r'^\d+(\.\d+)?$',       // Pure numbers
      r'#[0-9a-fA-F]{3,8}$',  // Hex colors
      r'^\d+\.\d+\.\d+$',     // Semantic versioning
      r'^\w{8}-\w{4}-\w{4}-\w{4}-\w{12}$',  // UUIDs
      r'^[A-Z][a-zA-Z0-9]*\.[A-Za-z0-9]+',   // Class.property
      r'^@\w+',               // Dart annotations
      r'^_\w+$'              // Private variables
    ];
    
    // Add custom patterns if provided
    if (customPatterns != null) {
      patterns.addAll(customPatterns);
    }
    
    return RegExp(patterns.join('|'));
  }

  // Main extraction method that matches the expected API
  List<String> extract() {
    return extractStrings(content).toList();
  }

  Set<String> extractStrings(String sourceCode) {
    final strings = <String>{};
    
    void addMatches(RegExp pattern, String source) {
      for (final match in pattern.allMatches(source)) {
        final value = match.group(1);
        if (value != null && !_excludePattern.hasMatch(value)) {
          strings.add(value);
        }
      }
    }

    // Extract strings from all supported patterns
    addMatches(_appLocalizationsPattern, sourceCode);
    addMatches(_trPattern, sourceCode);
    addMatches(_trExtensionPattern, sourceCode);
    addMatches(_getTrPattern, sourceCode);
    addMatches(_widgetTextPattern, sourceCode);

    return strings;
  }

  Future<Set<String>> extractStringsFromFile(File file) async {
    try {
      final String content = await file.readAsString();
      return extractStrings(content);
    } catch (e) {
      print('Error reading file ${file.path}: $e');
      return {};
    }
  }

  Future<Map<String, Set<String>>> extractStringsFromDirectory(Directory directory) async {
    final results = <String, Set<String>>{};
    
    try {
      await for (final entity in directory.list(recursive: true)) {
        if (entity is File && entity.path.endsWith('.dart')) {
          final strings = await extractStringsFromFile(entity);
          if (strings.isNotEmpty) {
            results[entity.path] = strings;
          }
        }
      }
    } catch (e) {
      print('Error processing directory ${directory.path}: $e');
    }
    
    return results;
  }
}
