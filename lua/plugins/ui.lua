return {
	-- Pending keybinds popup
	{
		'folke/which-key.nvim',
		event = 'VimEnter',
		opts = {
			delay = 0,
			icons = {
				mappings = vim.g.have_nerd_font,
				keys = vim.g.have_nerd_font and {} or {
					Up = '<Up> ',
					Down = '<Down> ',
					Left = '<Left> ',
					Right = '<Right> ',
					C = '<C-…> ',
					M = '<M-…> ',
					D = '<D-…> ',
					S = '<S-…> ',
					CR = '<CR> ',
					Esc = '<Esc> ',
					ScrollWheelDown = '<ScrollWheelDown> ',
					ScrollWheelUp = '<ScrollWheelUp> ',
					NL = '<NL> ',
					BS = '<BS> ',
					Space = '<Space> ',
					Tab = '<Tab> ',
					F1 = '<F1>',
					F2 = '<F2>',
					F3 = '<F3>',
					F4 = '<F4>',
					F5 = '<F5>',
					F6 = '<F6>',
					F7 = '<F7>',
					F8 = '<F8>',
					F9 = '<F9>',
					F10 = '<F10>',
					F11 = '<F11>',
					F12 = '<F12>',
				},
			},
			win = {
				border = 'rounded',
				padding = { 1, 2 },
				title = true,
				title_pos = 'center',
			},
			layout = {
				spacing = 3,
				align = 'left',
			},
			spec = {
				{ '<leader>b', group = '[B]itbucket' },
				{ '<leader>s', group = '[S]earch' },
				{ '<leader>t', group = '[T]oggle' },
				{ '<leader>x', group = 'Trouble' },
				{ '<leader>h', group = 'Git [H]unk', mode = { 'n', 'v' } },
			},
		},
		config = function(_, opts)
			local wk = require('which-key')
			wk.setup(opts)

			-- Aura theme highlights
			vim.api.nvim_set_hl(0, 'WhichKeyNormal', { bg = 'none' })
			vim.api.nvim_set_hl(0, 'WhichKey', { fg = '#a277ff' })
			vim.api.nvim_set_hl(0, 'WhichKeyGroup', { fg = '#61ffca' })
			vim.api.nvim_set_hl(0, 'WhichKeyDesc', { fg = '#edecee' })
			vim.api.nvim_set_hl(0, 'WhichKeySeparator', { fg = '#6d6d6d' })
			vim.api.nvim_set_hl(0, 'WhichKeyBorder', { fg = '#a277ff' })
		end,
	},

	-- Highlight TODO/FIXME/NOTE in comments
	{
		'folke/todo-comments.nvim',
		event = 'VimEnter',
		dependencies = { 'nvim-lua/plenary.nvim' },
		opts = { signs = false },
	},

	-- Mini.nvim modules
	{
		'echasnovski/mini.nvim',
		config = function()
			-- Better text objects
			require('mini.ai').setup({ n_lines = 500 })

			-- Add/delete/replace surroundings (disabled - conflicts with 's' key)
			-- require('mini.surround').setup()
		end,
	},

	-- Noice UI
	{
		'folke/noice.nvim',
		event = 'VeryLazy',
		dependencies = {
			'MunifTanjim/nui.nvim',
			{
				'rcarriga/nvim-notify',
				opts = {
					background_colour = '#000000',
				},
			},
		},
		opts = {
			cmdline = {
				enabled = true,
				view = 'cmdline_popup',
				format = {
					cmdline = { icon = '>' },
					search_down = { icon = '🔍⌄' },
					search_up = { icon = '🔍⌃' },
					filter = { icon = '$' },
					lua = { icon = '☾' },
					help = { icon = '?' },
				},
			},
			messages = {
				enabled = true,
				view = 'notify',
				view_error = 'notify',
				view_warn = 'notify',
				view_history = 'messages',
				view_search = 'virtualtext',
			},
			popupmenu = {
				enabled = true,
				backend = 'nui',
			},
			lsp = {
				override = {
					['vim.lsp.util.convert_input_to_markdown_lines'] = true,
					['vim.lsp.util.stylize_markdown'] = true,
					['cmp.entry.get_documentation'] = true,
				},
			},
			presets = {
				bottom_search = false,
				command_palette = true,
				long_message_to_split = true,
				inc_rename = false,
				lsp_doc_border = true,
			},
		},
	},
}
