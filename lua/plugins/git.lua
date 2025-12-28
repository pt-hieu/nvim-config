return {
	-- Git signs in gutter
	{
		'lewis6991/gitsigns.nvim',
		opts = {
			signs = {
				add = { text = '+' },
				change = { text = '~' },
				delete = { text = '_' },
				topdelete = { text = '‾' },
				changedelete = { text = '~' },
			},
			current_line_blame = true,
			current_line_blame_opts = {
				delay = 300,
			},
		},
	},

	-- VSCode-style diff viewer
	{
		'esmuellert/vscode-diff.nvim',
		dependencies = { 'MunifTanjim/nui.nvim' },
		cmd = 'CodeDiff',
		keys = {
			{ '<leader>gd', '<cmd>CodeDiff file HEAD<cr>', desc = 'Diff current file' },
			{ '<leader>gD', '<cmd>CodeDiff<cr>', desc = 'Diff explorer' },
		},
		opts = {
			highlights = {
				line_insert = '#1a332b',
				line_delete = '#331a1a',
				char_insert = '#1f4d3d',
				char_delete = '#ff6767',
			},
		},
	},
}
