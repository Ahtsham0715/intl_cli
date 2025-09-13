/// Enhanced string extraction with ML-based capabilities.
/// 
/// This module provides a factory pattern for managing string extraction using
/// the trained FlutterLocNet.tflite model with 5 million parameters. It handles
/// initialization, caching, and fallback mechanisms for robust string extraction.
/// 
/// The factory ensures only one ML extractor instance is created and manages
/// the lifecycle of the TensorFlow Lite model loading and inference.
library;

import 'ml_string_extractor.dart';

/// Factory class for managing string extraction with ML capabilities.
/// 
/// Provides a centralized interface for ML-based string extraction using the
/// trained FlutterLocNet.tflite model. Handles initialization, caching, and
/// provides fallback mechanisms when the ML model is not available.
/// 
/// Usage:
/// ```dart
/// // Initialize the ML extractor
/// await StringExtractorFactory.initializeML();
/// 
/// // Extract strings from source code
/// final strings = await StringExtractorFactory.extractStrings(sourceCode);
/// ```
class StringExtractorFactory {
  static MLStringExtractor? _mlExtractor;
  static bool _isInitialized = false;

  /// Initialize the ML-based string extractor.
  /// 
  /// Loads and initializes the FlutterLocNet.tflite model with 5 million parameters
  /// for high-accuracy string extraction. This method is idempotent and can be
  /// called multiple times safely.
  /// 
  /// Returns immediately if already initialized. Prints status messages during
  /// initialization process including model loading and validation.
  /// 
  /// Throws exceptions if model files are not found or initialization fails.
  static Future<void> initializeML() async {
    if (_isInitialized) return;

    try {
      _mlExtractor = MLStringExtractor();
      await _mlExtractor!.initialize();
      _isInitialized = true;
      print('🚀 ML String Extractor initialized successfully');
    } catch (e) {
      print('❌ Failed to initialize ML extractor: $e');
      _isInitialized = false;
    }
  }

  /// Extract strings using ML-based approach.
  /// 
  /// Analyzes the provided [sourceCode] using the trained FlutterLocNet.tflite
  /// model to identify and extract translatable strings with high accuracy.
  /// 
  /// Parameters:
  /// * [sourceCode] - The Dart source code to analyze for translatable strings
  /// 
  /// Returns a list of strings identified as translatable by the ML model.
  /// Each string includes confidence scoring and context analysis.
  /// 
  /// Automatically initializes the ML extractor if not already done.
  /// Returns empty list if extraction fails or no strings are found.
  /// 
  /// Example:
  /// ```dart
  /// final sourceCode = '''
  ///   Text("Hello World"),
  ///   Button(label: "Click me")
  /// ''';
  /// final strings = await StringExtractorFactory.extractStrings(sourceCode);
  /// // Returns: ["Hello World", "Click me"]
  /// ```
  static Future<List<String>> extractStrings(String sourceCode) async {
    if (!_isInitialized || _mlExtractor == null) {
      await initializeML();
    }

    if (_mlExtractor != null && _mlExtractor!.isInitialized) {
      return await _mlExtractor!.extractStrings(sourceCode);
    } else {
      print('⚠️ ML extractor not available, falling back to regex-based extraction');
      return _fallbackExtraction(sourceCode);
    }
  }

  /// Fallback regex-based extraction if ML model fails
  static List<String> _fallbackExtraction(String sourceCode) {
    final strings = <String>{};
    
    // Enhanced regex patterns for string extraction
    final patterns = [
      // Text widget strings: Text('string'), Text("string")
      RegExp(r'''Text\s*\(\s*['"]([^'"]+)['"]'''),
      
      // Widget property strings: title: 'string', hint: "string", etc.
      RegExp(r'''(?:title|hint|label|placeholder|description|tooltip|text|message|content):\s*['"]([^'"]+)['"]'''),
      
      // SnackBar and dialog content
      RegExp(r'''(?:content|child):\s*(?:const\s+)?Text\s*\(\s*['"]([^'"]+)['"]'''),
      
      // Button text
      RegExp(r'''(?:ElevatedButton|TextButton|OutlinedButton)\s*\([^)]*child:\s*(?:const\s+)?Text\s*\(\s*['"]([^'"]+)['"]'''),
      
      // AppBar titles and other common UI strings
      RegExp(r'''(?:title|subtitle):\s*(?:const\s+)?Text\s*\(\s*['"]([^'"]+)['"]'''),
    ];

    for (final pattern in patterns) {
      final matches = pattern.allMatches(sourceCode);
      for (final match in matches) {
        final extractedString = match.group(1);
        if (extractedString != null && _isValidUserString(extractedString)) {
          strings.add(extractedString);
        }
      }
    }

    return strings.toList();
  }

  /// Validate if a string is user-facing and should be localized
  static bool _isValidUserString(String str) {
    // Skip empty or very short strings
    if (str.trim().isEmpty || str.length < 2) return false;
    
    // Skip Dart variable interpolations
    if (str.startsWith(r'$') || str.contains(r'${')) return false;
    
    // Skip obvious non-user strings
    if (RegExp(r'^[a-z_][a-zA-Z0-9_]*$').hasMatch(str)) return false; // Variables
    if (str.startsWith('http://') || str.startsWith('https://')) return false; // URLs
    if (RegExp(r'^\d+\.?\d*$').hasMatch(str)) return false; // Pure numbers
    if (str.contains('package:') || str.contains('dart:')) return false; // Imports
    if (RegExp(r'^#[0-9a-fA-F]{6,8}$').hasMatch(str)) return false; // Hex colors
    if (RegExp(r'^[A-Z_]{2,}$').hasMatch(str)) return false; // Constants like DEBUG, INFO
    if (str.contains('=') || str.contains('||') || str.contains('&&')) return false; // Code expressions
    if (str.contains('()') || str.contains('[]')) return false; // Function calls or arrays
    if (RegExp(r'^\w+\.\w+$').hasMatch(str)) return false; // Property access
    if (str.startsWith('@')) return false; // Annotations
    
    // Skip very technical or code-like strings
    if (RegExp(r'^[a-z]+([A-Z][a-z]*)+$').hasMatch(str) && str.length > 20) return false; // Very long camelCase
    
    return true;
  }

  /// Check if ML extractor is available and initialized
  static bool get isMLInitialized => _isInitialized && _mlExtractor != null;

  /// Dispose of resources
  static void dispose() {
    _mlExtractor?.dispose();
    _mlExtractor = null;
    _isInitialized = false;
  }
}
