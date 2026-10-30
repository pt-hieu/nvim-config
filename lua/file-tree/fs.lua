local M = {}

function M.scan_directory(path)
	local entries = {}
	local handle = vim.uv.fs_scandir(path)

	if not handle then
		return entries
	end

	while true do
		local name, type = vim.uv.fs_scandir_next(handle)
		if not name then
			break
		end

		-- Determine type if not provided (some filesystems don't report it).
		-- Symlinks are resolved to what they point at.
		if not type or type == 'link' then
			local stat = vim.uv.fs_stat(path .. '/' .. name)
			type = stat and stat.type or 'file'
		end

		table.insert(entries, {
			name = name,
			type = type == 'directory' and 'directory' or 'file',
			path = path .. '/' .. name,
			lower_name = name:lower(),
		})
	end

	-- Sort: directories first, then alphabetically
	table.sort(entries, function(a, b)
		if a.type ~= b.type then
			return a.type == 'directory'
		end
		return a.lower_name < b.lower_name
	end)

	return entries
end

function M.is_directory(path)
	local stat = vim.uv.fs_stat(path)
	return stat and stat.type == 'directory'
end

function M.is_file(path)
	local stat = vim.uv.fs_stat(path)
	return stat and stat.type == 'file'
end

function M.exists(path)
	return vim.uv.fs_stat(path) ~= nil
end

function M.get_parent(path)
	return vim.fn.fnamemodify(path, ':h')
end

function M.get_name(path)
	return vim.fn.fnamemodify(path, ':t')
end

-- CRUD Operations

function M.create_file(path)
	-- Create parent directories if needed
	local parent = M.get_parent(path)
	if not M.exists(parent) then
		vim.fn.mkdir(parent, 'p')
	end

	-- Create empty file
	local ok = vim.fn.writefile({}, path)
	return ok == 0
end

function M.create_directory(path)
	local ok = vim.fn.mkdir(path, 'p')
	return ok == 1
end

function M.rename(old_path, new_path)
	local ok = vim.fn.rename(old_path, new_path)
	return ok == 0
end

function M.delete(path)
	-- 'rf' flag for recursive force delete
	local ok = vim.fn.delete(path, 'rf')
	return ok == 0
end

return M
