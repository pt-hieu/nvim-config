return {
	'stevearc/conform.nvim',
	event = { 'BufWritePre' },
	cmd = { 'ConformInfo' },
	keys = {
		{
			'<M-\\>',
			function()
				require('conform').format({ async = true, lsp_format = 'fallback' })
			end,
			mode = '',
			desc = 'Format buffer',
		},
	},
	opts = {
		notify_on_error = false,
		format_on_save = function(bufnr)
			-- Disable format_on_save for C/C++
			local disable_filetypes = { c = true, cpp = true }
			if disable_filetypes[vim.bo[bufnr].filetype] then
				return nil
			else
				return {
					timeout_ms = 500,
					lsp_format = 'fallback',
				}
			end
		end,
		formatters_by_ft = {
			lua = { 'stylua' },
			javascript = { 'prettier' },
			typescript = { 'prettier' },
			javascriptreact = { 'prettier' },
			typescriptreact = { 'prettier' },
			css = { 'prettier' },
			html = { 'prettier' },
			json = { 'prettier' },
		},
	},
}
