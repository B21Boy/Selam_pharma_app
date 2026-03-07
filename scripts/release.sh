de#!/usr/bin/env bash
# Simple helper for bumping version and creating release builds.
# Usage: ./scripts/release.sh <version+build> [--no-build]
# Example: ./scripts/release.sh 1.0.2+3

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <version>+<build> [--no-build]"
  exit 1
fi

NEWVER="$1"
shift

PUBSPEC="$(pwd)/pubspec.yaml"

# update version line in pubspec.yaml
if grep -qE '^version:' "$PUBSPEC"; then
  sed -i "s/^version:.*/version: $NEWVER/" "$PUBSPEC"
  echo "Updated pubspec.yaml to version $NEWVER"
else
  echo "no version field found in pubspec.yaml" >&2
  exit 1
fi

flutter pub get

# commit the change
if git diff --quiet "$PUBSPEC"; then
  echo "No changes to commit."
else
  git add "$PUBSPEC"
  git commit -m "Bump version to $NEWVER"
  echo "Committed version bump."
fi

# optionally build artifacts
if [[ " ${@} " =~ " --no-build " ]]; then
  echo "Skipping build as requested."
  exit 0
fi

# prefer bundle
flutter build appbundle --release
# also build split APKs for local testing
flutter build apk --release --split-per-abi

echo "Builds complete. Find outputs in build/app/outputs."

echo "
Next steps:
  * push commits and tags
  * upload the AAB to Play Console (internal -> production)
  * monitor logs/reporting
"
