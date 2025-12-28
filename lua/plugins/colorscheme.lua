return {
	'baliestri/aura-theme',
	lazy = false,
	priority = 1000,
	config = function(plugin)
		vim.opt.rtp:append(plugin.dir .. '/packages/neovim')
		vim.cmd([[colorscheme aura-dark]])

		-- Transparent background
		vim.api.nvim_set_hl(0, 'Normal', { bg = 'none' })
		vim.api.nvim_set_hl(0, 'NormalFloat', { bg = 'none' })
		vim.api.nvim_set_hl(0, 'NormalNC', { bg = 'none' })
		vim.api.nvim_set_hl(0, 'SignColumn', { bg = 'none' })
		vim.api.nvim_set_hl(0, 'FloatBorder', { fg = '#a277ff' })
		vim.api.nvim_set_hl(0, 'WinSeparator', { fg = '#6d6d6d' })

		-- JSX/TSX syntax highlighting
		vim.api.nvim_set_hl(0, '@tag', { fg = '#f694ff' })
		vim.api.nvim_set_hl(0, '@tag.tsx', { link = '@tag' })
		vim.api.nvim_set_hl(0, '@tag.builtin', { fg = '#82e2ff' })
		vim.api.nvim_set_hl(0, '@tag.delimiter', { fg = '#6d6d6d' })
		vim.api.nvim_set_hl(0, '@constructor', { fg = '#ffca85' })
		vim.api.nvim_set_hl(0, '@tag.attribute', { fg = '#61ffca' })

		-- Unified visual selection background
		vim.api.nvim_set_hl(0, 'Visual', { bg = '#4a4458' })

		-- LSP reference highlights (underline only, no background)
		vim.api.nvim_set_hl(0, 'LspReferenceText', { underdouble = true })
		vim.api.nvim_set_hl(0, 'LspReferenceRead', { underdouble = true })
		vim.api.nvim_set_hl(0, 'LspReferenceWrite', { underdouble = true })

		-- Line numbers with increased contrast
		vim.api.nvim_set_hl(0, 'LineNr', { fg = '#8d8d8d' })
	end,
}
