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
