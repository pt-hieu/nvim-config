# Open Markdown Files in Neovim + Ghostty (macOS)

> **Machine-specific.** This setup lives outside the Neovim config repo and is
> applied only on **Brian's MacBook Air** (`Mac17,3`, macOS Tahoe / Darwin 25.5.0).
> Cloning this repo to another machine does **not** apply it. Re-run the steps
> below on any new machine that needs it.

## Goal

Double-clicking a `.md` file in Finder opens it in Neovim, inside a new Ghostty
window.

## Why an app bundle is needed

macOS only lets a `.app` bundle register as a document handler. Finder passes
files to an app through the `odoc` Apple Event, not through `argv`, so a plain
shell script cannot receive them. The wrapper below is an AppleScript app with an
`on open` handler, which does receive the Apple Event.

## Prerequisites

| Requirement | Path on this machine |
|---|---|
| Ghostty | `/Applications/Ghostty.app` |
| Neovim | `/opt/homebrew/bin/nvim` |
| `duti` | `/opt/homebrew/bin/duti` (`brew install duti`) |

## What was installed

- `~/Applications/Neovim.app` — AppleScript wrapper app
- Bundle identifier: `com.brian.neovim-ghostty`
- Default handler registered for `net.daringfireball.markdown`, `.md`, `.markdown`

## Setup steps

### 1. Build the AppleScript wrapper

```bash
mkdir -p ~/Applications /tmp/nvim-app && cat > /tmp/nvim-app/nvim.applescript <<'EOF'
on run
	do shell script "/usr/bin/open -na /Applications/Ghostty.app --args -e nvim"
end run

on open theFiles
	repeat with aFile in theFiles
		set filePath to POSIX path of (aFile as alias)
		do shell script "/usr/bin/open -na /Applications/Ghostty.app --args -e nvim " & quoted form of filePath
	end repeat
end open
EOF
osacompile -o ~/Applications/Neovim.app /tmp/nvim-app/nvim.applescript
rm -rf /tmp/nvim-app
```

Notes:

- `do shell script` runs with a minimal `PATH`, so `/usr/bin/open` is spelled out
  in full.
- `open -na` forces a **new** Ghostty instance per file, so an already-running
  Ghostty window is never reused.
- `quoted form of` handles paths containing spaces.

### 2. Declare the bundle identifier and document types

```bash
P=~/Applications/Neovim.app/Contents/Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.brian.neovim-ghostty" "$P" 2>/dev/null \
  || /usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string com.brian.neovim-ghostty" "$P"
/usr/libexec/PlistBuddy -c "Delete :CFBundleDocumentTypes" "$P" 2>/dev/null
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes array" "$P"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0 dict" "$P"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:CFBundleTypeName string 'Markdown Document'" "$P"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:CFBundleTypeRole string Editor" "$P"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:LSHandlerRank string Owner" "$P"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:LSItemContentTypes array" "$P"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:LSItemContentTypes:0 string net.daringfireball.markdown" "$P"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:LSItemContentTypes:1 string public.plain-text" "$P"
```

### 3. Re-sign and register with LaunchServices

`osacompile` signs the bundle, so editing `Info.plist` afterwards invalidates the
signature. Re-sign, then register:

```bash
codesign --force --deep --sign - ~/Applications/Neovim.app
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f ~/Applications/Neovim.app
```

### 4. Set it as the default handler

```bash
brew install duti
duti -s com.brian.neovim-ghostty net.daringfireball.markdown all
duti -s com.brian.neovim-ghostty .md all
duti -s com.brian.neovim-ghostty .markdown all
```

## Verification

```bash
duti -x md
# Neovim
# /Users/brian/Applications/Neovim.app
# com.brian.neovim-ghostty

open ~/.config/nvim/CLAUDE.md
# A new Ghostty window opens with CLAUDE.md loaded in Neovim.
```

## Known limitation

`.mdx` could not be registered. macOS assigns it a dynamic UTI
(`dyn.ah62d4qmxhk2x45peta`), and `duti` rejects those:

```
failed to set com.brian.neovim-ghostty as handler for dyn.ah62d4qmxhk2x45peta (error -50)
```

To cover `.mdx`, declare a custom exported UTI for it in the app's `Info.plist`,
or set the handler per-file in Finder with **Get Info → Open With → Change All**.

## Uninstall

```bash
rm -rf ~/Applications/Neovim.app
duti -s com.apple.dt.Xcode net.daringfireball.markdown all   # previous handler
```

## Extending to other file types

Add more `LSItemContentTypes` entries in step 2, then repeat steps 3 and 4 with
the new UTI or extension. Examples: `public.json`, `public.yaml`,
`public.shell-script`.
