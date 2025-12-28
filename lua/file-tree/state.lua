local M = {}

M.state = {
	root = nil,
	tree = nil,
	visible_lines = {},
	current_idx = 1,
	expanded_paths = {},
	git_status = {},
	filter_text = '',
	filter_mode = false,
	filter_input = nil,
	layout = nil,
	tree_popup = nil,
	preview_popup = nil,
	tree_buf = nil,
	preview_buf = nil,
}

function M.init_state(root)
	M.state.root = root
	M.state.tree = nil
	M.state.visible_lines = {}
	M.state.current_idx = 1
	M.state.expanded_paths = { [root] = true }
	M.state.git_status = {}
	M.state.filter_text = ''
	M.state.filter_mode = false
	M.state.filter_input = nil
end

function M.get_current_node()
	return M.state.visible_lines[M.state.current_idx]
end

function M.is_expanded(path)
	return M.state.expanded_paths[path] == true
end

function M.toggle_expanded(path)
	M.state.expanded_paths[path] = not M.state.expanded_paths[path]
end

function M.set_expanded(path, expanded)
	M.state.expanded_paths[path] = expanded or nil
end

function M.move_selection(direction)
	local new_idx = M.state.current_idx + direction
	if new_idx >= 1 and new_idx <= #M.state.visible_lines then
		M.state.current_idx = new_idx
		return true
	end
	return false
end

function M.set_selection(idx)
	if idx >= 1 and idx <= #M.state.visible_lines then
		M.state.current_idx = idx
		return true
	end
	return false
end

function M.find_node_index(path)
	for i, node in ipairs(M.state.visible_lines) do
		if node.path == path then
			return i
		end
	end
	return nil
end

function M.reset_state()
	if M.state.filter_input then
		M.state.filter_input:unmount()
	end
	if M.state.layout then
		M.state.layout:unmount()
	end
	M.state = {
		root = nil,
		tree = nil,
		visible_lines = {},
		current_idx = 1,
		expanded_paths = {},
		git_status = {},
		filter_text = '',
		filter_mode = false,
		filter_input = nil,
		layout = nil,
		tree_popup = nil,
		preview_popup = nil,
		tree_buf = nil,
		preview_buf = nil,
	}
end

return M
