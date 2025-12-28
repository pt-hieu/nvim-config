-- Kickstart.nvim - Modular Configuration
-- This config has been reorganized into logical modules for easier maintenance.
--
-- Structure:
--   lua/config/    - Core Neovim settings (options, keymaps, autocmds)
--   lua/plugins/   - Plugin specifications organized by functionality

-- Leader keys (must be set before plugins load)
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '
vim.g.have_nerd_font = true

-- Bootstrap lazy.nvim plugin manager
local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not (vim.uv or vim.loop).fs_stat(lazypath) then
	local lazyrepo = 'https://github.com/folke/lazy.nvim.git'
	local out = vim.fn.system({ 'git', 'clone', '--filter=blob:none', '--branch=stable', lazyrepo, lazypath })
	if vim.v.shell_error ~= 0 then
		error('Error cloning lazy.nvim:\n' .. out)
	end
end
vim.opt.rtp:prepend(lazypath)

-- Load core configuration
require('config.options')
require('config.keymaps')
require('config.autocmds')

-- Load plugins (auto-imports all files in lua/plugins/)
require('lazy').setup('plugins', {
	performance = {
		rtp = {
			disabled_plugins = {
				'matchparen',
			},
		},
	},
	ui = {
		icons = vim.g.have_nerd_font and {} or {
			cmd = '⌘',
			config = '🛠',
			event = '📅',
			ft = '📂',
			init = '⚙',
			keys = '🗝',
			plugin = '🔌',
			runtime = '💻',
			require = '🌙',
			source = '📄',
			start = '🚀',
			task = '📌',
			lazy = '💤 ',
		},
	},
})
