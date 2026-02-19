# Neovim Configuration

## Overview
Modular **Kickstart.nvim** based configuration optimized for maintainability. Core settings separated from plugin specs for easy navigation and modification.

## Structure

```
~/.config/nvim/
├── init.lua (49 lines)              # Bootstrap: leader keys + lazy.nvim + module imports
├── lazy-lock.json                   # Plugin version lockfile
└── lua/
    ├── config/
    │   ├── options.lua              # All vim.opt settings
    │   ├── keymaps.lua              # Core keymaps (non-plugin)
    │   ├── autocmds.lua             # Autocommands
    │   └── colors.lua               # Shared Aura color palette
    ├── bitbucket/                   # Bitbucket PR comments (local plugin)
    │   ├── init.lua                 # Public API
    │   ├── api.lua                  # Bitbucket REST client
    │   ├── git.lua                  # Git utilities
    │   ├── state.lua                # Buffer state management
    │   └── display.lua              # Virtual text rendering
    └── plugins/
        ├── bitbucket.lua            # Bitbucket plugin spec
        ├── colorscheme.lua          # Aura theme
        ├── completion.lua           # Blink.cmp + LuaSnip
        ├── editor.lua               # Yazi, autopairs, guess-indent, nvim-ts-autotag
        ├── formatting.lua           # Conform.nvim
        ├── git.lua                  # Gitsigns
        ├── lsp.lua                  # LSP + Mason + nvim-rulebook
        ├── statusline.lua           # Heirline statusline
        ├── session.lua              # Auto-session management
        ├── telescope.lua            # Telescope + keymaps + session-lens
        ├── treesitter.lua           # Syntax highlighting
        └── ui.lua                   # Which-key, mini, noice, diagnostics
```

## Plugin Manager
**lazy.nvim** - Modern lazy-loading plugin manager
- Auto-installs on first run
- Lazy-loads plugins by event/command/keys
- Commands: `:Lazy`, `:Lazy update`

## Core Settings (lua/config/options.lua)

### Display
- `number = true` + `relativenumber = true` - Hybrid line numbers
- `cursorline = true` - Highlight current line
- `scrolloff = 10` - Keep 10 lines visible above/below cursor
- `list = true` - Show whitespace chars (tab: `» `, trail: `·`)
- `inccommand = 'split'` - Live preview for substitutions

### Editing
- `clipboard = 'unnamedplus'` - Sync with system clipboard
- `breakindent = true` - Smart line wrapping
- `undofile = true` - Persistent undo history
- `ignorecase = true` + `smartcase = true` - Smart case search
- `confirm = true` - Confirm dialog for unsaved changes

### Performance
- `updatetime = 250` - Faster CursorHold triggers
- `timeoutlen = 300` - Quick key sequence timeout

### Leader Key
- `<Space>` is leader key (set in init.lua before plugins load)

## Autocommands (lua/config/autocmds.lua)
- **Highlight on yank** - Briefly highlight yanked text
- **Cursor position restore** - Jump to last cursor position when reopening files

## Installed Plugins

### Core Dependencies
- **plenary.nvim** - Lua utility library
- **nui.nvim** - UI component library
- **nvim-web-devicons** - File icons (Nerd Font optional)

### File Navigation (lua/plugins/editor.lua, lua/plugins/telescope.lua, lua/plugins/session.lua)
- **telescope.nvim** - Fuzzy finder for files, buffers, LSP, grep
  - Extensions: `fzf-native`, `ui-select`, `session-lens`, `smart-open`
  - Key patterns: `<leader>s*` (search commands)
- **smart-open.nvim** - Intelligent file finder with proximity + frecency sorting
  - Prioritizes files near current buffer + frequently edited files
  - Uses SQLite for history tracking
  - Replaces find_files/buffers/oldfiles with unified picker
- **file-tree** - Custom file explorer (local plugin, `lua/file-tree/`)
  - Float mode only: `<leader>e`
  - Split layout: tree (40%) + file preview (60%)
  - CRUD: `a` create, `r` rename, `d` delete
  - Filter: `/`, Grep in path: `f`
  - Git status indicators (right-aligned)
- **auto-session** - Automatic session management
  - Auto-saves on exit, auto-restores on startup (per directory)
  - Suppressed dirs: `~/`, `~/.config`, `/tmp`
  - Search sessions: `<leader>sS` (Telescope)

### LSP & Completion (lua/plugins/lsp.lua, lua/plugins/completion.lua)
- **nvim-lspconfig** - LSP client configurations
- **mason.nvim** - LSP/tool installer UI
- **mason-lspconfig.nvim** - Bridge between mason + lspconfig
- **mason-tool-installer.nvim** - Auto-install tools
- **fidget.nvim** - LSP progress UI
- **nvim-rulebook** - Add eslint-disable comments for diagnostics
  - Key: `grI` - Insert `// eslint-disable-next-line <rule>` comment
- **blink.cmp** - Autocompletion engine (v1.*)
  - Preset: `default` (Ctrl-Y to accept)
  - Lua fuzzy implementation
- **LuaSnip** - Snippet engine (v2.*)
- **lazydev.nvim** - Lua LSP for Neovim config/API

Configured LSPs:
- `lua_ls` (Lua Language Server)
- `eslint` (ESLint Language Server)
- Auto-installed tools: `stylua`, `prettier`, `eslint_d`

### Formatting (lua/plugins/formatting.lua)
- **conform.nvim** - Format on save + manual format
  - Key: `<M-\>` - Format buffer
  - Auto-formats on save (500ms timeout)
  - Configured formatters:
    - Lua: `stylua`
    - JS/TS/React: `prettier`
    - CSS/HTML/JSON: `prettier`

### Git Integration (lua/plugins/git.lua, lua/plugins/git-history.lua)
- **gitsigns.nvim** - Git signs in gutter + blame
  - Shows: add `+`, change `~`, delete `_`
  - `current_line_blame = true` (300ms delay)
- **git-history** - Custom git history inspector (local plugin)
  - View commit history for current buffer in float window
  - Split view: commit list (40%) + unified diff (60%)
  - Navigate commits with `j`/`k`, auto-preview changes
  - Diff shows additions (green +), deletions (red -), context (white)
  - Tab to switch between commit list and diff preview
  - Keymap: `<leader>gh`
  - Close: `q` or `Esc`

### Bitbucket Integration (lua/plugins/bitbucket.lua, lua/bitbucket/)
- **bitbucket** - Custom PR comments display (local plugin)
  - Display PR comments as virtual text inline in buffers
  - Auto-detects PR from current git branch
  - Shows line-level and file-level comments
  - Aura theme styling with bordered comment boxes
  - Auto-loads on BufEnter with 500ms debounce
  - Statusline indicator: 󰊢 (gray=no PR, green=PR detected)
  - Keymaps: `<leader>bc` (toggle), `<leader>br` (refresh)
  - Commands: `:BBComments`, `:BBRefresh`
  - Requires env vars: `BITBUCKET_USERNAME`, `BITBUCKET_TOKEN`

### Statusline (lua/plugins/statusline.lua)
- **heirline.nvim** - Highly customizable statusline built from scratch
  - Components (left to right):
    - Mode (color-coded: purple=normal, green=insert, pink=visual, etc.)
    - Git diff (+added ~changed -removed) from gitsigns
    - Diagnostics (󰅚 errors, 󰀪 warnings, 󰋽 info, 󰌶 hints)
    - LLM Ghost status (󱙺 purple=connected, red=disconnected)
    - Bitbucket PR status (󰊢 gray=no PR, green=PR detected)
    - Filename (with modified ● indicator)
    - LSP clients (blue background)
    - Filetype (green background)
    - Progress percentage
    - Line:column location
  - Uses Aura theme colors
  - Powerline separators (`` ``)

### Code Intelligence (lua/plugins/treesitter.lua)
- **nvim-treesitter** - Syntax highlighting + code understanding
  - Languages: bash, c, html, lua, markdown, vim, js, ts, tsx, json, css
  - Auto-installs missing parsers
- **todo-comments.nvim** - Highlight TODO/FIXME/NOTE in comments

### Editing Enhancements (lua/plugins/editor.lua, lua/plugins/ui.lua)
- **nvim-autopairs** - Auto-close brackets/quotes
- **mini.nvim** - Multiple modules:
  - `mini.ai` - Better text objects (500 lines)
  - `mini.surround` - Add/delete/replace surroundings
- **which-key.nvim** - Popup for pending keybinds
  - Delay: 0ms (instant)
  - Groups: `<leader>s` (Search), `<leader>t` (Toggle), `<leader>h` (Git Hunk)
- **guess-indent.nvim** - Auto-detect tabs vs spaces

### Theme & UI (lua/plugins/colorscheme.lua, lua/plugins/ui.lua)
- **aura-theme** - Dark theme
  - Applied: `aura-dark` colorscheme
  - Transparent background enabled
- **tiny-inline-diagnostic.nvim** - Inline diagnostic messages
- **noice.nvim** - Enhanced UI for messages, cmdline, popupmenu
  - Centered command palette
  - Notify for messages
- **nvim-notify** - Notification manager

### Aura Dark Color Palette
| Color | Hex | Token | Usage |
|-------|-----|-------|-------|
| Purple | `#a277ff` | accent1 | Primary |
| Green | `#61ffca` | accent2 | Secondary |
| Orange | `#ffca85` | accent3 | Tertiary |
| Pink | `#f694ff` | accent6 | Quaternary |
| Blue | `#82e2ff` | accent32 | Quinary |
| Red | `#ff6767` | accent5 | Senary |
| White | `#edecee` | accent7 | Foregrounds |
| Gray | `#6d6d6d` | accent8 | Comments |
| Black | `#15141b` | accent12 | Backgrounds |
| Selection | `#3d375e` | accent20 | Selections |

- **Do not** use colors with alpha channel since it Neovim can not parse them

## Key Bindings

### Core Mappings (lua/config/keymaps.lua)
```
<Esc>           - Clear search highlights
<leader>q       - Open diagnostic quickfix list
<leader>cp      - Copy file path to clipboard
<Esc><Esc>      - Exit terminal mode (in terminal)

# Window Navigation
<C-h/j/k/l>     - Move focus to left/down/up/right window
```

### Telescope (lua/plugins/telescope.lua)
```
<leader>sh      - Search help
<leader>sk      - Search keymaps
<leader>sf      - Search files (smart-open: proximity + frecency)
<leader>ss      - Search select Telescope
<leader>sS      - Search sessions (saved sessions)
<leader>sw      - Search current word
<leader>sg      - Search by grep (live)
<leader>sgf     - Search by grep filtered by file pattern
<leader>st      - Search git status
<leader>sd      - Search diagnostics
<leader>sr      - Search resume (last search)
<leader>/       - Fuzzy search in current buffer
<leader>s/      - Search in open files
<leader>sn      - Search Neovim config files
```

### LSP Mappings (lua/plugins/lsp.lua)
```
grn             - Rename symbol
gra             - Code action
grr             - Go to references
gri             - Go to implementation
grI             - Ignore rule (add eslint-disable comment)
grd             - Go to definition
grD             - Go to declaration
gO              - Open document symbols
gW              - Open workspace symbols
grt             - Go to type definition
<leader>th      - Toggle inlay hints
```

### File Tree (lua/plugins/file-tree.lua)
```
<leader>e       - Open file explorer (float, split layout)
q / <Esc>       - Close explorer
j/k             - Navigate
l / <CR>        - Expand dir / open file
h               - Collapse dir or go to parent
a               - Create file or directory
r               - Rename
d               - Delete
/               - Filter
f               - Grep in path (opens telescope)
<Tab>           - Switch to preview pane
```

### Format (lua/plugins/formatting.lua)
```
<M-\>           - Format buffer (async)
```

### Git History (lua/plugins/git-history.lua)
```
<leader>gh      - Open git history for current buffer

# Inside git history float:
j/k             - Navigate commits (in commit list)
<CR>            - Refresh preview (in commit list)
<Tab>           - Switch between commit list and diff preview
j/k             - Scroll diff (in preview pane)
q/<Esc>         - Close window (from either pane)
<C-w>w          - Standard Vim window navigation
```

### Bitbucket (lua/plugins/bitbucket.lua)
```
<leader>bc      - Toggle PR comments visibility
<leader>br      - Refresh PR comments from API
```

## LSP Configuration (lua/plugins/lsp.lua)

### Capabilities
- Enhanced by `blink.cmp` for completion
- Supports: hover, completion, goto definition, find references, rename, code actions

### Diagnostics Config
- Sorted by severity
- Rounded borders on float windows
- Only ERROR underlines (not WARN/INFO/HINT)
- Virtual text shows diagnostic messages
- Nerd Font icons (if enabled): 󰅚 (error), 󰀪 (warn), 󰋽 (info), 󰌶 (hint)

### Features
- Document highlight on CursorHold (highlights references)
- Auto-clears on CursorMove
- Inlay hints toggleable (if LSP supports)

## Modular Design

### Configuration Organization
- **lua/config/** - Core Neovim settings (options, keymaps, autocmds)
- **lua/plugins/** - Plugin specifications organized by functionality
  - Each file returns a plugin spec (table or array of tables)
  - Lazy.nvim auto-imports all files in `lua/plugins/`
  - Plugin-specific keymaps stay with their plugin config

### Benefits
- **Easy to find** - Logical grouping by feature (git.lua, lsp.lua, etc.)
- **Easy to improve** - Each file 100-500 lines vs 1000+ monolith
- **Easy to debug** - Clear separation of concerns

### Adding Plugins
Create new file in `lua/plugins/` or add to existing file:

```lua
-- lua/plugins/my-plugin.lua
return {
  'author/plugin-name',
  opts = {
    -- config here
  },
}
```

## Extension Guide

### Add LSP Server
Edit `lua/plugins/lsp.lua`, update `servers` table:
```lua
local servers = {
  lua_ls = { ... },
  ts_ls = {},        -- TypeScript
  gopls = {},        -- Go
  pyright = {},      -- Python
  rust_analyzer = {}, -- Rust
}
```

### Add Formatter
Edit `lua/plugins/formatting.lua`, update `formatters_by_ft`:
```lua
formatters_by_ft = {
  lua = { 'stylua' },
  python = { 'black', 'isort' },
  go = { 'gofmt' },
}
```

### Add Treesitter Language
Edit `lua/plugins/treesitter.lua`, update `ensure_installed`:
```lua
ensure_installed = {
  'bash', 'c', 'lua', 'markdown',
  'python', 'go', 'rust',  -- add here
}
```

### Add Keymap
- **Core keymap**: Edit `lua/config/keymaps.lua`
- **Plugin keymap**: Edit the plugin file (e.g., `lua/plugins/telescope.lua`)

### Add Option
Edit `lua/config/options.lua`:
```lua
vim.o.wrap = true
vim.o.spell = true
```

## Health Check
Run `:checkhealth` to verify setup and catch issues.

## Quick Reference

### Files by Purpose
| Task | File |
|------|------|
| Vim settings | `lua/config/options.lua` |
| Core keymaps | `lua/config/keymaps.lua` |
| Autocommands | `lua/config/autocmds.lua` |
| LSP servers | `lua/plugins/lsp.lua` |
| Formatters | `lua/plugins/formatting.lua` |
| Treesitter langs | `lua/plugins/treesitter.lua` |
| Theme | `lua/plugins/colorscheme.lua` |
| File explorer | `lua/plugins/file-tree.lua`, `lua/file-tree/` |
| Search/fuzzy find | `lua/plugins/telescope.lua` |
| Session management | `lua/plugins/session.lua` |
| Git integration | `lua/plugins/git.lua` |
| Git history inspector | `lua/plugins/git-history.lua`, `lua/git-history/` |
| Bitbucket PR comments | `lua/plugins/bitbucket.lua`, `lua/bitbucket/` |
| Statusline | `lua/plugins/statusline.lua` |
| UI/UX plugins | `lua/plugins/ui.lua` |

## Summary
Modular Kickstart config with:
- Clean separation: settings in `config/`, plugins in `plugins/`
- Modern ecosystem: lazy.nvim, telescope, treesitter, LSP
- LSP with Mason for easy tool management
- Auto-session restore (per directory)
- Neo-tree (sidebar + float mode, lazy-loaded)
- Transparent Aura dark theme
- Git integration (gitsigns, git-history)
- Bitbucket PR comments inline display
- Custom heirline statusline with Aura colors
- Format on save (conform.nvim)
- ESLint disable comments (nvim-rulebook)
- Quality of life: autopairs, which-key, inline diagnostics, noice, cursor restore
