# Script Launcher

A panel widget for **KDE Plasma 6** that puts your own scripts, programs and files one click away.

Script Launcher adds an icon to your panel (or desktop). Clicking it opens a titled popup with a tree of launchers that you define yourself. Pick one with the keyboard or the mouse and it runs. There is no background service and nothing else to install.

## Features

### Three kinds of entries

| Type | Description |
|------|-------------|
| **Script** | Type or paste code right in the settings. The first line decides the interpreter (`#!/usr/bin/env fish`, `#!/bin/sh`, `#!/usr/bin/python3`, ...). Without a shebang the script runs in `bash`. |
| **File** | Point to any file. Executable files are run directly, anything else is opened with its default application (`xdg-open`). `~/` paths are supported. |
| **Drawer** | A group that holds other entries, nested as deep as you like. |

### Run in terminal

Every script or file can optionally run in a terminal window, so you can watch its output.

- The terminal defaults to your KDE default terminal (`konsole` as a fallback).
- You can set your own in the widget settings, including the flag that runs a program, e.g. `konsole -e` or `gnome-terminal --`.
- The window waits for Enter when the program finishes.

### Tree editor

- Build the launcher list as a tree in the widget settings.
- Drag entries by their handle to reorder them; dragging left or right changes the nesting.
- Buttons move entries up, down, into or out of a drawer.
- New entries are added where you would expect: after the selected entry, or at the end of a selected drawer.

### Two views (set per widget)

- **List** – drawers open in place, with a back button and a breadcrumb path.
- **Tree** – drawers expand and collapse inline.

### Keyboard navigation

- Nothing is selected when the popup opens. <kbd>↓</kbd> selects the first item, <kbd>↑</kbd> the last one; both wrap around.
- <kbd>Enter</kbd> runs the selected item and closes the popup. On a drawer it enters it (list) or expands it (tree) and selects its first item.
- <kbd>Backspace</kbd> / <kbd>Esc</kbd> go up one level in the list view and close the popup at the top level. In the tree view <kbd>Esc</kbd> closes the popup, and <kbd>←</kbd> / <kbd>→</kbd> collapse and expand drawers.

### Names, icons and colors

- Every entry has a name and an optional icon from your icon theme (sensible defaults otherwise).
- Set text, background and highlight colors for the whole widget, and override the text and background color of individual entries.
- The popup has a title bar whose text you can change.

### Several widgets, independent settings

Add as many instances as you like, for example one for work scripts and one for system tools. Each has its own icon, title, view mode, terminal, colors and launcher tree.

### Import and export

Save the launcher tree to a JSON file and load it on another machine or widget. When importing into a non-empty list you can replace the current launchers or append the imported ones.

### Nothing to run? You get told

If an entry has no script or file defined, a KDE notification with the entry's name is shown instead of silently doing nothing.

### Translations

Follows your KDE language and falls back to English. Included: Polish, German, Spanish, French, Italian, Brazilian Portuguese, Russian, Ukrainian, Czech, Dutch, Japanese and Simplified Chinese. Translations were written by the author and corrections are welcome. See [Translations](#translations-1) below for how to update them.

## Requirements

- KDE Plasma 6
- `bash` and `sh`, plus `fish` or any other interpreter your scripts use
- `notify-send` (libnotify) for the "nothing to run" notification
- `kreadconfig6` (KDE Frameworks) to detect the default terminal

## Installation

From the repository root:

```sh
kpackagetool6 -t Plasma/Applet -i package   # first install
kpackagetool6 -t Plasma/Applet -u package   # update
```

Then right-click the panel → **Add Widgets…** → **Script Launcher**.
After an update you may need to restart the shell: `plasmashell --replace &`.

## Translations

UI strings are written in English with `i18n()`. All translations live in [`tools/i18n.py`](tools/i18n.py). After changing strings or adding a language, run:

```sh
python3 tools/i18n.py
```

It generates `po/*.po`, the compiled `.mo` catalogs in `package/contents/locale/` and the localized `Name[..]` / `Description[..]` entries in `metadata.json` (requires `msgfmt`). It also reports missing and unused translations.

## Security note

Launchers run with your user's privileges, exactly like any script you start yourself. Only import launcher files from sources you trust.

## License

GPL-2.0-or-later
