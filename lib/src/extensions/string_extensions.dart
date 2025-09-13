extension StringExtensions on String {
  /// Converts a string to a valid Dart method name / ARB key
  String toValidKey({String format = 'camelCase'}) {
    // Preserve original words by splitting on spaces and punctuation
    var words = RegExp(r'[a-zA-Z0-9]+')
        .allMatches(this)
        .map((match) => match.group(0)!.toLowerCase())
        .where((word) => word.isNotEmpty)
        .toList();

    // Handle empty input
    if (words.isEmpty) return 'emptyString';

    // Ensure first word doesn't start with a number
    if (words[0].isNotEmpty && RegExp(r'^\d').hasMatch(words[0])) {
      words[0] = 'text${words[0]}';
    }

    switch (format) {
      case 'snake_case':
        // Convert to snake_case keeping full string
        return words.join('_');
      
      case 'dot.case':
        // Convert to dot.case keeping full string
        return words.join('.');
      
      case 'camelCase':
      default:
        // Convert to camelCase keeping full string and preserving all words
        return words[0] + 
               words.skip(1)
                    .map((word) => word.isNotEmpty 
                        ? word[0].toUpperCase() + word.substring(1) 
                        : '')
                    .join('');
    }
  }

  /// Checks if the string would make a valid key
  bool isValidKey() {
    return RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$').hasMatch(this);
  }

  /// Makes the key unique by adding a suffix if needed
  String makeKeyUnique(Set<String> existingKeys) {
    var key = this;
    var suffix = 1;
    
    while (existingKeys.contains(key)) {
      key = '${this}_$suffix';
      suffix++;
    }
    
    return key;
  }
}
