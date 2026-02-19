-- Diagnostics panel
return {
	'folke/trouble.nvim',
	dependencies = { 'nvim-tree/nvim-web-devicons' },
	cmd = 'Trouble',
	keys = {
		{ '<leader>xx', '<cmd>Trouble diagnostics toggle<cr>', desc = 'Diagnostics (Trouble)' },
		{ '<leader>xX', '<cmd>Trouble diagnostics toggle filter.buf=0<cr>', desc = 'Buffer Diagnostics (Trouble)' },
		{ '<leader>xs', '<cmd>Trouble symbols toggle focus=false<cr>', desc = 'Symbols (Trouble)' },
		{ '<leader>xr', '<cmd>Trouble lsp_references toggle<cr>', desc = 'LSP References (Trouble)' },
		{ '<leader>xl', '<cmd>Trouble loclist toggle<cr>', desc = 'Location List (Trouble)' },
		{ '<leader>xq', '<cmd>Trouble qflist toggle<cr>', desc = 'Quickfix List (Trouble)' },
	},
	opts = {
		-- Floating window mode
		mode = 'diagnostics',
		focus = true,
		win = {
			type = 'float',
			position = 'center',
			border = 'rounded',
			size = {
				width = 0.8,
				height = 0.6,
			},
		},
		-- Buffer-local keymaps
		keys = {
			q = 'close', -- Press 'q' to close Trouble window
		},
		-- Aura theme icons (same as LSP diagnostics)
		icons = {
			error = '󰅚 ',
			warning = '󰀪 ',
			info = '󰋽 ',
			hint = '󰌶 ',
			other = ' ',
		},
	},
	config = function(_, opts)
		require('trouble').setup(opts)

		local colors = require('config.colors')

		-- Set highlight groups
		vim.api.nvim_set_hl(0, 'TroubleNormal', { bg = colors.black })
		vim.api.nvim_set_hl(0, 'TroubleNormalNC', { bg = colors.black })
		vim.api.nvim_set_hl(0, 'TroubleText', { fg = colors.white })
		vim.api.nvim_set_hl(0, 'TroubleCount', { fg = colors.purple, bold = true })
		vim.api.nvim_set_hl(0, 'TroublePos', { fg = colors.gray })
		vim.api.nvim_set_hl(0, 'TroubleSource', { fg = colors.gray })
		vim.api.nvim_set_hl(0, 'TroubleFoldIcon', { fg = colors.purple })
		vim.api.nvim_set_hl(0, 'TroubleIndent', { fg = colors.gray })

		-- Severity-specific colors
		vim.api.nvim_set_hl(0, 'TroubleError', { fg = colors.red })
		vim.api.nvim_set_hl(0, 'TroubleWarning', { fg = colors.orange })
		vim.api.nvim_set_hl(0, 'TroubleInformation', { fg = colors.blue })
		vim.api.nvim_set_hl(0, 'TroubleHint', { fg = colors.green })

		-- Sign colors (for icons)
		vim.api.nvim_set_hl(0, 'TroubleSignError', { fg = colors.red })
		vim.api.nvim_set_hl(0, 'TroubleSignWarning', { fg = colors.orange })
		vim.api.nvim_set_hl(0, 'TroubleSignInformation', { fg = colors.blue })
		vim.api.nvim_set_hl(0, 'TroubleSignHint', { fg = colors.green })
	end,
}
