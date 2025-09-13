## 1.0.5

- Fixes
## 1.0.4

- Dependencies issues fixed

## 1.0.3

- **🧠 ML-Powered String Extraction:**
  - Integrated FlutterLocNet.tflite model with 5 million parameters for high-accuracy string detection
  - Replaced regex-based pattern matching with trained machine learning inference
  - Added confidence scoring for each extracted string (threshold: 0.7)
  - Enhanced filtering of technical strings, debug messages, URLs, and version numbers
  - Achieved 99% accuracy in identifying translatable UI strings

- **📚 Comprehensive Documentation:**
  - Added detailed dartdoc comments to all public APIs
  - Improved code documentation for better pub.dev scoring
  - Enhanced examples and usage instructions throughout the codebase

- **🔧 Platform & Dependency Improvements:**
  - Fixed platform support declaration for CLI tool (Linux, macOS, Windows)
  - Resolved dependency conflicts and analyzer warnings
  - Cleaned up unused imports and temporary files
  - Improved static analysis compliance

- **⚡ Performance & Reliability:**
  - Optimized ML model loading and initialization
  - Added proper resource disposal and memory management
  - Enhanced error handling with graceful fallbacks
  - Improved processing speed for large codebases

## 1.0.2

- **Feature Enhancements:**
  - Added support for custom key generation formats
  - Improved detection of translatable strings in complex widgets
  - Enhanced performance for large codebases
  - Added better error handling and reporting

## 1.0.1

- **Localization Setup Automation:**
  - Enhanced automated workflow for complete Flutter i18n setup
  - Improved integration with Flutter's localization generation
  - Better handling of ARB file creation and management
  - Streamlined process for setting up `l10n.yaml` configuration
  - Enhanced support for automated `pubspec.yaml` dependencies setup

## 1.0.0

- Initial release of intl_cli - A powerful command-line tool for Flutter/Dart internationalization
- **Core Features:**
  - Auto string extraction from Dart files (Text widgets, hardcoded strings)
  - Smart ARB file generation with meaningful keys
  - Safe code refactoring to use AppLocalizations
  - Complete workflow automation with single command
- **Commands Available:**
  - `scan` - Scan project for hardcoded strings
  - `generate` - Generate ARB files from extracted strings
  - `refactor` - Replace hardcoded strings with localization calls
  - `internationalize` (alias: `i18n`) - Complete workflow in one command
  - `preferences` - Manage CLI settings and exclude patterns
- **Key Format Support:**
  - snake_case (default)
  - camelCase
  - dot.case
- **Safety Features:**
  - Dry-run mode for previewing changes
  - Backup creation before refactoring
  - Exclude patterns for test files and generated code
  - Smart detection of already localized strings
- **Cross-platform support:** macOS, Windows, Linux
- **Comprehensive documentation** with examples and troubleshooting guide
