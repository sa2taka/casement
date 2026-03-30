# Casement

A fast, keyboard-driven window switcher for macOS.

Casement lets you search all open windows by app name or title, then instantly switch focus with a few keystrokes. Think of it as Spotlight for your windows.

![Launching Casement and typing "casement"](doc/img/casement.png)

## Features

- **Global Hotkey** --- Press `Option+Space` (configurable) from anywhere to open the search panel
- **Fuzzy Search** --- Find windows by app name, title, acronym, or subsequence
- **Chrome Tab Search** --- Search and switch to Chrome tabs by title or URL domain
- **Cmux Workspace Search** --- Search and switch between Cmux workspaces
- **App Exclusion** --- Hide noisy apps from search results via Preferences or inline action

## Requirements

- macOS 14.0 (Sonoma) or later
- **Accessibility permission** (required for window enumeration and focus switching)
- **Automation permission** for Chrome tab search (macOS prompts on first use)

Currently only self-build is supported:

- Xcode 16.3 or later (Swift 6.3)

## Setup

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

### Installing to Applications

Copy the built `.app` to `/Applications` to use it like any other app:

```bash
cp -R build/Build/Products/Release/Casement.app /Applications/
```

> **Note**: Accessibility permission is tied to the app's path. After copying to `/Applications`, you may need to re-grant permission in **System Settings > Privacy & Security > Accessibility**.

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

### Tab Search

Casement also searches **Chrome tabs** and **Cmux workspaces** alongside windows:
- Chrome tabs show with a "tab" badge. Selecting a tab switches Chrome to that tab and window.
- Cmux workspaces show with a "workspace" badge. Selecting one switches to that workspace via Cmd+N.
- Searchable by title, app name, or URL domain (Chrome).

Chrome tab search requires Automation permission (macOS prompts on first use). Cmux uses the existing Accessibility permission.

### Preferences

Open Preferences from the menu bar icon or press `Cmd+,`:
- Change the global hotkey
- Toggle minimized / utility window inclusion
- Manage excluded apps
- Clear learned shortcut data
- Launch at login

## Development

After modifying `project.yml`, regenerate the Xcode project:

```bash
xcodegen generate
```

## License

MIT --- see [LICENSE](LICENSE) for details.
