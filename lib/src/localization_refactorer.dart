import 'extensions/string_extensions.dart';

class LocalizationRefactorer {
  /// Cache of compiled regular expressions for better performance
  static final Map<String, RegExp> _regexCache = {};

  /// Refactors code to use localized strings with AppLocalizations
  static Map<String, dynamic> batchRefactor({
    required String content,
    required Map<String, String> replacements,
    bool useAppLocalizations = true,
    bool preserveConst = true,
  }) {
    final widgetRegex = _regexCache['widget'] ??= RegExp(
        r'(const\s+)?((?:Text|MyText|CustomText|Label|LocalizedText)\s*(?:<[^>]*>)?)\s*\(([^)]*)\)',
        multiLine: true);

    bool changesMade = false;
    final buffer = StringBuffer();
    int lastMatch = 0;

    // Pre-compute file-level settings for consistency
    final usesNullAssertion = content.contains('AppLocalizations.of(context)!.');

    for (final match in widgetRegex.allMatches(content)) {
      final widget = match.group(2) ?? '';
      final args = match.group(3) ?? '';
      
      buffer.write(content.substring(lastMatch, match.start));

      var replaced = false;
      for (final entry in replacements.entries) {
        final original = entry.key;
        final key = entry.value;

        // Handle both double and single quotes
        if (args.contains('"$original"') || args.contains("'$original'")) {
          changesMade = true;
          replaced = true;

          // Always validate the key
          final validKey = key.isValidKey() ? key : key.toValidKey();
          
          // Generate the replacement using AppLocalizations
          final replacement = usesNullAssertion
              ? 'AppLocalizations.of(context)!.$validKey'
              : 'AppLocalizations.of(context).$validKey';

          // AppLocalizations requires context, so we can't use const
          if (args.contains('"$original"')) {
            buffer.write('$widget(${args.replaceAll('"$original"', replacement)})');
          } else {
            buffer.write('$widget(${args.replaceAll("'$original'", replacement)})');
          }
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
      'importNeeded': changesMade,
    };
  }

  /// Add AppLocalizations import if needed
  static String addLocalizationImport(String content, String packageName) {
    // Get or create cached regex for better performance
    final importRegex = _regexCache['import'] ??=
        RegExp("import\\s+['\"].*?['\"];", multiLine: true);

    final importPattern = "import 'package:flutter_gen/gen_l10n/app_localizations.dart';";

    // If import already exists, don't add it
    if (content.contains(importPattern)) {
      return content;
    }

    // Find the last import statement
    final matches = importRegex.allMatches(content);
    if (matches.isNotEmpty) {
      final lastImport = matches.last;
      return '${content.substring(0, lastImport.end)}\n$importPattern${content.substring(lastImport.end)}';
    }

    // No imports found, add at the top
    return '$importPattern\n\n$content';
  }
}
