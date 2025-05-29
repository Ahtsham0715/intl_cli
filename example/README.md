# Example Usage

This directory contains example files showing how to use the intl_cli tool.

## Quick Start Example

```bash
# 1. Install the CLI
dart pub global activate intl_cli

# 2. Navigate to your Flutter project
cd my_flutter_app

# 3. Run the complete internationalization workflow
intl_cli i18n

# 4. Generate Flutter localization files
flutter gen-l10n
```

## Before and After Example

### Before (hardcoded strings):
```dart
class LoginPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Login'),
      ),
      body: Column(
        children: [
          Text('Welcome to our app'),
          ElevatedButton(
            onPressed: () {},
            child: Text('Sign In'),
          ),
        ],
      ),
    );
  }
}
```

### After (using intl_cli):
```dart
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class LoginPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).login),
      ),
      body: Column(
        children: [
          Text(AppLocalizations.of(context).welcomeToOurApp),
          ElevatedButton(
            onPressed: () {},
            child: Text(AppLocalizations.of(context).signIn),
          ),
        ],
      ),
    );
  }
}
```

### Generated ARB file (lib/l10n/intl_en.arb):
```json
{
  "login": "Login",
  "welcomeToOurApp": "Welcome to our app",
  "signIn": "Sign In"
}
```
