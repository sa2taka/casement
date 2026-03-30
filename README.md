# Casement

A fast, keyboard-driven window switcher for macOS.

Casement lets you search all open windows by app name or title, then instantly switch focus with a few keystrokes. Think of it as Spotlight for your windows.

## Features

- **Global Hotkey** --- Press `Option+Space` from anywhere to open the search panel
- **Fuzzy Search** --- Find windows by app name, title, acronym, or subsequence
- **Smart Ranking** --- Results are ranked by textual relevance, recency (MRU), display/space context, and learned shortcuts
- **Learned Shortcuts** --- Casement remembers your query-to-window selections and boosts them over time
- **Window Activation** --- Handles app activation, window raising, unminimizing, and cross-Space switching with retry
- **App Exclusion** --- Hide noisy apps from search results
- **Menu Bar Resident** --- Runs quietly in the menu bar with no Dock icon

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 16.3 or later (Swift 6.3)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- **Accessibility permission** (required for window enumeration and focus switching)

## Getting Started

### 1. Install dependencies

```bash
brew install xcodegen
```

### 2. Generate the Xcode project

```bash
git clone <repository-url>
cd casement
xcodegen generate
```

This creates `Casement.xcodeproj` from `project.yml`.

### 3. Build and Run

```bash
xcodebuild -project Casement.xcodeproj -scheme Casement -configuration Debug -derivedDataPath build build
```

```bash
open build/Build/Products/Debug/Casement.app
```

Or open `Casement.xcodeproj` in Xcode and press `Cmd+R`.

On first launch, macOS will prompt you to grant Accessibility permission. Go to **System Settings > Privacy & Security > Accessibility** and enable Casement.

### 4. Release Build

```bash
xcodebuild -project Casement.xcodeproj -scheme Casement -configuration Release -derivedDataPath build build
```

```bash
open build/Build/Products/Release/Casement.app
```

The Release build includes compiler optimizations and is suitable for daily use.

### 5. Run tests

```bash
xcodebuild test -project Casement.xcodeproj -scheme Casement -destination 'platform=macOS'
```

## Usage

| Action | Key |
|---|---|
| Open search panel | `Option+Space` (configurable) |
| Close search panel | `Escape` |
| Navigate results | `Up`/`Down` arrows or `Ctrl+P`/`Ctrl+N` |
| Switch to selected window | `Enter` |
| Open actions for selected window | `Tab` |
| Close action menu | `Escape` |

When the search panel opens:
1. Start typing to filter windows by app name or title
2. Use arrow keys (or Ctrl+N / Ctrl+P) to select a result
3. Press Enter to switch to that window
4. Press Tab to open actions (e.g., exclude the app from results)

Empty query shows all windows ordered by most recently used.

The search panel opens on the display where the cursor is located.

### Preferences

Open Preferences from the menu bar icon or press `Cmd+,`. You can:
- Change the global hotkey
- Toggle minimized / utility window inclusion
- Manage excluded apps
- Clear learned shortcut data

## Architecture

```
Casement/
  App/            -- Entry point, AppDelegate, menu bar
  Models/         -- WindowRecord, WindowStableID, RankingTypes
  Services/       -- Core logic (WindowTracker, SearchIndex, RankingEngine, FocusEngine, etc.)
  ViewModels/     -- SearchPanelViewModel
  Views/          -- SwiftUI views + NSPanel wrapper
CasementTests/    -- Unit tests (36 tests)
project.yml       -- XcodeGen project spec
```

Key components:
- **WindowTracker** --- Enumerates windows via CGWindowList + Accessibility API with event-driven + polling hybrid
- **SearchIndex** --- In-memory index with prefix, contains, acronym, and subsequence matching
- **RankingEngine** --- Multi-factor scoring (textual match, MRU decay, context bonuses, learned shortcuts, penalties)
- **FocusEngine** --- Window activation state machine with retry (activate > unminimize > raise > verify)

## Development

After modifying `project.yml`, regenerate the Xcode project:

```bash
xcodegen generate
```

The `.xcodeproj` is generated and should not be committed to version control.

## License

TBD
