local state = require('file-tree.state')
local tree = require('file-tree.tree')
local ui = require('file-tree.ui')
local fs = require('file-tree.fs')
local git = require('file-tree.git')

local M = {}

function M.open()
	-- Get current buffer's file path before opening tree
	local current_file = vim.api.nvim_buf_get_name(0)

	-- Get root directory (current working directory)
	local root = vim.fn.getcwd()

	-- Initialize state
	state.init_state(root)

	-- Build tree from root
	state.state.tree = tree.build_tree(root)

	-- Expand path to current file if it exists within root
	if current_file ~= '' and current_file:sub(1, #root) == root then
		M.reveal_path(current_file)
	end

	-- Create and show UI
	ui.create_and_show()

	-- Select the current file after render
	if current_file ~= '' then
		local idx = state.find_node_index(current_file)
		if idx then
			state.set_selection(idx)
			ui.update_cursor_highlight()
			ui.sync_cursor_position()
			ui.preview_current()
		end
	end

	-- Fetch git status async and re-render when done
	git.get_status(root, function(status_map)
		vim.schedule(function()
			state.state.git_status = status_map
			-- Only re-render if UI is still open
			if state.state.tree_buf and vim.api.nvim_buf_is_valid(state.state.tree_buf) then
				ui.render_tree()
			end
		end)
	end)
end

function M.reveal_path(path)
	-- Expand all parent directories to reveal the file
	local root = state.state.root
	local relative = path:sub(#root + 2) -- Remove root/ prefix
	local parts = vim.split(relative, '/', { plain = true })

	local current_path = root
	for i = 1, #parts - 1 do -- Exclude the file itself
		current_path = current_path .. '/' .. parts[i]
		state.set_expanded(current_path, true)

		-- Load children for this path
		local node = M.find_node_by_path(state.state.tree, current_path)
		if node then
			tree.load_children(node)
		end
	end
end

function M.find_node_by_path(node, target_path)
	if node.path == target_path then
		return node
	end

	if node.children then
		for _, child in ipairs(node.children) do
			local found = M.find_node_by_path(child, target_path)
			if found then
				return found
			end
		end
	end

	return nil
end

return M
