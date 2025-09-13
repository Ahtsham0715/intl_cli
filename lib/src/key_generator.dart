// Class to handle consistent key generation across the application
class KeyGenerator {
  /// Generate a uniform key from a string value that will be consistent
  /// across both ARB generation and code refactoring
  static String generateKey(String value, {String keyFormat = 'camelCase'}) {
    // Convert to lowercase and clean up the string
    var base = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');

    // Handle empty input
    if (base.isEmpty) return 'emptyString';

    var words = base.split(' ');
    
    // Ensure first word doesn't start with a number
    if (words[0].isNotEmpty && RegExp(r'^\d').hasMatch(words[0])) {
      words[0] = 'text${words[0]}';
    }

    switch (keyFormat) {
      case 'snake_case':
        // Convert to snake_case without truncation
        return words.join('_');
      
      case 'dot.case':
        // Convert to dot.case without truncation
        return words.join('.');
      
      case 'camelCase':
      default:
        // Convert to camelCase without truncation
        if (words.isEmpty) return 'emptyString';
        
        return words[0] + 
               words.skip(1)
                    .map((word) => word.isNotEmpty 
                        ? word[0].toUpperCase() + word.substring(1) 
                        : '')
                    .join('');
    }
  }

  /// Checks if a key is valid for use in ARB files and as a Dart method name
  static bool isValidKey(String key) {
    // Must start with a letter or underscore
    if (!RegExp(r'^[a-zA-Z_]').hasMatch(key)) return false;
    
    // Can only contain letters, numbers, and underscores
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(key)) return false;
    
    return true;
  }

  /// Generate a unique key by adding a suffix if needed
  static String makeKeyUnique(String baseKey, Set<String> existingKeys) {
    var key = baseKey;
    int suffix = 1;
    
    while (existingKeys.contains(key)) {
      key = '${baseKey}_$suffix';
      suffix++;
    }
    
    return key;
  }
}
