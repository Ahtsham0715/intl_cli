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
    
    // Create a reverse lookup for existing translations
    Map<String, String> existingValueToKey = {};
    if (fileExists) {
      arbData.forEach((key, value) {
        if (value is String) {
          existingValueToKey[value] = key;
        }
      });
    }
    
    // Process new strings
    final pluralGenderStrings = addPluralAndGenderSupport(newStrings);
    int newAdded = 0;
    
    for (final entry in pluralGenderStrings.entries) {
      // First check if the exact string already exists in the ARB file
      if (entry.value is String && existingValueToKey.containsKey(entry.value)) {
        // Skip, we already have this exact string
        continue;
      }
      
      // Generate key for new string
      String key = suggestMeaningfulKeys
          ? _suggestKey(entry.value is String ? entry.value as String : entry.key, keyFormat)
          : entry.key;
      
      // Ensure key is unique by adding a suffix if needed
      int suffix = 1;
      String baseKey = key;
      while (arbData.containsKey(key)) {
        key = '${baseKey}_$suffix';
        suffix++;
      }
      
      // Add the new string
      arbData[key] = entry.value;
      newAdded++;
    }
    
    // Add context notes for ambiguous strings
    arbData = addContextNotes(arbData);
    var arbContent = JsonEncoder.withIndent('  ').convert(arbData);
    file.writeAsStringSync(arbContent);
    
    if (newAdded > 0) {
      print('✅ Added $newAdded new strings to ${file.path}');
    } else {
      print('ℹ️ No new strings added to ${file.path}');
    }
  }

  /// Suggest a meaningful ARB key from a string with custom format
  static String _suggestKey(String value, String keyFormat) {
    var base = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
    switch (keyFormat) {
      case 'camelCase':
        return _toCamelCase(base);
      case 'dot.case':
        return base.replaceAll(RegExp(r'\s+'), '.');
      case 'snake_case':
      default:
        return base.replaceAll(RegExp(r'\s+'), '_');
    }
  }

  static String _toCamelCase(String input) {
    final words = input.split(RegExp(r'\s+'));
    if (words.isEmpty) return '';
    return words.first + words.skip(1).map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : '').join();
  }

  /// Detect plural/gender patterns and generate ARB entries accordingly
  static Map<String, dynamic> addPluralAndGenderSupport(Map<String, String> newStrings) {
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
        String singularForm = value.replaceAll('(s)', '')
                                  .replaceAll(RegExp(r'\b(\d+|count)\s+items\b'), r'$1 item')
                                  .replaceAll(RegExp(r'\bitems\b'), 'item')
                                  .replaceAll(RegExp(r'\b\d+\b'), '{count}');
                                  
        String pluralForm = value.replaceAll('(s)', 's')
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
          femaleForm = value.replaceAll(RegExp(r'\bhe\b', caseSensitive: false), 'she');
          otherForm = value.replaceAll(RegExp(r'\bhe\b', caseSensitive: false), 'they');
        } else if (value.toLowerCase().contains(' she ')) {
          maleForm = value.replaceAll(RegExp(r'\bshe\b', caseSensitive: false), 'he');
          femaleForm = value.replaceAll(RegExp(r'\bshe\b', caseSensitive: false), 
                        '{gender, select, male{he} female{she} other{they}}');
          otherForm = value.replaceAll(RegExp(r'\bshe\b', caseSensitive: false), 'they');
        } else if (value.toLowerCase().contains(' they ')) {
          maleForm = value.replaceAll(RegExp(r'\bthey\b', caseSensitive: false), 'he');
          femaleForm = value.replaceAll(RegExp(r'\bthey\b', caseSensitive: false), 'she');
          otherForm = value.replaceAll(RegExp(r'\bthey\b', caseSensitive: false), 
                       '{gender, select, male{he} female{she} other{they}}');
        }
        
        // Handle possessive pronouns
        if (value.toLowerCase().contains(' his ')) {
          maleForm = maleForm.replaceAll(RegExp(r'\bhis\b', caseSensitive: false), 
                     '{gender, select, male{his} female{her} other{their}}');
          femaleForm = femaleForm.replaceAll(RegExp(r'\bhis\b', caseSensitive: false), 'her');
          otherForm = otherForm.replaceAll(RegExp(r'\bhis\b', caseSensitive: false), 'their');
        } else if (value.toLowerCase().contains(' her ')) {
          maleForm = maleForm.replaceAll(RegExp(r'\bher\b', caseSensitive: false), 'his');
          femaleForm = femaleForm.replaceAll(RegExp(r'\bher\b', caseSensitive: false), 
                       '{gender, select, male{his} female{her} other{their}}');
          otherForm = otherForm.replaceAll(RegExp(r'\bher\b', caseSensitive: false), 'their');
        } else if (value.toLowerCase().contains(' their ')) {
          maleForm = maleForm.replaceAll(RegExp(r'\btheir\b', caseSensitive: false), 'his');
          femaleForm = femaleForm.replaceAll(RegExp(r'\btheir\b', caseSensitive: false), 'her');
          otherForm = otherForm.replaceAll(RegExp(r'\btheir\b', caseSensitive: false), 
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
    final ambiguous = {'ok', 'yes', 'no', 'cancel', 'submit', 'save', 'edit', 'delete'};
    final updated = <String, dynamic>{};
    arbData.forEach((key, value) {
      updated[key] = value;
      if (ambiguous.contains(key.toLowerCase()) || (value is String && ambiguous.contains(value.toLowerCase()))) {
        updated['@$key'] = {
          'description': 'Please provide context for "$key" (e.g., button label, dialog action, etc.)'
        };
      }
    });
    return updated;
  }
}
