<!-- filepath: /Users/apple/Documents/flutterProjects/intl_cli/README.md -->
# 🌍 Flutter Internationalization CLI (`intl_cli`)

A professional, all-in-one command-line tool for automating internationalization (i18n) in Flutter/Dart projects. Effortlessly extract hardcoded strings, generate ARB files, refactor code, and manage localization with advanced features for teams and CI/CD.

---

## 🚀 Features

- **1. Auto Extraction of Strings**
  - Extracts hardcoded strings from Dart, YAML, JSON, etc.
  - Supports `Text()`, `MyText()`, `AppLocalizations.of(context).xyz`, etc.
  - Skips `Text.rich`, comments, or lines with `// i18n-ignore`.
- **2. Safe Code Replacement**
  - Replaces hardcoded strings with `AppLocalizations.of(context).key` or custom getter.
  - Context-aware, with dry-run and backup/undo support.
- **3. ARB File Management**
  - Auto-generates ARB keys, inserts/merges/syncs strings, avoids duplication, suggests meaningful keys.
- **4. Custom Key Format Support**
  - Supports `snake_case`, `camelCase`, `dot.case`, etc.
- **5. IDE/CI Integration**
  - VSCode tasks, Git pre-commit hooks, CI lint/validate command.
- **6. Undo/Backup Mode**
  - Backup before changes, `--revert` to restore.
- **7. Scoping Support**
  - Modular/localized ARB files per feature or package (e.g., `feature_login.arb`).
- **8. Plural and Gender Support**
  - Detects plural/gender patterns, generates correct ARB/Dart.
- **9. Text Context Scanner**
  - Highlights ambiguous strings, prompts for ARB context notes.
- **10. Dead Key Detection**
  - Detects unused ARB keys, can remove or mark them.
- **11. Translation Coverage Report**
  - Shows % of missing strings per locale, highlights untranslated.
- **12. Local Translation Mode**
  - Temporarily replaces all translations with ⟦KEY⟧ for visual QA.
- **13. Interactive & Help Commands**
  - `init` for interactive setup, `help` for full feature list and usage.

---

## 📦 Installation

```sh
dart pub global activate intl_cli
```

---

## 🏁 Getting Started

### 1. Scan for Hardcoded Strings
```sh
dart run bin/intl_cli.dart scan --dir lib --verbose
```

### 2. Generate ARB Files
```sh
dart run bin/intl_cli.dart generate --dir lib --output lib/l10n/intl_en.arb
```
- Use `--key-format` to set key style: `snake_case`, `camelCase`, `dot.case`.
- Use `--scope login` for feature-specific ARB: `lib/l10n/feature_login.arb`.

### 3. Refactor Code to Use Localizations
```sh
dart run bin/intl_cli.dart refactor --dir lib --backup
```
- Use `--dry-run` to preview changes.
- Use `--revert` to restore from backup.

### 4. Lint/Validate in CI
```sh
dart run bin/intl_cli.dart lint --dir lib --arb lib/l10n/intl_en.arb
```

### 5. Detect and Manage Dead Keys
```sh
dart run bin/intl_cli.dart dead-keys --dir lib --arb lib/l10n/intl_en.arb --mark
```
- Use `--remove` to delete dead keys.

### 6. Translation Coverage Report
```sh
dart run bin/intl_cli.dart coverage --dir lib --arb-dir lib/l10n
```

### 7. Local Translation Mode (Visual QA)
```sh
dart run bin/intl_cli.dart local-mode --dir lib --arb lib/l10n/intl_en.arb
# Restore after QA
dart run bin/intl_cli.dart local-mode --dir lib --restore
```

### 8. Interactive Setup & Help
```sh
dart run bin/intl_cli.dart init
# or
dart run bin/intl_cli.dart help
```

---

## 🛠️ IDE/CI Integration

### VSCode Task Example
Add this to your `.vscode/tasks.json`:
```json
{
  "version": "2.0.0",
  "tasks": [
    { "label": "intl_cli: scan", "type": "shell", "command": "dart run bin/intl_cli.dart scan --dir lib --verbose", "group": "build" },
    { "label": "intl_cli: generate ARB", "type": "shell", "command": "dart run bin/intl_cli.dart generate --dir lib --output lib/l10n/intl_en.arb", "group": "build" },
    { "label": "intl_cli: refactor", "type": "shell", "command": "dart run bin/intl_cli.dart refactor --dir lib --backup", "group": "build" }
  ]
}
```

### Git Pre-commit Hook Example
Add this to `.git/hooks/pre-commit` and make it executable:
```sh
#!/bin/zsh
dart run bin/intl_cli.dart scan --dir lib
```

### CI Validation/Lint Command
```sh
dart run bin/intl_cli.dart lint --dir lib --arb lib/l10n/intl_en.arb
```

---

## 📚 Command Reference

| Command         | Description                                                      |
|----------------|------------------------------------------------------------------|
| `scan`         | Scan for hardcoded strings                                       |
| `generate`     | Generate/merge ARB files                                         |
| `refactor`     | Refactor code to use localizations                               |
| `lint`         | Validate/lint localization consistency                           |
| `dead-keys`    | Detect/remove/mark unused ARB keys                               |
| `coverage`     | Show translation coverage per locale                             |
| `local-mode`   | Visual QA: replace translations with ⟦KEY⟧, restore with `--restore` |
| `init`         | Interactive setup: pick a feature/command                        |
| `help`         | Show all features and usage                                      |

---

## 🤝 Contributing

Pull requests and issues are welcome! For major changes, please open an issue first to discuss what you would like to change.

---

## 📄 License

[MIT](LICENSE)
