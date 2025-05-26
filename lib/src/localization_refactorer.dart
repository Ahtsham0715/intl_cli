class LocalizationRefactorer {
  /// Cache of compiled regular expressions for better performance
  static final Map<String, RegExp> _regexCache = {};
  
  /// Simple refactor method for quick string replacement
  static String refactor(String content, String original, String key) {
    return content.replaceAll('"$original"', 'tr("$key")').replaceAll("'$original'", "tr('$key')");
  }
  
  /// Refactors code to use localized strings while preserving all other code
  /// Returns a map with content, changes made flag, and import info
  static Map<String, dynamic> refactorWithContext({
    required String content,
    required String original,
    required String key,
    bool useAppLocalizations = true,
    bool dryRun = false,
    bool preserveConst = true,
  }) {
    // Get or create cached regex for better performance
    final widgetRegex = _regexCache['widget'] ??= RegExp(r'(const\s+)?(Text|MyText)\s*\(([^)]*)\)', multiLine: true);
    
    // Pre-compute the replacement string
    final replacement = useAppLocalizations
        ? 'AppLocalizations.of(context).$key'
        : 'tr("$key")';
    
    // Use StringBuffer for more efficient string manipulation
    final buffer = StringBuffer();
    bool changesMade = false;
    int lastMatch = 0;
    
    // Process all matches efficiently
    for (final match in widgetRegex.allMatches(content)) {
      final constModifier = match.group(1) ?? '';
      final widget = match.group(2) ?? '';
      final args = match.group(3) ?? '';
      
      // Add unchanged content before this match
      buffer.write(content.substring(lastMatch, match.start));
      
      // Check for exact string matches using indexOf for better performance
      final doubleQuoteIdx = args.indexOf('"$original"');
      final singleQuoteIdx = args.indexOf("'$original'");
      
      if (doubleQuoteIdx >= 0 || singleQuoteIdx >= 0) {
        changesMade = true;
        // Remove const when adding AppLocalizations (since it's no longer compile-time constant)
        final newConstModifier = preserveConst && !useAppLocalizations ? constModifier : '';
        
        // Replace the string efficiently
        if (doubleQuoteIdx >= 0) {
          buffer.write('$newConstModifier$widget(${args.replaceFirst('"$original"', replacement)})');
        } else {
          buffer.write('$newConstModifier$widget(${args.replaceFirst("'$original'", replacement)})');
        }
      } else {
        // No replacement needed, keep original
        buffer.write(match.group(0));
      }
      
      lastMatch = match.end;
    }
    
    // Add remaining content
    buffer.write(content.substring(lastMatch));
    final newContent = buffer.toString();
    
    // If dryRun, return a preview with markers
    if (dryRun) {
      return {
        'content': '// DRY RUN PREVIEW\n$newContent',
        'changed': changesMade,
      };
    }
    
    return {
      'content': newContent,
      'changed': changesMade,
      'importNeeded': changesMade && useAppLocalizations,
    };
  }

  /// Adds the AppLocalizations import to a file if not already present
  /// Preserves all existing imports
  static String addLocalizationImport(String content, String packageName) {
    // Get or create cached regex for better performance
    final importRegex = _regexCache['import'] ??= RegExp("import\\s+['\"].*?['\"];", multiLine: true);
    
    // Define the import pattern for AppLocalizations
    final importPattern = "import 'package:$packageName/l10n/app_localizations.dart';";
    final importPattern2 = "import 'package:flutter_gen/gen_l10n/app_localizations.dart';";
    
    // Quick check using indexOf for better performance
    if (content.contains(importPattern) || content.contains(importPattern2)) {
      return content;
    }
    
    final matches = importRegex.allMatches(content);
    if (matches.isNotEmpty) {
      final lastImport = matches.last;
      // Use StringBuffer for better performance with large files
      final buffer = StringBuffer()
        ..write(content.substring(0, lastImport.end))
        ..write('\n')
        ..write(importPattern2)
        ..write(content.substring(lastImport.end));
      return buffer.toString();
    }
    
    // No imports found, add at the top with a blank line
    return '$importPattern2\n\n$content';
  }

  /// Batch process multiple strings in a file for better performance
  static Map<String, dynamic> batchRefactor({
    required String content,
    required Map<String, String> replacements,
    bool useAppLocalizations = true,
    bool preserveConst = true,
  }) {
    final widgetRegex = _regexCache['widget'] ??= RegExp(r'(const\s+)?(Text|MyText)\s*\(([^)]*)\)', multiLine: true);
    bool changesMade = false;
    final buffer = StringBuffer();
    int lastMatch = 0;

    for (final match in widgetRegex.allMatches(content)) {
      final args = match.group(3) ?? '';
      buffer.write(content.substring(lastMatch, match.start));
      
      var replaced = false;
      for (final entry in replacements.entries) {
        final original = entry.key;
        final key = entry.value;
        
        if (args.contains('"$original"') || args.contains("'$original'")) {
          changesMade = true;
          replaced = true;
          final constModifier = match.group(1) ?? '';
          final widget = match.group(2) ?? '';
          final replacement = useAppLocalizations
              ? 'AppLocalizations.of(context).$key'
              : 'tr("$key")';
          
          final newConstModifier = preserveConst && !useAppLocalizations ? constModifier : '';
          buffer.write('$newConstModifier$widget(${args.replaceAll(RegExp('(["\'])$original\\1'), replacement)})');
          break;
        }
      }
      
      if (!replaced) {
        buffer.write(match.group(0));
      }
      
      lastMatch = match.end;
    }
    
    buffer.write(content.substring(lastMatch));
    
    return {
      'content': buffer.toString(),
      'changed': changesMade,
      'importNeeded': changesMade && useAppLocalizations,
    };
  }
}
