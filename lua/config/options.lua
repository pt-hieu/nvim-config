-- See `:help vim.o` and `:help option-list`

-- Line numbers
vim.o.number = true
vim.o.relativenumber = true

-- Mouse
vim.o.mouse = 'a'

-- Hide mode (already in status line)
vim.o.showmode = false

-- Clipboard sync (scheduled to avoid startup delay)
vim.schedule(function()
	vim.o.clipboard = 'unnamedplus'
end)

-- Indentation
vim.o.breakindent = true

-- Undo
vim.o.undofile = true

-- Search
vim.o.ignorecase = true
vim.o.smartcase = true

-- Sign column
vim.o.signcolumn = 'yes'

-- Timing
vim.o.updatetime = 250
vim.o.timeoutlen = 300

-- Splits
vim.o.splitright = true
vim.o.splitbelow = true

-- Whitespace display
vim.o.list = true
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }

-- Live preview for substitutions
vim.o.inccommand = 'split'

-- Cursor line
vim.o.cursorline = true

-- Confirm dialogs
vim.o.confirm = true

-- Title bar
vim.o.title = true
vim.o.titlestring = "%{fnamemodify(getcwd(), ':t')}"

-- Scroll context
vim.o.scrolloff = 10

-- Tab settings
vim.o.tabstop = 2
vim.o.shiftwidth = 2
vim.o.softtabstop = 2
vim.o.expandtab = false
