#!/usr/bin/env bash
# Build and publish an APK that installed apps pick up as an in-app update.
#   tool/release.sh dev    "what changed"   -> prerelease dev-<build>
#   tool/release.sh stable "what changed"   -> release stable-<build>
# Build number = commit count on HEAD, so it only goes up. Commit first.
set -euo pipefail
cd "$(dirname "$0")/.."

ch="${1:?channel: dev|stable}"
notes="${2:?release notes}"
[[ "$ch" == dev || "$ch" == stable ]] || { echo "channel must be dev or stable"; exit 1; }
[[ -z "$(git status --porcelain)" ]] || { echo "commit your changes first"; exit 1; }

build=$(git rev-list --count HEAD)
sha=$(git rev-parse --short HEAD)
name="1.0.$build"
tag="$ch-$build"

flutter build apk --release \
  --build-name="$name" --build-number="$build" \
  --dart-define-from-file=../.env \
  --dart-define=CHANNEL="$ch" --dart-define=GIT_SHA="$sha"

apk="build/app/outputs/flutter-apk/focus-$ch-$build.apk"
cp build/app/outputs/flutter-apk/app-release.apk "$apk"

flags=()
[[ "$ch" == dev ]] && flags+=(--prerelease)
git push origin HEAD
gh release create "$tag" "$apk" --title "$tag ($sha)" --notes "$notes" --target "$(git rev-parse HEAD)" "${flags[@]}"
echo "released $tag ($name, $sha)"
