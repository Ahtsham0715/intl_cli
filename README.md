# Flutter Internationalization CLI

A command-line tool for automatically finding hard-coded strings in Flutter/Dart projects,
generating ARB files, and refactoring code to use localization.

## Installation

```
dart pub global activate intl_cli
```

## Usage

Run in your Flutter project directory:

```
intl_cli
```

Or specify a directory:

```
intl_cli path/to/your/flutter/project
```

## What it does

1. Scans all Dart files in the specified directory
2. Extracts hard-coded strings
3. Translates them to English (you can implement other languages)
4. Generates ARB files (`intl_en.arb`)
5. Refactors your code to use localization keys

## How to extend

To support more languages, modify the Translator class to connect with a translation API.
