import 'dart:convert';
import 'dart:io';

class ArbGenerator {
  /// Generate or merge ARB file, avoid key duplication, suggest meaningful keys, support custom key format
  static void generateOrMerge({
    required Map<String, String> newStrings,
    required String filePath,
    String locale = 'en',
    bool suggestMeaningfulKeys = true,
    String keyFormat = 'camelCase', // Options: snake_case, camelCase, dot.case
  }) {
    final file = File(filePath);

    // Create directory if it doesn't exist
    final directory = file.parent;
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }

    Map<String, dynamic> arbData = {};
    bool fileExists = file.existsSync();

    if (fileExists) {
      try {
        arbData = jsonDecode(file.readAsStringSync());
        print('📝 Merging with existing ARB file: ${file.path}');
      } catch (e) {
        print('⚠️ Error reading existing ARB file: $e');
        print('Creating a new ARB file instead.');
        fileExists = false;
      }
    }

    int newAdded = 0;

    for (final entry in newStrings.entries) {
      final value = entry.value;
      
      // Always respect the original key if provided
      String key = entry.key;
      
      print('📍 Processing value: $value for key: $key');
      bool needsPluralization = value.contains('(s)') || value.contains('{count}');
      dynamic processedValue = needsPluralization
          ? _generatePluralOrGenderValue(value)
          : (_needsPluralOrGenderSupport(value) ? _generatePluralOrGenderValue(value) : value);
      
      print('✏️ Generated value: $processedValue');

      // Always write the value since we know it's new or an update
      arbData[key] = processedValue;
      newAdded++;
    }

    print('📦 Final ARB data: $arbData');
    // Add context notes and save
    arbData = addContextNotes(arbData);
    var arbContent = JsonEncoder.withIndent('  ').convert(arbData);
    file.writeAsStringSync(arbContent);

    if (newAdded > 0) {
      print('✅ Added $newAdded new strings to ${file.path}');
    } else {
      print('ℹ️ No new strings added to ${file.path}');
    }
  }



  /// Checks if a string needs plural or gender support
  static bool _needsPluralOrGenderSupport(String value) {
    // Only return true if there are explicit indicators
    return value.contains('(s)') || // Explicit plural indicator
           value.contains('{count}') || // Explicit count placeholder
           RegExp(r'\b(he|she|his|her|they|their)\b', caseSensitive: false).hasMatch(value) || // Gender indicators
           RegExp(r'\b\d+\s+\w+s\b').hasMatch(value); // Explicit numbers with plurals
  }

  /// Generate plural or gender variations for a string that needs it
  static dynamic _generatePluralOrGenderValue(String value) {
    // Handle plural forms first
    if (value.contains('(s)') || value.contains('{count}')) {
      // Normalize the base string first
      String baseValue = value.replaceAll(RegExp(r'\b\d+\b'), '{count}');

      // Create singular form
      String singularForm = baseValue
          .replaceAll('(s)', '')  // Remove (s) for singular
          .replaceAll(RegExp(r'\bitems?\b'), 'item')  // Normalize to singular form
          .trim();

      // Create plural form
      String pluralForm = baseValue
          .replaceAll('(s)', 's')  // Add 's' for plural
          .replaceAll(RegExp(r'\bitems?\b'), 'items')  // Normalize to plural form
          .trim();

      // Return the plural forms as a Map
      return <String, String>{
        'one': singularForm,
        'other': pluralForm,
      };
    } else if (RegExp(r'\b(he|she|his|her|they|their)\b', caseSensitive: false).hasMatch(value)) {
      // Handle gender variations
      return <String, String>{
        'male': value.replaceAll(RegExp(r'\b(they|their)\b', caseSensitive: false), 'he'),
        'female': value.replaceAll(RegExp(r'\b(they|their)\b', caseSensitive: false), 'she'),
        'other': value,
      };
    }

    return value;
  }

  /// Detect plural/gender patterns and generate ARB entries accordingly
  static Map<String, dynamic> addPluralAndGenderSupport(
      Map<String, String> newStrings) {
    final result = <String, dynamic>{};
    for (final entry in newStrings.entries) {
      final value = entry.value;

      // Check for potential plural patterns
      bool containsCount = value.toLowerCase().contains('count') ||
          value.contains('{count}') ||
          RegExp(r'\b\d+\s+\w+s?\b').hasMatch(value);

      bool containsPlural = value.contains('(s)') ||
          (value.contains(' item') || value.contains(' items')) ||
          (value.contains(' file') || value.contains(' files'));

      // Detect gender patterns
      bool containsGender = value.toLowerCase().contains(' he ') ||
          value.toLowerCase().contains(' she ') ||
          value.toLowerCase().contains(' they ') ||
          value.toLowerCase().contains(' his ') ||
          value.toLowerCase().contains(' her ') ||
          value.toLowerCase().contains(' their ');

      if (containsCount && containsPlural) {
        // Example: '{count} item(s)' or '1 item' or 'count items'
        String singularForm = value
            .replaceAll('(s)', '')
            .replaceAll(RegExp(r'\b(\d+|count)\s+items\b'), r'$1 item')
            .replaceAll(RegExp(r'\bitems\b'), 'item')
            .replaceAll(RegExp(r'\b\d+\b'), '{count}');

        String pluralForm = value
            .replaceAll('(s)', 's')
            .replaceAll(RegExp(r'\b(\d+|count)\s+item\b'), r'$1 items')
            .replaceAll(RegExp(r'\bitem\b'), 'items')
            .replaceAll(RegExp(r'\b\d+\b'), '{count}');

        result[entry.key] = {
          "one": singularForm,
          "other": pluralForm,
        };
      } else if (containsGender) {
        // Create gender variations with ICU syntax
        String maleForm = value;
        String femaleForm = value;
        String otherForm = value;

        // Replace gender pronouns with ICU syntax
        if (value.toLowerCase().contains(' he ')) {
          maleForm = value.replaceAll(RegExp(r'\bhe\b', caseSensitive: false),
              '{gender, select, male{he} female{she} other{they}}');
          femaleForm =
              value.replaceAll(RegExp(r'\bhe\b', caseSensitive: false), 'she');
          otherForm =
              value.replaceAll(RegExp(r'\bhe\b', caseSensitive: false), 'they');
        } else if (value.toLowerCase().contains(' she ')) {
          maleForm =
              value.replaceAll(RegExp(r'\bshe\b', caseSensitive: false), 'he');
          femaleForm = value.replaceAll(
              RegExp(r'\bshe\b', caseSensitive: false),
              '{gender, select, male{he} female{she} other{they}}');
          otherForm = value.replaceAll(
              RegExp(r'\bshe\b', caseSensitive: false), 'they');
        } else if (value.toLowerCase().contains(' they ')) {
          maleForm =
              value.replaceAll(RegExp(r'\bthey\b', caseSensitive: false), 'he');
          femaleForm = value.replaceAll(
              RegExp(r'\bthey\b', caseSensitive: false), 'she');
          otherForm = value.replaceAll(
              RegExp(r'\bthey\b', caseSensitive: false),
              '{gender, select, male{he} female{she} other{they}}');
        }

        // Handle possessive pronouns
        if (value.toLowerCase().contains(' his ')) {
          maleForm = maleForm.replaceAll(
              RegExp(r'\bhis\b', caseSensitive: false),
              '{gender, select, male{his} female{her} other{their}}');
          femaleForm = femaleForm.replaceAll(
              RegExp(r'\bhis\b', caseSensitive: false), 'her');
          otherForm = otherForm.replaceAll(
              RegExp(r'\bhis\b', caseSensitive: false), 'their');
        } else if (value.toLowerCase().contains(' her ')) {
          maleForm = maleForm.replaceAll(
              RegExp(r'\bher\b', caseSensitive: false), 'his');
          femaleForm = femaleForm.replaceAll(
              RegExp(r'\bher\b', caseSensitive: false),
              '{gender, select, male{his} female{her} other{their}}');
          otherForm = otherForm.replaceAll(
              RegExp(r'\bher\b', caseSensitive: false), 'their');
        } else if (value.toLowerCase().contains(' their ')) {
          maleForm = maleForm.replaceAll(
              RegExp(r'\btheir\b', caseSensitive: false), 'his');
          femaleForm = femaleForm.replaceAll(
              RegExp(r'\btheir\b', caseSensitive: false), 'her');
          otherForm = otherForm.replaceAll(
              RegExp(r'\btheir\b', caseSensitive: false),
              '{gender, select, male{his} female{her} other{their}}');
        }

        result[entry.key] = {
          "male": maleForm,
          "female": femaleForm,
          "other": otherForm,
        };
      } else {
        result[entry.key] = value;
      }
    }
    return result;
  }

  /// Scan for ambiguous or repetitive strings and add context notes
  static Map<String, dynamic> addContextNotes(Map<String, dynamic> arbData) {
    final ambiguous = {
      'ok',
      'yes',
      'no',
      'cancel',
      'submit',
      'save',
      'edit',
      'delete'
    };
    final updated = <String, dynamic>{};
    arbData.forEach((key, value) {
      updated[key] = value;
      if (ambiguous.contains(key.toLowerCase()) ||
          (value is String && ambiguous.contains(value.toLowerCase()))) {
        updated['@$key'] = {
          'description':
              'Please provide context for "$key" (e.g., button label, dialog action, etc.)'
        };
      }
    });
    return updated;
  }

  /// Clean ARB file by removing entries with invalid ICU syntax (Dart interpolation)
  static void cleanInvalidEntries(String filePath) {
    final file = File(filePath);
    if (!file.existsSync()) {
      print('ARB file does not exist: $filePath');
      return;
    }

    try {
      final content = file.readAsStringSync();
      final arbData = jsonDecode(content) as Map<String, dynamic>;

      // Pattern to detect Dart string interpolation
      final dartInterpolationPattern = RegExp(r'\$\{[^}]+\}');

      final keysToRemove = <String>[];

      // Find entries with invalid ICU syntax
      arbData.forEach((key, value) {
        if (value is String && dartInterpolationPattern.hasMatch(value)) {
          keysToRemove.add(key);
          print('Found invalid ICU syntax in key "$key": $value');
        }
      });

      // Remove invalid entries
      if (keysToRemove.isNotEmpty) {
        for (final key in keysToRemove) {
          arbData.remove(key);
          // Also remove associated metadata if it exists
          arbData.remove('@$key');
        }

        // Write cleaned ARB file
        final cleanedContent = JsonEncoder.withIndent('  ').convert(arbData);
        file.writeAsStringSync(cleanedContent);

        print('✅ Cleaned ${keysToRemove.length} invalid entries from $filePath');
        print('Removed keys: ${keysToRemove.join(', ')}');
      } else {
        print('✅ No invalid entries found in $filePath');
      }
    } catch (e) {
      print('❌ Error cleaning ARB file: $e');
    }
  }
}
