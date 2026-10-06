# Ayna

A native agentic AI client for macOS, iOS, and watchOS, built with SwiftUI. Swift 6.0+, macOS 26.0+, iOS 26.0+, watchOS 26.0+.

## Project Structure

```
Sources/Ayna/  → All source code (single SwiftPM executableTarget)
Tests/AynaTests/ → Unit tests (Swift Testing)
docs/  → Detailed docs (architecture, testing, platforms, workflow, patterns, performance)
```

## Critical Rules

- **Cross-platform**: Code in `Sources/Ayna/` must build for macOS, iOS, AND watchOS. Use `#if os()` guards for AppKit/UIKit.
- **No third-party deps** without asking first.
- **Swift Concurrency**: Mark `@Observable` classes with `@MainActor`. Never use `DispatchQueue`.
- **Swift Testing** for unit tests, not XCTest. See [docs/testing.md](docs/testing.md).

## Build Commands

```bash
# macOS
swift build

# iOS (compile check)
swift build --triple arm64-apple-ios26.0

# watchOS (compile check)
swift build --triple arm64-apple-watchos26.0

# iOS/watchOS simulator (use AynaMobile.xcodeproj)
open AynaMobile.xcodeproj
```

## Test Commands

```bash
# Unit tests only (preferred)
swift test

# Never run unit + UI tests together
```

## Linting

```bash
swiftlint --strict && swiftformat .
```

## Style (differs from defaults)

| Avoid                         | Prefer                                       |
| ----------------------------- | -------------------------------------------- |
| `DispatchQueue.main.async`    | `@MainActor` or `await MainActor.run {}`     |
| `NavigationView`              | `NavigationStack`                            |
| `.foregroundColor()`          | `.foregroundStyle()`                         |
| `.cornerRadius()`             | `.clipShape(.rect(cornerRadius:))`           |
| `onTapGesture()`              | `Button`                                     |
| `#available` for new SDK APIs | `#if compiler(>=version)`                    |
| XCTest for unit tests         | Swift Testing (`@Suite`, `@Test`, `#expect`) |

## Key Files

- `Sources/Ayna/Services/AIService.swift` — AI service coordinator
- `Sources/Ayna/ViewModels/ConversationManager.swift` — App state
- `Sources/Ayna/Services/Providers/AIProviderProtocol.swift` — Provider protocol
- `Sources/Ayna/Diagnostics/DiagnosticsLogger.swift` — Use for all logging

## Detailed Docs

For detailed guidance, read the relevant doc before starting:

| Task                                | Read                                         |
| ----------------------------------- | -------------------------------------------- |
| Services, providers, concurrency    | [docs/architecture.md](docs/architecture.md) |
| Writing tests                       | [docs/testing.md](docs/testing.md)           |
| Platform-specific, SwiftUI patterns | [docs/platforms.md](docs/platforms.md)       |
| Architectural changes               | [docs/adr/README.md](docs/adr/README.md)     |
| Task planning, debugging            | [docs/workflow.md](docs/workflow.md)         |
| Bug patterns to avoid               | [docs/patterns.md](docs/patterns.md)         |
| Performance checklist               | [docs/performance.md](docs/performance.md)   |

## Living Project Board

`PROJECT_BOARD.md` is this repository's shared living project board. Before starting substantial work, scan it for relevant context. During normal work, agents should proactively add concise, actionable entries when they discover something with genuine future value, including:

- useful technical discoveries
- optimization opportunities
- implementation tricks
- architectural ideas
- possible future improvements
- experiments worth running
- unresolved issues or questions
- follow-up work that should not be lost

Do this proactively even when the discovery is incidental to the current task. Do not add trivial observations, temporary debugging chatter, information already documented elsewhere, generic suggestions with no project relevance, or every step performed during a task. The board supports memory but is not a source of truth when repository code, documentation, or current state contradicts it.

When an item is implemented, mark it complete and optionally record the date and commit/PR, moving it to `Done` when useful. Delete or archive obsolete entries when appropriate.

Updating `PROJECT_BOARD.md` as a side effect of another task is allowed and encouraged when a worthwhile discovery is made. Recording an idea is allowed; implementing unrelated ideas is not.

Preserve all existing repository-specific instructions.
