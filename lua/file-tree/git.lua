local M = {}

-- Two passes because the untracked modes are mutually exclusive. `-u` lists
-- every untracked file individually, but it also expands an ignored directory
-- into its contents, which floods the map and never marks the directory
-- itself. `ls-files --directory` reports a fully ignored directory as one
-- entry, which is what lets an entire `node_modules/` grey out. Both run with
-- `-z`, so paths are NUL-separated and never quoted.
local STATUS_ARGS = { 'git', 'status', '--porcelain', '-z', '-u' }
local IGNORED_ARGS = { 'git', 'ls-files', '-z', '-o', '-i', '--exclude-standard', '--directory' }

local function run_git(root_path, args, on_done)
	vim.system(args, { cwd = root_path, text = true }, function(result)
		on_done(result.code == 0 and vim.split(result.stdout or '', '\0', { plain = true }) or {})
	end)
end

function M.get_status(root_path, callback)
	local status_map, ignored_paths

	local function finish()
		if status_map and ignored_paths then
			callback(status_map, ignored_paths)
		end
	end

	run_git(root_path, STATUS_ARGS, function(entries)
		status_map = M.parse_status(entries, root_path)
		finish()
	end)

	run_git(root_path, IGNORED_ARGS, function(entries)
		ignored_paths = M.parse_ignored(entries, root_path)
		finish()
	end)
end

-- Directories carry a trailing slash that tree node paths do not have.
local function strip_trailing_slash(filepath)
	return (filepath:gsub('/$', ''))
end

-- Takes the NUL-separated entries of `git status --porcelain -z`.
function M.parse_status(entries, root_path)
	local status_map = {}
	local root_len = #root_path
	local i = 1

	while i <= #entries do
		local entry = entries[i]
		i = i + 1

		if entry ~= '' then
			-- Format: XY filename
			-- X = index status, Y = worktree status
			local xy = entry:sub(1, 2)
			local full_path = root_path .. '/' .. strip_trailing_slash(entry:sub(4))
			local status = M.parse_xy(xy)

			-- Renames and copies are followed by the original path as its own
			-- entry; only the new path exists on disk.
			local x, y = xy:sub(1, 1), xy:sub(2, 2)
			if x == 'R' or x == 'C' or y == 'R' or y == 'C' then
				i = i + 1
			end

			if status then
				status_map[full_path] = status

				-- Also mark parent directories. Marking a path always marks its
				-- ancestors, so the first marked parent ends the walk.
				local parent = full_path:match('^(.*)/')
				while parent and #parent > root_len and not status_map[parent] do
					status_map[parent] = 'dirty'
					parent = parent:match('^(.*)/')
				end
			end
		end
	end

	return status_map
end

-- Returns the ignored roots as a set: paths that are themselves ignored, and
-- whose descendants are therefore ignored too.
function M.parse_ignored(entries, root_path)
	local ignored_paths = {}

	for _, entry in ipairs(entries) do
		if entry ~= '' then
			ignored_paths[root_path .. '/' .. strip_trailing_slash(entry)] = true
		end
	end

	return ignored_paths
end

function M.is_ignored(path, ignored_paths)
	if not ignored_paths then
		return false
	end

	-- Check the path, then each ancestor, against the set.
	while path do
		if ignored_paths[path] then
			return true
		end
		path = path:match('^(.*)/')
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
