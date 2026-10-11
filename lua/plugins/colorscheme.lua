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

		-- Markdown headings: Aura accents, with backgrounds pre-blended into #15141b since alpha is unsupported
		local heading_colors = {
			{ fg = '#a277ff', bg = '#2a233d' },
			{ fg = '#61ffca', bg = '#203735' },
			{ fg = '#ffca85', bg = '#382f2b' },
			{ fg = '#f694ff', bg = '#37273d' },
			{ fg = '#82e2ff', bg = '#25333d' },
			{ fg = '#ff6767', bg = '#382026' },
		}
		for level, colors in ipairs(heading_colors) do
			vim.api.nvim_set_hl(0, '@markup.heading.' .. level .. '.markdown', { fg = colors.fg, bold = true })
			vim.api.nvim_set_hl(0, 'RenderMarkdownH' .. level .. 'Bg', { bg = colors.bg })
		end

		-- Markdown body: aura-dark leaves @markup.* unset, and render-markdown's code background falls back to ColorColumn's stock gray
		vim.api.nvim_set_hl(0, '@markup.raw.markdown_inline', { fg = '#ffca85' })
		vim.api.nvim_set_hl(0, '@markup.link', { fg = '#82e2ff' })
		vim.api.nvim_set_hl(0, '@markup.link.label', { fg = '#82e2ff' })
		vim.api.nvim_set_hl(0, '@markup.link.url', { fg = '#6d6d6d', underline = true })
		vim.api.nvim_set_hl(0, '@markup.list', { fg = '#a277ff' })
		vim.api.nvim_set_hl(0, '@markup.quote', { italic = true })
		vim.api.nvim_set_hl(0, 'RenderMarkdownCode', { bg = '#1f1d29' })
		vim.api.nvim_set_hl(0, 'RenderMarkdownCodeInline', { fg = '#ffca85', bg = '#26232f' })
		vim.api.nvim_set_hl(0, 'RenderMarkdownBullet', { fg = '#a277ff' })
		vim.api.nvim_set_hl(0, 'RenderMarkdownQuote', { fg = '#a277ff' })
		vim.api.nvim_set_hl(0, 'RenderMarkdownDash', { fg = '#3d375e' })
		vim.api.nvim_set_hl(0, 'RenderMarkdownChecked', { fg = '#61ffca' })
		vim.api.nvim_set_hl(0, 'RenderMarkdownUnchecked', { fg = '#6d6d6d' })
		vim.api.nvim_set_hl(0, 'RenderMarkdownTableHead', { fg = '#a277ff' })
		vim.api.nvim_set_hl(0, 'RenderMarkdownTableRow', { fg = '#3d375e' })

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
