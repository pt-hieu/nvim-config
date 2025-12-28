return {
	-- Ensure devicons is available
	{ 'nvim-tree/nvim-web-devicons', lazy = true },

	{
		dir = vim.fn.stdpath('config') .. '/lua/file-tree',
		name = 'file-tree',
		dependencies = {
			'nvim-lua/plenary.nvim',
			'MunifTanjim/nui.nvim',
			{ 'nvim-tree/nvim-web-devicons', opts = {} },
		},
		cmd = 'FileTree',
		keys = {
			{ '<leader>e', '<cmd>FileTree<cr>', desc = 'File [E]xplorer' },
		},
		config = function()
			local file_tree = require('file-tree')

			vim.api.nvim_create_user_command('FileTree', function()
				file_tree.open()
			end, { desc = 'Open file tree explorer' })

			-- Aura theme highlight groups
			vim.api.nvim_set_hl(0, 'FileTreeFolder', { fg = '#ffca85', bold = true })
			vim.api.nvim_set_hl(0, 'FileTreeFolderOpen', { fg = '#ffca85' })
			vim.api.nvim_set_hl(0, 'FileTreeFile', { fg = '#edecee' })
			vim.api.nvim_set_hl(0, 'FileTreeSelection', { bg = '#3d375e' })
			vim.api.nvim_set_hl(0, 'FileTreeBorder', { fg = '#a277ff' })
			vim.api.nvim_set_hl(0, 'FileTreeIndent', { fg = '#4d4d4d' })
			vim.api.nvim_set_hl(0, 'FileTreeRootName', { fg = '#a277ff', bold = true })

			-- Preview highlight groups
			vim.api.nvim_set_hl(0, 'FileTreePreviewBorder', { fg = '#61ffca' })

			-- Git status highlight groups
			vim.api.nvim_set_hl(0, 'FileTreeGitModified', { fg = '#a277ff' })
			vim.api.nvim_set_hl(0, 'FileTreeGitStaged', { fg = '#61ffca' })
			vim.api.nvim_set_hl(0, 'FileTreeGitUntracked', { fg = '#6d6d6d' })
			vim.api.nvim_set_hl(0, 'FileTreeGitIgnored', { fg = '#4d4d4d' })
			vim.api.nvim_set_hl(0, 'FileTreeGitDirty', { fg = '#ffca85' })
		end,
	},
}
