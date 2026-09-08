local M = {}

-- Two passes because the untracked modes are mutually exclusive. `-u` lists
-- every untracked file individually, but it also expands an ignored directory
-- into its contents, which floods the map and never marks the directory
-- itself. The collapsed pass reports a fully ignored directory as one entry,
-- which is what lets an entire `node_modules/` grey out.
local STATUS_ARGS = { 'git', 'status', '--porcelain', '-u' }
local IGNORED_ARGS = { 'git', 'status', '--porcelain', '--ignored' }

local function run_git(root_path, args, on_done)
	local lines = {}

	vim.fn.jobstart(args, {
		cwd = root_path,
		stdout_buffered = true,
		on_stdout = function(_, data)
			if data then
				lines = data
			end
		end,
		on_exit = function(_, exit_code)
			on_done(exit_code == 0 and lines or {})
		end,
	})
end

function M.get_status(root_path, callback)
	local status_map, ignored_paths

	local function finish()
		if status_map and ignored_paths then
			callback(status_map, ignored_paths)
		end
	end

	run_git(root_path, STATUS_ARGS, function(lines)
		status_map = M.parse_status(lines, root_path)
		finish()
	end)

	run_git(root_path, IGNORED_ARGS, function(lines)
		ignored_paths = M.parse_ignored(lines, root_path)
		finish()
	end)
end

local function normalize_path(filepath)
	-- Renames are reported as "old -> new"; only the new path exists on disk.
	if filepath:find(' %-> ') then
		filepath = filepath:match(' %-> (.+)$')
	end

	-- Paths containing special characters come back quoted.
	filepath = filepath:gsub('^"', ''):gsub('"$', '')

	-- Directories carry a trailing slash that tree node paths do not have.
	return (filepath:gsub('/$', ''))
end

function M.parse_status(lines, root_path)
	local status_map = {}

	for _, line in ipairs(lines) do
		if line and line ~= '' then
			-- Format: XY filename
			-- X = index status, Y = worktree status
			local xy = line:sub(1, 2)
			local full_path = root_path .. '/' .. normalize_path(line:sub(4))
			local status = M.parse_xy(xy)

			if status then
				status_map[full_path] = status

				-- Also mark parent directories
				local parent = vim.fn.fnamemodify(full_path, ':h')
				while parent ~= root_path and parent ~= '' do
					if not status_map[parent] then
						status_map[parent] = 'dirty'
					end
					parent = vim.fn.fnamemodify(parent, ':h')
				end
			end
		end
	end

	return status_map
end

-- Returns the ignored roots: paths that are themselves ignored, and whose
-- descendants are therefore ignored too.
function M.parse_ignored(lines, root_path)
	local ignored_paths = {}

	for _, line in ipairs(lines) do
		if line and line:sub(1, 2) == '!!' then
			table.insert(ignored_paths, root_path .. '/' .. normalize_path(line:sub(4)))
		end
	end

	return ignored_paths
end

function M.is_ignored(path, ignored_paths)
	if not ignored_paths then
		return false
	end

	for _, ignored_path in ipairs(ignored_paths) do
		if path == ignored_path or path:sub(1, #ignored_path + 1) == ignored_path .. '/' then
			return true
		end
	end

	return false
end

function M.parse_xy(xy)
	local x, y = xy:sub(1, 1), xy:sub(2, 2)

	-- Untracked
	if xy == '??' then
		return 'untracked'
	end

	-- Staged (index has changes)
	if x == 'A' or x == 'M' or x == 'D' or x == 'R' or x == 'C' then
		if y == ' ' then
			return 'staged'
		else
			return 'staged_modified' -- staged + unstaged changes
		end
	end

	-- Modified (worktree has changes)
	if y == 'M' or y == 'D' then
		return 'modified'
	end

	return nil
end

return M
