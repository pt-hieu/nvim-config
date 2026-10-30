-- Files above this size skip treesitter and indent guides
local max_size = 1024 * 1024

return function(bufnr)
	local ok, stat = pcall(vim.uv.fs_stat, vim.api.nvim_buf_get_name(bufnr))
	return ok and stat ~= nil and stat.size > max_size
end
