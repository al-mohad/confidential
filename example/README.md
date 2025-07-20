# Confidential Flutter Example

This is a complete Flutter application that demonstrates how to use the `dart-confidential` package with build_runner integration.

## Features

- **Automatic Code Generation**: Uses build_runner to automatically generate obfuscated code
- **Flutter Integration**: Shows how to use obfuscated literals in a real Flutter app
- **Interactive Demo**: Tap the button to deobfuscate and display secret values
- **Multiple Secret Types**: Demonstrates strings, lists, and different namespaces

## Getting Started

### Prerequisites

- Flutter SDK (3.24.0 or later)
- Dart SDK (3.8.1 or later)

### Running the Example

1. **Install dependencies:**
   ```bash
   dart pub get
   ```

2. **Generate obfuscated code:**
   ```bash
   # Using the CLI tool (recommended for this example)
   dart run confidential:dart-confidential obfuscate -c confidential.yaml -o lib/generated/confidential.dart

   # Or using build_runner (run from the main package directory)
   cd ..
   dart run build_runner build
   cd example
   ```

   This will read the `confidential.yaml` configuration and generate obfuscated code in `lib/generated/confidential.dart`.

3. **Run the Flutter app:**
   ```bash
   flutter run
   ```

### How It Works

1. **Configuration**: The `confidential.yaml` file defines the secrets to obfuscate and the obfuscation algorithm.

2. **Code Generation**: The build_runner watches for changes to `confidential.yaml` and automatically regenerates the obfuscated code.

3. **Usage**: The Flutter app imports the generated code and uses the obfuscated values at runtime.

### Project Structure

```
example/
├── lib/
│   ├── main.dart                    # Flutter app main file
│   └── generated/
│       └── confidential.dart        # Generated obfuscated code
├── confidential.yaml               # Configuration file
├── pubspec.yaml                    # Flutter dependencies
└── build.yaml                      # Build runner configuration
```

### Configuration

The `confidential.yaml` file contains:

- **Algorithm**: Encryption and obfuscation steps
- **Secrets**: The actual values to obfuscate
- **Namespaces**: Organization of generated code
- **Access Modifiers**: Visibility of generated members

### Development Workflow

1. **Modify secrets**: Edit `confidential.yaml` to add/change secrets
2. **Regenerate**: Run `dart run build_runner build` to update generated code
3. **Use in app**: Import and use the obfuscated values in your Flutter code

### Watch Mode

For continuous development, you can use watch mode:

```bash
dart run build_runner watch
```

This will automatically regenerate the code whenever `confidential.yaml` changes.

## Security Notes

- The example configuration uses a simple algorithm for demonstration
- **Do not use the example algorithm in production**
- Create your own unique algorithm for real applications
- Keep your `confidential.yaml` file secure and out of version control if it contains real secrets

## Troubleshooting

### Build Issues

If you encounter build issues:

1. Clean the build cache:
   ```bash
   dart run build_runner clean
   ```

2. Rebuild:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

### Flutter Issues

If Flutter analysis fails:

1. Run Flutter doctor:
   ```bash
   flutter doctor
   ```

2. Clean Flutter cache:
   ```bash
   flutter clean
   flutter pub get
   ```

## Learn More

- [dart-confidential Documentation](../README.md)
- [Build Runner Documentation](https://pub.dev/packages/build_runner)
- [Flutter Documentation](https://flutter.dev/docs)
