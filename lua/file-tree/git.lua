local M = {}

local state = require('file-tree.state')

function M.get_status(root_path, callback)
	local stdout = {}

	vim.fn.jobstart({ 'git', 'status', '--porcelain', '-u', '--ignored' }, {
		cwd = root_path,
		stdout_buffered = true,
		on_stdout = function(_, data)
			if data then
				stdout = data
			end
		end,
		on_exit = function(_, exit_code)
			if exit_code == 0 then
				local status_map = M.parse_status(stdout, root_path)
				callback(status_map)
			else
				callback({})
			end
		end,
	})
end

function M.parse_status(lines, root_path)
	local status_map = {}

	for _, line in ipairs(lines) do
		if line and line ~= '' then
			-- Format: XY filename
			-- X = index status, Y = worktree status
			local xy = line:sub(1, 2)
			local filepath = line:sub(4)

			-- Handle renamed files: "R  old -> new"
			if filepath:find(' %-> ') then
				filepath = filepath:match(' %-> (.+)$')
			end

			-- Remove quotes if present
			filepath = filepath:gsub('^"', ''):gsub('"$', '')

			local full_path = root_path .. '/' .. filepath
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

function M.parse_xy(xy)
	local x, y = xy:sub(1, 1), xy:sub(2, 2)

	-- Ignored
	if xy == '!!' then
		return 'ignored'
	end

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
