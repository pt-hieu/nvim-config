return {
	'nvim-telescope/telescope.nvim',
	cmd = 'Telescope',
	keys = { '<leader>sh', '<leader>sk', '<leader>sf', '<leader>ss', '<leader>sw', '<leader>sg', '<leader>sgf', '<leader>st', '<leader>sd', '<leader>sr', '<leader>/', '<leader>s/', '<leader>sn', '<leader>sS' },
	dependencies = {
		'nvim-lua/plenary.nvim',
		{
			'nvim-telescope/telescope-fzf-native.nvim',
			build = 'make',
			cond = function()
				return vim.fn.executable('make') == 1
			end,
		},
		{ 'nvim-telescope/telescope-ui-select.nvim' },
		{ 'nvim-tree/nvim-web-devicons', enabled = vim.g.have_nerd_font },
		{ 'kkharji/sqlite.lua' },
		{
			'danielfalk/smart-open.nvim',
			branch = '0.2.x',
			dependencies = { 'kkharji/sqlite.lua' },
		},
	},
	config = function()
		local colors = require('config.colors')

		-- Set Aura purple border highlight
		vim.api.nvim_set_hl(0, 'TelescopeBorder', { fg = colors.purple })
		vim.api.nvim_set_hl(0, 'TelescopePromptBorder', { fg = colors.purple })
		vim.api.nvim_set_hl(0, 'TelescopeResultsBorder', { fg = colors.purple })
		vim.api.nvim_set_hl(0, 'TelescopePreviewBorder', { fg = colors.purple })

		local ignore_patterns = {
			'node_modules',
			'.git/',
			'dist/',
			'build/',
			'__generated__',
			'__snapshots__/',
			'%.snap$',
			'%.test%.',
			'%.spec%.',
		}

		require('telescope').setup({
			defaults = {
				borderchars = { '─', '│', '─', '│', '╭', '╮', '╯', '╰' },
				vimgrep_arguments = {
					'rg',
					'--color=never',
					'--no-heading',
					'--with-filename',
					'--line-number',
					'--column',
					'--smart-case',
				},
			},
			pickers = {
				find_files = { file_ignore_patterns = ignore_patterns },
				live_grep = { file_ignore_patterns = ignore_patterns },
			},
			extensions = {
				['ui-select'] = {
					require('telescope.themes').get_dropdown(),
				},
				['smart_open'] = {
					match_algorithm = 'fzf',
					cwd_only = true,
				},
			},
		})

		-- Load extensions
		pcall(require('telescope').load_extension, 'fzf')
		pcall(require('telescope').load_extension, 'ui-select')
		pcall(require('telescope').load_extension, 'session-lens')
		pcall(require('telescope').load_extension, 'smart_open')

		-- Keymaps
		local builtin = require('telescope.builtin')
		vim.keymap.set('n', '<leader>sh', builtin.help_tags, { desc = '[S]earch [H]elp' })
		vim.keymap.set('n', '<leader>sk', builtin.keymaps, { desc = '[S]earch [K]eymaps' })
		vim.keymap.set('n', '<leader>sf', function()
			require('telescope').extensions.smart_open.smart_open()
		end, { desc = '[S]earch [F]iles (smart)' })
		vim.keymap.set('n', '<leader>ss', builtin.builtin, { desc = '[S]earch [S]elect Telescope' })
		vim.keymap.set('n', '<leader>sw', builtin.grep_string, { desc = '[S]earch current [W]ord' })
		vim.keymap.set('n', '<leader>sg', builtin.live_grep, { desc = '[S]earch by [G]rep' })
		vim.keymap.set('n', '<leader>sgf', function()
			local pattern = vim.fn.input('File pattern (e.g., *.lua): ')
			if pattern ~= '' then
				builtin.live_grep({ glob_pattern = pattern })
			end
		end, { desc = '[S]earch [G]rep [F]iltered by file' })
		vim.keymap.set('n', '<leader>st', builtin.git_status, { desc = '[S]earch git s[T]atus' })
		vim.keymap.set('n', '<leader>sd', builtin.diagnostics, { desc = '[S]earch [D]iagnostics' })
		vim.keymap.set('n', '<leader>sr', builtin.resume, { desc = '[S]earch [R]esume' })

		vim.keymap.set('n', '<leader>/', function()
			builtin.current_buffer_fuzzy_find(require('telescope.themes').get_dropdown({
				winblend = 10,
				previewer = false,
			}))
		end, { desc = '[/] Fuzzily search in current buffer' })

		vim.keymap.set('n', '<leader>s/', function()
			builtin.live_grep({
				grep_open_files = true,
				prompt_title = 'Live Grep in Open Files',
			})
		end, { desc = '[S]earch [/] in Open Files' })

		vim.keymap.set('n', '<leader>sn', function()
			builtin.find_files({ cwd = vim.fn.stdpath('config') })
		end, { desc = '[S]earch [N]eovim files' })

		vim.keymap.set('n', '<leader>sS', '<cmd>SearchSession<cr>', { desc = '[S]earch [S]essions' })
	end,
}
