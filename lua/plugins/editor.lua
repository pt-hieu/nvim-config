return {
	-- Auto-detect indentation
	{ 'NMAC427/guess-indent.nvim', event = 'BufReadPost' },

	-- Auto-close brackets/quotes
	{
		'windwp/nvim-autopairs',
		event = 'InsertEnter',
		opts = {},
	},

	-- Auto-close and rename HTML/XML tags
	{
		'windwp/nvim-ts-autotag',
		ft = { 'html', 'xml', 'javascript', 'javascriptreact', 'typescript', 'typescriptreact', 'vue', 'svelte' },
		opts = {},
	},

	-- Yazi file manager integration
	{
		'mikavilpas/yazi.nvim',
		version = '*',
		event = 'VeryLazy',
		dependencies = {
			{ 'nvim-lua/plenary.nvim', lazy = true },
		},
		keys = {
			{ '<leader>-', '<cmd>Yazi<cr>', desc = 'Open yazi at current file' },
			{ '<leader>cw', '<cmd>Yazi cwd<cr>', desc = 'Open yazi in cwd' },
			{ '<c-up>', '<cmd>Yazi toggle<cr>', desc = 'Resume yazi session' },
		},
		opts = {
			open_for_directories = false,
			yazi_floating_window_border = 'rounded',
			keymaps = { show_help = '<f1>' },
		},
		init = function()
			vim.g.loaded_netrwPlugin = 1
		end,
	},
}
