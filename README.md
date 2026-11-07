<p align="center">
  <img src="docs/app-icon.png" width="128" alt="SwiftStarList app icon">
</p>

# SwiftStarList

English | [简体中文](README.zh-CN.md)

> Vibe-coded with DeepSeek V4.1 Flash / OpenCode

A native macOS app for managing GitHub stars, with AI-powered repository analysis.

![SwiftStarList](docs/overview-en.png)

## Features

- Browse all of your GitHub starred repositories
- Search by name, language, topic, or description
- Sort and group by starred date, language, first letter, star count, and more
- Read repository READMEs with native Markdown rendering
- AI analysis through OpenAI-compatible APIs
  - Multiple custom LLM profiles with a selectable default
  - Structured analysis cards rendered progressively while streaming
  - Optional simple mode with plain Markdown output
  - Additional custom prompt for focus areas or style
- Proxy support: system, HTTP, and SOCKS5
- Local caching for repository data and avatars

## AI Analysis

![AI analysis](docs/analysis-en.png)

## Setup

Configure your GitHub Token and at least one LLM profile before first use:

![Settings](docs/settings-en.png)

The GitHub Token is required to read your starred repositories. The LLM configuration is only needed for AI analysis. Credentials are stored locally at:

```
~/Library/Containers/com.swiftstarlist.app/Data/Library/Application Support/SwiftStarList/credentials.json
```

The file is created with `0600` permissions.

## Build

```bash
# SPM
swift build
swift run

# Xcode
xcodebuild -scheme SwiftStarList build
# or open SwiftStarList.xcodeproj
```

Requires macOS 14 or later.

## Screenshots

Screenshots in `docs/` are generated from the app's SwiftUI components:

```bash
./scripts/render-screenshots.sh
```

## Dependencies

- [MarkdownUI](https://github.com/gonzalezreal/swift-markdown-ui) - Markdown rendering

## License

[MIT](LICENSE) © 2026 0x574859
