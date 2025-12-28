return {
	'saghen/blink.cmp',
	event = 'VimEnter',
	version = '1.*',
	dependencies = {
		{
			'L3MON4D3/LuaSnip',
			version = '2.*',
			build = (function()
				if vim.fn.has('win32') == 1 or vim.fn.executable('make') == 0 then
					return
				end
				return 'make install_jsregexp'
			end)(),
			opts = {},
		},
		'folke/lazydev.nvim',
		'xzbdmw/colorful-menu.nvim',
	},
	---@module 'blink.cmp'
	---@type blink.cmp.Config
	opts = {
		keymap = {
			preset = 'default',
			-- Custom overrides for macOS input source conflict
			['<M-.>'] = { 'show', 'show_documentation', 'hide_documentation' },
			['<C-Space>'] = {},
			-- Accept with tab or enter
			['<Tab>'] = { 'accept', 'fallback' },
			['<CR>'] = { 'accept', 'fallback' },
		},

		appearance = {
			nerd_font_variant = 'mono',
		},

		completion = {
			accept = {
				auto_brackets = {
					enabled = false,
					kind_resolution = { enabled = false },
					semantic_token_resolution = { enabled = false },
				},
			},
			ghost_text = { enabled = false },
			list = {
				selection = {
					preselect = true,
					auto_insert = false,
				},
			},
			documentation = {
				auto_show = true,
				auto_show_delay_ms = 200,
				window = { border = 'rounded' },
			},
			menu = {
				border = 'rounded',
				draw = {
					columns = {
						{ 'kind_icon' },
						{ 'label', 'label_description', gap = 1 },
					},
					components = {
						label = {
							text = function(ctx)
								return require('colorful-menu').blink_components_text(ctx)
							end,
							highlight = function(ctx)
								return require('colorful-menu').blink_components_highlight(ctx)
							end,
						},
						label_description = {
							text = function(ctx)
								return ctx.item.labelDetails and ctx.item.labelDetails.description
									or ctx.item.detail
									or ''
							end,
							highlight = 'BlinkCmpLabelDescription',
						},
					},
				},
			},
		},

		sources = {
			default = { 'lsp', 'path', 'snippets', 'lazydev' },
			providers = {
				lazydev = { module = 'lazydev.integrations.blink', score_offset = 100 },
			},
		},

		snippets = { preset = 'luasnip' },

		fuzzy = { implementation = 'lua' },

		signature = { enabled = false },
	},
	config = function(_, opts)
		-- Load custom snippets
		require('luasnip.loaders.from_vscode').lazy_load({ paths = { vim.fn.stdpath('config') .. '/snippets' } })

		-- Set purple border for completion windows
		vim.api.nvim_set_hl(0, 'BlinkCmpMenuBorder', { fg = '#a277ff' })
		vim.api.nvim_set_hl(0, 'BlinkCmpDocBorder', { fg = '#a277ff' })
		require('blink.cmp').setup(opts)
	end,
}
