#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/swiftstarlist-shots.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

SRC="$WORK/Sources/Screenshots"
mkdir -p "$SRC"

# Copy the app sources (without the @main entry point) into a throwaway
# executable target so we can render SwiftUI views offscreen.
find "$ROOT/SwiftStarList" -name '*.swift' ! -name 'StarListApp.swift' -exec cp {} "$SRC/" \;
cp "$ROOT/scripts/ScreenshotsMain.swift" "$SRC/ScreenshotsMain.swift"

cat > "$WORK/Package.swift" <<'PKG'
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Screenshots",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.2.0"),
    ],
    targets: [
        .executableTarget(
            name: "Screenshots",
            dependencies: [
                .product(name: "MarkdownUI", package: "swift-markdown-ui"),
            ],
            path: "Sources/Screenshots"
        ),
    ]
)
PKG

mkdir -p "$WORK/home"
mkdir -p "$ROOT/docs"

# Keep the README icon in sync with the app icon
sips -Z 256 \
    "$ROOT/SwiftStarList/Assets.xcassets/AppIcon.appiconset/appicon-mac-512@2x.png" \
    --out "$ROOT/docs/app-icon.png" >/dev/null

cd "$WORK"
swift build

for language in en zh; do
    CFFIXED_USER_HOME="$WORK/home" HOME="$WORK/home" ./.build/debug/Screenshots "$ROOT/docs" analysis "$language"
    CFFIXED_USER_HOME="$WORK/home" HOME="$WORK/home" ./.build/debug/Screenshots "$ROOT/docs" overview "$language"
    CFFIXED_USER_HOME="$WORK/home" HOME="$WORK/home" ./.build/debug/Screenshots "$ROOT/docs" data "$language"
    CFFIXED_USER_HOME="$WORK/home" HOME="$WORK/home" ./.build/debug/Screenshots "$ROOT/docs" snapshots "$language"
    CFFIXED_USER_HOME="$WORK/home" HOME="$WORK/home" ./.build/debug/Screenshots "$ROOT/docs" settings "$language"
    CFFIXED_USER_HOME="$WORK/home" HOME="$WORK/home" ./.build/debug/Screenshots "$ROOT/docs" settings-general "$language"
done
