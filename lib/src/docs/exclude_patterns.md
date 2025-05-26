# Exclude Patterns in intl_cli

This document explains how the exclude patterns feature works in intl_cli and provides guidance on creating effective patterns for your project.

## What are Exclude Patterns?

Exclude patterns are regular expressions used to identify text strings that should **not** be extracted for translation. This helps prevent non-translatable content like URLs, file paths, class names, and formatting codes from being included in your translations.

## Default Exclude Patterns

The tool includes the following default patterns:

### URLs and Web Addresses
- `^https?://` - Matches URLs that start with http:// or https://
- `^www\.` - Matches web addresses that start with www.
- `^\w+://\w+` - Matches URI schemes like file://, ftp://, etc.

### File Paths and Assets
- `^assets/` - Matches asset paths in Flutter projects
- `^[\w-]+\.(?:png|jpg|jpeg|svg|gif|webp|json|arb|md)$` - Matches common file types
- `^[\w/\-\.]+$` - Matches simple file paths with no spaces
- `^\w+\.` - Matches simple file extensions (e.g., image.png)

### Formatting Codes
- `^<[^>]+>$` - Matches XML/HTML tags
- `^#[0-9a-fA-F]{3,8}$` - Matches color hex codes

### Numbers and IDs
- `^[\d,.]+$` - Matches numbers and simple formatted numbers
- `^\d+\.\d+\.\d+$` - Matches version numbers
- `^\w{8}-\w{4}-\w{4}-\w{4}-\w{12}$` - Matches UUIDs

### Code Elements
- `^[A-Z][a-zA-Z0-9]*\.[A-Za-z0-9]+` - Class references like Widget.property
- `^@\w+` - Annotations
- `^_\w+$` - Private variables

## Managing Exclude Patterns

You can manage exclude patterns using the preferences command:

```bash
intl_cli preferences
```

Then select the option to manage exclude patterns. You can:

1. Add a new pattern
2. Add patterns from predefined categories
3. Remove existing patterns
4. Test a pattern against sample text
5. Reset to default patterns

## Creating Custom Patterns

When creating custom exclude patterns:

1. Use the `^` symbol at the beginning to match the start of a string
2. Use `$` at the end to match the end of a string
3. Test your patterns with sample text before adding them
4. Be careful with overly broad patterns that might exclude legitimate content

## Examples of Custom Patterns

Here are some examples of custom patterns you might want to add:

- `^[A-Z][A-Za-z0-9_]+$` - Class names (PascalCase)
- `^[a-z][a-zA-Z0-9_]+$` - Variable or method names (camelCase)
- `^FLUTTER_[A-Z_]+$` - Constants in screaming snake case
- `^[a-f0-9]{32}$` - MD5 hashes
- `^\d{4}-\d{2}-\d{2}$` - ISO date format (YYYY-MM-DD)

## Tips for Effective Pattern Management

1. **Start specific**: Begin with specific patterns and add broader ones only if needed
2. **Test thoroughly**: Always test patterns against real content from your app
3. **Review extractions**: Periodically review what's being extracted to refine your patterns
4. **Project-specific patterns**: Consider adding patterns specific to your project conventions
5. **Document custom patterns**: Document what your custom patterns exclude and why

Remember that exclude patterns apply globally to all scanned files. If you need to exclude a specific string just once, you can use the `// i18n-ignore` comment on the line above the string in your code.
