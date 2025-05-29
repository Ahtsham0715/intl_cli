<!-- filepath: /Users/apple/Documents/flutterProjects/intl_cli/README.md -->
# 🌍 Flutter Internationalization CLI (`intl_cli`)

A powerful command-line tool for automating internationalization (i18n) in Flutter/Dart projects. Extract hardcoded strings, generate ARB files, refactor code, and manage localization with ease.

---

## 🚀 Key Features

- **Auto String Extraction**: Scans Dart files for hardcoded strings in `Text()`, `MyText()`, and other widgets
- **Smart ARB Generation**: Creates ARB files with meaningful keys and proper formatting
- **Safe Code Refactoring**: Replaces hardcoded strings with `AppLocalizations.of(context).key` calls
- **Complete Workflow**: One command to scan → generate → refactor your entire project
- **Flexible Key Formats**: Support for `snake_case`, `camelCase`, and `dot.case` key naming
- **Preferences Management**: Save and reuse project-specific configuration
- **Cross-Platform**: Works on macOS, Windows, and Linux

---

## 📦 Installation

### Option 1: Global installation from pub.dev (Recommended)
```bash
dart pub global activate intl_cli
```

### Option 2: Development/Source installation
```bash
git clone <repository-url>
cd intl_cli
dart pub get
dart pub global activate --source path .
```

After installation, make sure `~/.pub-cache/bin` is in your PATH to use the `intl_cli` command globally.

---

## 🏁 Quick Start

### Complete Workflow (Recommended)
Run the entire internationalization process with one command:
```bash
# Process your entire lib folder
intl_cli internationalize

# Or use the short alias
intl_cli i18n

# Process a specific directory
intl_cli i18n lib/features/login

# With custom options
intl_cli i18n --key-format camelCase --output lib/l10n/app_en.arb
```

### Step-by-Step Commands

#### 1. Scan for Hardcoded Strings
```bash
# Scan the lib directory (default)
intl_cli scan

# Scan a specific directory
intl_cli scan lib/features/login

# Verbose output with detailed information
intl_cli scan --verbose

# Scan specific directory with options
intl_cli scan --dir lib/pages --verbose
```

#### 2. Generate ARB Files
```bash
# Generate ARB file with default settings
intl_cli generate

# Generate with custom output path
intl_cli generate --output lib/l10n/app_en.arb

# Use camelCase keys instead of snake_case
intl_cli generate --key-format camelCase

# Generate scoped ARB for specific feature
intl_cli generate --scope login

# Generate with specific directory and settings
intl_cli generate --dir lib/features --key-format dot.case
```

#### 3. Refactor Code to Use Localizations
```bash
# Refactor with default settings
intl_cli refactor

# Preview changes without modifying files
intl_cli refactor --dry-run

# Refactor specific directory
intl_cli refactor --dir lib/pages

# Skip confirmation prompts (use with caution)
intl_cli refactor --confirm

# Preserve const modifiers where possible
intl_cli refactor --preserve-const

# Use custom package name for imports
intl_cli refactor --package my_app
```

---

## 📋 Command Reference

### Core Commands

| Command | Aliases | Description |
|---------|---------|-------------|
| `scan` | - | Scan project for hardcoded strings |
| `generate` | - | Generate ARB files from found strings |
| `refactor` | - | Replace hardcoded strings with localization calls |
| `internationalize` | `i18n` | Complete workflow: scan → generate → refactor |
| `preferences` | - | Manage CLI preferences and settings |

### Command Options

#### `scan` Command
```bash
intl_cli scan [directory] [options]
```
**Options:**
- `--dir, -d <path>`: Directory to scan (default: lib)
- `--verbose, -v`: Show detailed information about found strings
- `--use-preferences, -p`: Use saved exclude patterns (default: true)

#### `generate` Command
```bash
intl_cli generate [directory] [options]
```
**Options:**
- `--dir, -d <path>`: Directory to scan (default: lib)
- `--output, -o <path>`: Output ARB file path
- `--key-format, -k <format>`: Key format: `snake_case`, `camelCase`, `dot.case`
- `--scope <name>`: Feature/module name for scoped ARB file
- `--confirm, -c`: Skip confirmation prompt

#### `refactor` Command
```bash
intl_cli refactor [directory] [options]
```
**Options:**
- `--dir, -d <path>`: Directory to refactor (default: lib)
- `--dry-run, -n`: Preview changes without modifying files
- `--use-app-localizations, -a`: Use AppLocalizations.of(context) pattern (default: true)
- `--package, -p <name>`: Package name for import statements (auto-detected if not specified)
- `--preserve-const`: Preserve const modifiers where possible
- `--confirm, -c`: Skip confirmation prompt

#### `internationalize` Command
```bash
intl_cli internationalize [directory] [options]
intl_cli i18n [directory] [options]
```
**Options:**
- `--dir, -d <path>`: Root directory to process (default: lib)
- `--output, -o <path>`: Output ARB file path
- `--key-format, -k <format>`: Key format: `snake_case`, `camelCase`, `dot.case`
- `--use-app-localizations, -a`: Use AppLocalizations.of(context) pattern (default: true)
- `--confirm, -c`: Skip confirmation prompt

#### `preferences` Command
```bash
intl_cli preferences [options]
```
**Options:**
- `--reset, -r`: Reset preferences to default values
- `--view, -v`: View current preferences (default: true)
- `--edit, -e`: Edit preferences interactively
- `--patterns, -p`: Manage exclude patterns

---

## ⚙️ Configuration & Preferences

The CLI saves your preferences in `~/.intl_cli_prefs.json`. You can manage these using the preferences command:

```bash
# View current preferences
intl_cli preferences

# Edit preferences interactively
intl_cli preferences --edit

# Manage exclude patterns
intl_cli preferences --patterns

# Reset to defaults
intl_cli preferences --reset
```

### Example Preferences File
```json
{
  "keyFormat": "camelCase",
  "outputDir": "lib/l10n",
  "excludePatterns": [
    "**/*_test.dart",
    "**/test/**",
    "**/.dart_tool/**"
  ]
}
```

---

## 🎯 Usage Examples

### Basic Flutter Project Setup
```bash
# 1. Complete setup in one command
intl_cli i18n

# 2. Or step by step:
intl_cli scan --verbose
intl_cli generate --key-format camelCase
intl_cli refactor --dry-run  # Preview first
intl_cli refactor            # Apply changes
```

### Feature-Specific Internationalization
```bash
# Work on specific feature
intl_cli i18n lib/features/auth --scope auth

# This creates lib/l10n/feature_auth.arb with only auth-related strings
```

### Working with Different Key Formats
```bash
# Use camelCase keys (loginButton, welcomeMessage)
intl_cli generate --key-format camelCase

# Use snake_case keys (login_button, welcome_message)
intl_cli generate --key-format snake_case

# Use dot notation (login.button, welcome.message)
intl_cli generate --key-format dot.case
```

### Safe Testing and Preview
```bash
# Always preview before making changes
intl_cli refactor --dry-run

# Check what strings will be extracted
intl_cli scan --verbose

# Set up preferences first for consistent behavior
intl_cli preferences --edit
```

---

## 🔧 Flutter Project Setup

After running the CLI commands, make sure your Flutter project is properly configured for internationalization:

### 1. Add Dependencies to `pubspec.yaml`
```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter

dev_dependencies:
  flutter_test:
    sdk: flutter

# Enable code generation
flutter:
  generate: true
  uses-material-design: true
```

### 2. Create `l10n.yaml` Configuration
```yaml
arb-dir: lib/l10n
template-arb-file: intl_en.arb
output-localization-file: app_localizations.dart
```

### 3. Configure `MaterialApp`
```dart
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'), // English
        // Add more locales as needed
      ],
      home: MyHomePage(),
    );
  }
}
```

### 4. Generate Localization Files
```bash
# After creating/updating ARB files
flutter gen-l10n
```

---

## 🚨 Important Notes

### What Gets Extracted
The CLI extracts hardcoded strings from:
- `Text('Hello World')` → `Text(AppLocalizations.of(context).helloWorld)`
- `MyText('Welcome')` → `MyText(AppLocalizations.of(context).welcome)`
- String literals in various widget properties

### What Gets Ignored
- Comments and documentation
- Lines with `// i18n-ignore` comment
- `Text.rich()` widgets (complex text formatting)
- Already localized strings (containing `AppLocalizations`)
- Variable names and method names
- Import statements and annotations

### Key Generation Rules
- **snake_case**: `"Hello World"` → `hello_world`
- **camelCase**: `"Hello World"` → `helloWorld`
- **dot.case**: `"Hello World"` → `hello.world`
- Numbers at start: `"123 Test"` → `text123Test` (prefixed with "text")
- Special characters removed: `"Hello, World!"` → `helloWorld`

### File Safety
- Always use `--dry-run` first to preview changes
- The tool creates backups of modified files
- Exclude patterns prevent processing of test files and generated code
- Use version control before running refactor commands

---

## 🐛 Troubleshooting

### Common Issues

#### 1. "AppLocalizations not found" Error
```bash
# Make sure you've generated the localization files
flutter gen-l10n

# Check that your l10n.yaml configuration is correct
# Verify pubspec.yaml has generate: true
```

#### 2. No Strings Found During Scan
```bash
# Use verbose mode to see what's being scanned
intl_cli scan --verbose

# Check if files are being excluded by patterns
intl_cli preferences --patterns
```

#### 3. Refactor Creates Compilation Errors
```bash
# Use dry-run first to preview changes
intl_cli refactor --dry-run

# Make sure ARB file exists and is valid JSON
# Verify your Flutter project is properly configured
```

#### 4. Keys Have Invalid Characters
```bash
# Use a different key format
intl_cli generate --key-format camelCase

# Check that your strings don't start with numbers or special characters
```

### Debug Mode
Set environment variable for detailed logging:
```bash
export INTL_CLI_DEBUG=true
intl_cli scan
```

---

## 📚 Advanced Usage

### Custom Exclude Patterns
```bash
# Edit exclude patterns to skip certain files
intl_cli preferences --patterns

# Common patterns:
# **/*_test.dart     (skip test files)
# **/generated/**   (skip generated code)
# **/build/**       (skip build output)
```

### Integration with CI/CD
```yaml
# .github/workflows/i18n-check.yml
name: Check Internationalization
on: [push, pull_request]
jobs:
  i18n-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: dart-lang/setup-dart@v1
      - name: Install intl_cli
        run: dart pub global activate intl_cli
      - name: Check for new hardcoded strings
        run: intl_cli scan --verbose
        # Fail if new strings found (exit code 1)
```

### IDE Integration
Add tasks to `.vscode/tasks.json`:
```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "i18n: Scan for strings",
      "type": "shell",
      "command": "intl_cli",
      "args": ["scan", "--verbose"],
      "group": "build",
      "presentation": {
        "echo": true,
        "reveal": "always"
      }
    },
    {
      "label": "i18n: Complete workflow",
      "type": "shell", 
      "command": "intl_cli",
      "args": ["i18n"],
      "group": "build"
    }
  ]
}
```

---

## 🤝 Contributing

Contributions are welcome! Here's how to get started:

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/amazing-feature`
3. **Make your changes**
4. **Add tests** for new functionality
5. **Run tests**: `dart test`
6. **Commit changes**: `git commit -m 'Add amazing feature'`
7. **Push to branch**: `git push origin feature/amazing-feature`
8. **Open a Pull Request**

### Development Setup
```bash
git clone <repository-url>
cd intl_cli
dart pub get
dart test  # Run tests
```

### Adding New Commands
1. Create a new file in `lib/src/commands/`
2. Implement the `Command` class
3. Add it to the runner in `lib/src/cli_runner.dart`
4. Update this README with documentation

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 📞 Support

- **Issues**: Report bugs and request features on GitHub Issues
- **Discussions**: Ask questions in GitHub Discussions
- **Documentation**: Check this README and inline help: `dart run bin/intl_cli.dart <command> --help`

---

## 🙏 Acknowledgments

- Flutter team for the excellent internationalization framework
- The Dart community for inspiration and feedback
- Contributors who help improve this tool

---

**Made with ❤️ for the Flutter community**
