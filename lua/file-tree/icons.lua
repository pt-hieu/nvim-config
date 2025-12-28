local M = {}

-- Nerd Font fallback icons
M.folder_closed = '\u{f07b}' --
M.folder_open = '\u{f07c}' --
M.file_default = '\u{f15b}' --

-- Cache
local devicons = nil

function M.get_icon(name, type, is_open)
	if type == 'directory' then
		local icon = is_open and M.folder_open or M.folder_closed
		local hl = is_open and 'FileTreeFolderOpen' or 'FileTreeFolder'
		return icon, hl
	end

	-- Lazy require on first file icon request
	if not devicons then
		local ok, mod = pcall(require, 'nvim-web-devicons')
		if ok then
			devicons = mod
		end
	end

	if devicons then
		local ext = vim.fn.fnamemodify(name, ':e')
		local icon, hl = devicons.get_icon(name, ext, { default = true })
		if icon and icon ~= '' then
			return icon, hl or 'FileTreeFile'
		end
	end

	return M.file_default, 'FileTreeFile'
end

-- Git status indicators
local git_indicators = {
	modified = { icon = '●', hl = 'FileTreeGitModified' },
	staged = { icon = '✓', hl = 'FileTreeGitStaged' },
	staged_modified = { icon = '●', hl = 'FileTreeGitStaged' },
	untracked = { icon = '?', hl = 'FileTreeGitUntracked' },
	ignored = { icon = '◌', hl = 'FileTreeGitIgnored' },
	dirty = { icon = '●', hl = 'FileTreeGitDirty' },
}

function M.get_git_indicator(status)
	local indicator = git_indicators[status]
	if indicator then
		return indicator.icon, indicator.hl
	end
	return nil, nil
end

return M
