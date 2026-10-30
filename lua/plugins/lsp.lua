return {
	-- Lua LSP for Neovim config
	{
		'folke/lazydev.nvim',
		ft = 'lua',
		opts = {
			library = {
				{ path = '${3rd}/luv/library', words = { 'vim%.uv' } },
			},
		},
	},

	-- ESLint disable comments
	{
		'chrisgrieser/nvim-rulebook',
		keys = {
			{
				'grI',
				function()
					require('rulebook').ignoreRule()
				end,
				desc = 'LSP: Ignore [R]ule',
				mode = { 'n', 'x' },
			},
		},
	},

	-- LSP progress notifications
	{
		'j-hui/fidget.nvim',
		event = 'LspAttach',
		opts = {
			notification = {
				window = {
					winblend = 0,
					border = 'rounded',
				},
			},
		},
		config = function(_, opts)
			require('fidget').setup(opts)
			-- Aura theme colors
			vim.api.nvim_set_hl(0, 'FidgetTitle', { fg = '#a277ff', bold = true }) -- purple
			vim.api.nvim_set_hl(0, 'FidgetTask', { fg = '#edecee' }) -- white
			vim.api.nvim_set_hl(0, 'FidgetProgress', { fg = '#61ffca' }) -- green
		end,
	},

	-- LSP Configuration
	{
		'neovim/nvim-lspconfig',
		-- Load after filetype detection: vim.lsp.enable() fires FileType on open buffers, which during a
		-- session restore would make :setf skip the buffer being read
		event = 'FileType',
		-- TypeScript 7 for projects pinned to an older TypeScript; mason's tsgo is a stale preview
		build = function()
			vim.system({ 'npm', 'install', '--prefix', vim.fn.stdpath('data') .. '/typescript-7', 'typescript@7' }):wait()
		end,
		dependencies = {
			{ 'mason-org/mason.nvim', opts = {} },
			'mason-org/mason-lspconfig.nvim',
			'WhoIsSethDaniel/mason-tool-installer.nvim',
			'saghen/blink.cmp',
		},
		config = function()
			-- LspAttach autocmd for keymaps
			vim.api.nvim_create_autocmd('LspAttach', {
				group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
				callback = function(event)
					local map = function(keys, func, desc, mode)
						mode = mode or 'n'
						vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
					end

					map('grn', vim.lsp.buf.rename, '[R]e[n]ame')
					map('gra', vim.lsp.buf.code_action, '[G]oto Code [A]ction', { 'n', 'x' })
					map('grr', require('telescope.builtin').lsp_references, '[G]oto [R]eferences')
					map('gri', require('telescope.builtin').lsp_implementations, '[G]oto [I]mplementation')
					map('grd', require('telescope.builtin').lsp_definitions, '[G]oto [D]efinition')
					map('grD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')
					map('gO', require('telescope.builtin').lsp_document_symbols, 'Open Document Symbols')
					map('gW', require('telescope.builtin').lsp_dynamic_workspace_symbols, 'Open Workspace Symbols')
					map('grt', require('telescope.builtin').lsp_type_definitions, '[G]oto [T]ype Definition')
					map('gh', vim.lsp.buf.hover, 'Hover Documentation')
					map('<C-k>', vim.lsp.buf.signature_help, 'Signature Help', 'i')

					local function client_supports_method(client, method, bufnr)
						if vim.fn.has('nvim-0.11') == 1 then
							return client:supports_method(method, bufnr)
						else
							return client.supports_method(method, { bufnr = bufnr })
						end
					end

					-- Document highlight on CursorHold
					local client = vim.lsp.get_client_by_id(event.data.client_id)
					if
						client
						and client_supports_method(client, vim.lsp.protocol.Methods.textDocument_documentHighlight, event.buf)
					then
						local highlight_augroup = vim.api.nvim_create_augroup('kickstart-lsp-highlight', { clear = false })
						vim.api.nvim_create_autocmd('CursorHold', {
							buffer = event.buf,
							group = highlight_augroup,
							callback = vim.lsp.buf.document_highlight,
						})

						vim.api.nvim_create_autocmd('CursorMoved', {
							buffer = event.buf,
							group = highlight_augroup,
							callback = vim.lsp.buf.clear_references,
						})

						vim.api.nvim_create_autocmd('LspDetach', {
							group = vim.api.nvim_create_augroup('kickstart-lsp-detach', { clear = true }),
							callback = function(event2)
								vim.lsp.buf.clear_references()
								vim.api.nvim_clear_autocmds({ group = 'kickstart-lsp-highlight', buffer = event2.buf })
							end,
						})
					end

				end,
			})

			-- Diagnostic config
			vim.diagnostic.config({
				severity_sort = true,
				float = { border = 'rounded', source = 'if_many' },
				underline = { severity = vim.diagnostic.severity.ERROR },
				signs = vim.g.have_nerd_font and {
					text = {
						[vim.diagnostic.severity.ERROR] = '󰅚 ',
						[vim.diagnostic.severity.WARN] = '󰀪 ',
						[vim.diagnostic.severity.INFO] = '󰋽 ',
						[vim.diagnostic.severity.HINT] = '󰌶 ',
					},
				} or {},
				virtual_text = {
					prefix = '󰅚',
					spacing = 4,
					source = 'if_many',
				},
			})

			-- Capabilities from blink.cmp
			local capabilities = require('blink.cmp').get_lsp_capabilities()

			-- LSP servers
			local servers = {
				lua_ls = {
					settings = {
						Lua = {
							completion = {
								callSnippet = 'Replace',
							},
						},
					},
				},
				typos_lsp = {
					init_options = {
						diagnosticSeverity = 'Hint',
					},
				},
				eslint = {},
				tsgo = {
					-- Use the project's TypeScript when it is 7 or newer, otherwise the copy installed by build
					cmd = function(dispatchers, config)
						local tsc = vim.fn.stdpath('data') .. '/typescript-7/node_modules/.bin/tsc'
						local ok, pkg = pcall(function()
							return vim.json.decode(table.concat(vim.fn.readfile(config.root_dir .. '/node_modules/typescript/package.json'), '\n'))
						end)
						if ok and tonumber(pkg.version:match('^%d+')) >= 7 then
							tsc = config.root_dir .. '/node_modules/.bin/tsc'
						end
						return vim.lsp.rpc.start({ tsc, '--lsp', '--stdio' }, dispatchers)
					end,
					settings = {
						typescript = {
							inlayHints = {
								parameterNames = { enabled = 'literals' },
								variableTypes = { enabled = true },
								functionLikeReturnTypes = { enabled = true },
							},
						},
						javascript = {
							inlayHints = {
								parameterNames = { enabled = 'literals' },
								variableTypes = { enabled = true },
								functionLikeReturnTypes = { enabled = true },
							},
						},
					},
				},
				jsonls = {
					settings = {
						json = {
							validate = { enable = true },
						},
					},
				},
			}

			-- Ensure tools are installed
			local ensure_installed = vim.tbl_filter(function(name)
				return name ~= 'tsgo'
			end, vim.tbl_keys(servers))
			vim.list_extend(ensure_installed, {
				'stylua',
				'prettierd',
				'eslint_d',
			})
			require('mason-tool-installer').setup({ ensure_installed = ensure_installed, start_delay = 3000 })

			for server_name, server_config in pairs(servers) do
				server_config.capabilities =
					vim.tbl_deep_extend('force', {}, capabilities, server_config.capabilities or {})
				vim.lsp.config(server_name, server_config)
			end

			require('mason-lspconfig').setup({
				ensure_installed = {},
				automatic_enable = { exclude = { 'ts_ls' } },
			})
			vim.lsp.enable('tsgo')
		end,
	},
}
