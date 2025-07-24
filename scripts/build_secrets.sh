#!/bin/bash
# Build script for dart-confidential

echo "Building dart-confidential secrets..."

# Generate obfuscated code
dart run dart-confidential obfuscate --config confidential.yaml --output lib/generated/confidential.dart

# Generate encrypted assets
dart run dart-confidential generate-assets --config confidential.yaml --output-dir assets/encrypted

# Generate environment file
dart run dart-confidential generate-env --config confidential.yaml --output .env.encrypted

echo "Build completed successfully!"
