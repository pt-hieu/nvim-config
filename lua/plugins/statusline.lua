return {
	'rebelot/heirline.nvim',
	dependencies = { 'nvim-tree/nvim-web-devicons' },
	config = function()
		local conditions = require('heirline.conditions')
		local utils = require('heirline.utils')

		-- Cached optional module references (loaded once on first use)
		local _llm_ghost = nil
		local _bb_state = nil
		local function get_llm_ghost()
			if _llm_ghost == nil then
				local ok, m = pcall(require, 'llm-ghost')
				_llm_ghost = ok and m or false
			end
			return _llm_ghost ~= false and _llm_ghost or nil
		end
		local function get_bb_state()
			if _bb_state == nil then
				local ok, m = pcall(require, 'bitbucket.state')
				_bb_state = ok and m or false
			end
			return _bb_state ~= false and _bb_state or nil
		end

		-- Aura theme colors
		local colors = vim.tbl_extend('force', require('config.colors'), { fg = '#edecee' })

		-- Mode colors
		local mode_colors = {
			n = colors.purple,
			i = colors.green,
			v = colors.pink,
			V = colors.pink,
			['\22'] = colors.pink,
			c = colors.orange,
			s = colors.blue,
			S = colors.blue,
			['\19'] = colors.blue,
			R = colors.red,
			r = colors.red,
			['!'] = colors.orange,
			t = colors.green,
		}

		require('heirline').setup({
			opts = {
				colors = colors,
			},
			statusline = {
				-- Mode
				{
					init = function(self)
						self.mode = vim.fn.mode(1)
					end,
					static = {
						mode_names = {
							n = 'NORMAL',
							no = 'N-PENDING',
							i = 'INSERT',
							ic = 'INSERT',
							v = 'VISUAL',
							V = 'V-LINE',
							['\22'] = 'V-BLOCK',
							c = 'COMMAND',
							s = 'SELECT',
							S = 'S-LINE',
							['\19'] = 'S-BLOCK',
							R = 'REPLACE',
							Rv = 'V-REPLACE',
							cv = 'EX',
							ce = 'EX',
							r = 'REPLACE',
							rm = 'MORE',
							['r?'] = 'CONFIRM',
							['!'] = 'SHELL',
							t = 'TERMINAL',
						},
					},
					provider = function(self)
						return '  ' .. (self.mode_names[self.mode] or self.mode) .. '  '
					end,
					hl = function(self)
						local mode = self.mode:sub(1, 1)
						return { bg = mode_colors[mode] or colors.purple, fg = colors.black, bold = true }
					end,
					update = { 'ModeChanged', pattern = '*:*' },
				},

				-- Mode separator
				{
					provider = '',
					hl = function()
						local mode = vim.fn.mode(1):sub(1, 1)
						return { fg = mode_colors[mode] or colors.purple, bg = colors.bg }
					end,
				},

				-- Diff (from gitsigns)
				{
					condition = function()
						return vim.b.gitsigns_status_dict ~= nil
					end,
					init = function(self)
						self.status = vim.b.gitsigns_status_dict or {}
					end,
					{
						provider = function(self)
							local added = self.status.added or 0
							return added > 0 and (' +' .. added) or ''
						end,
						hl = { fg = colors.green, bg = colors.black },
					},
					{
						provider = function(self)
							local changed = self.status.changed or 0
							return changed > 0 and (' ~' .. changed) or ''
						end,
						hl = { fg = colors.orange, bg = colors.black },
					},
					{
						provider = function(self)
							local removed = self.status.removed or 0
							return removed > 0 and (' -' .. removed) or ''
						end,
						hl = { fg = colors.red, bg = colors.black },
					},
					{ provider = ' ', hl = { bg = colors.black } },
				},

				-- Diagnostics
				{
					condition = conditions.has_diagnostics,
					static = {
						error_icon = '󰅚 ',
						warn_icon = '󰀪 ',
						info_icon = '󰋽 ',
						hint_icon = '󰌶 ',
					},
					init = function(self)
						local counts = vim.diagnostic.count(0)
						self.errors = counts[vim.diagnostic.severity.ERROR] or 0
						self.warnings = counts[vim.diagnostic.severity.WARN] or 0
						self.hints = counts[vim.diagnostic.severity.HINT] or 0
						self.info = counts[vim.diagnostic.severity.INFO] or 0
					end,
					update = { 'DiagnosticChanged', 'BufEnter' },
					{
						provider = function(self)
							return self.errors > 0 and (self.error_icon .. self.errors .. ' ') or ''
						end,
						hl = { fg = colors.red, bg = colors.black },
					},
					{
						provider = function(self)
							return self.warnings > 0 and (self.warn_icon .. self.warnings .. ' ') or ''
						end,
						hl = { fg = colors.orange, bg = colors.black },
					},
					{
						provider = function(self)
							return self.info > 0 and (self.info_icon .. self.info .. ' ') or ''
						end,
						hl = { fg = colors.blue, bg = colors.black },
					},
					{
						provider = function(self)
							return self.hints > 0 and (self.hint_icon .. self.hints .. ' ') or ''
						end,
						hl = { fg = colors.green, bg = colors.black },
					},
				},

				-- LLM Ghost server status
				{
					provider = ' 󱙺 ',
					hl = function()
						local ghost = get_llm_ghost()
						local connected = ghost and ghost.is_server_ok()
						return { fg = connected and colors.purple or colors.red, bg = colors.black }
					end,
				},

				-- Bitbucket PR status (shows review mode when active)
				{
					provider = function()
						local bb_state = get_bb_state()
						if not bb_state then
							return ' 󰊢 '
						end
						local has_pr = bb_state.has_pr()
						local review_mode = bb_state.is_review_mode()
						if review_mode then
							return ' 󰊢 R '
						elseif has_pr then
							return ' 󰊢 '
						else
							return ' 󰊢 '
						end
					end,
					hl = function()
						local bb_state = get_bb_state()
						if not bb_state then
							return { fg = colors.gray, bg = colors.black }
						end
						local review_mode = bb_state.is_review_mode()
						local has_pr = bb_state.has_pr()
						if review_mode then
							return { fg = colors.purple, bg = colors.black, bold = true }
						elseif has_pr then
							return { fg = colors.green, bg = colors.black }
						else
							return { fg = colors.gray, bg = colors.black }
						end
					end,
				},

				-- Filename (fills available space)
				{
					provider = function()
						local filename = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ':t')
						if filename == '' then
							return '[No Name]'
						end
						return ' ' .. filename
					end,
					hl = { fg = colors.white, bg = colors.black },
				},
				{
					provider = function()
						if vim.bo.modified then
							return ' ●'
						elseif vim.bo.readonly then
							return ' '
						end
						return ''
					end,
					hl = { fg = colors.orange, bg = colors.black },
				},
				{ provider = '%=', hl = { bg = colors.black } },

				-- LSP clients
				{
					condition = conditions.lsp_attached,
					update = { 'LspAttach', 'LspDetach' },
					static = {
						lsp_labels = {
							ts_ls = 'TS',
							tsgo = 'TSGo',
							eslint = 'ESLint',
							lua_ls = 'Lua',
							jsonls = 'JSON',
							typos_lsp = 'Typos',
						},
					},
					provider = function(self)
						local clients = vim.lsp.get_clients({ bufnr = 0 })
						if #clients == 0 then
							return ''
						end
						local names = {}
						for _, client in ipairs(clients) do
							local label = self.lsp_labels[client.name] or client.name
							table.insert(names, label)
						end
						return ' ' .. table.concat(names, ', ') .. ' '
					end,
					hl = { fg = colors.black, bg = colors.blue },
				},

				-- Filetype with devicon
				{
					init = function(self)
						local filename = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ':t')
						local extension = vim.fn.fnamemodify(filename, ':e')
						self.icon, self.icon_color = require('nvim-web-devicons').get_icon_color(filename, extension, { default = true })
					end,
					provider = function(self)
						local ft = vim.bo.filetype
						if ft == '' then
							return ''
						end
						return ' ' .. (self.icon or '') .. ' ' .. ft .. ' '
					end,
					hl = { fg = colors.black, bg = colors.green },
				},

				-- Right separator
				{
					provider = '',
					hl = function()
						local mode = vim.fn.mode(1):sub(1, 1)
						return { fg = mode_colors[mode] or colors.purple, bg = colors.bg }
					end,
				},

				-- Progress
				{
					provider = '  %3p%%  ',
					hl = function()
						local mode = vim.fn.mode(1):sub(1, 1)
						return { bg = mode_colors[mode] or colors.purple, fg = colors.black }
					end,
				},

				-- Location separator
				{
					provider = '',
					hl = function()
						local mode = vim.fn.mode(1):sub(1, 1)
						return { fg = colors.black, bg = mode_colors[mode] or colors.purple }
					end,
				},

				-- Location
				{
					provider = '  %l:%c  ',
					hl = { bg = colors.black, fg = colors.white, bold = true },
				},
			},
		})
	end,
}
