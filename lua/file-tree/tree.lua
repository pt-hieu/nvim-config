local fs = require('file-tree.fs')
local state = require('file-tree.state')

local M = {}

function M.build_node(path, depth)
	local name = fs.get_name(path)
	local is_dir = fs.is_directory(path)

	local node = {
		name = name,
		path = path,
		type = is_dir and 'directory' or 'file',
		depth = depth,
		children = nil,
	}

	return node
end

function M.load_children(node)
	if node.type ~= 'directory' then
		return
	end

	if node.children ~= nil then
		return
	end

	local entries = fs.scan_directory(node.path)
	node.children = {}

	for _, entry in ipairs(entries) do
		local child = M.build_node(entry.path, node.depth + 1)
		table.insert(node.children, child)
	end
end

function M.build_tree(root_path)
	local root = {
		name = fs.get_name(root_path),
		path = root_path,
		type = 'directory',
		depth = 0,
		children = nil,
		is_root = true,
	}

	M.load_children(root)
	return root
end

function M.flatten_visible(tree, expanded_paths)
	local lines = {}

	local function traverse(node)
		table.insert(lines, node)

		if node.type == 'directory' and expanded_paths[node.path] then
			M.load_children(node)
			if node.children then
				for _, child in ipairs(node.children) do
					traverse(child)
				end
			end
		end
	end

	traverse(tree)
	return lines
end

function M.find_parent_index(visible_lines, current_idx)
	local current = visible_lines[current_idx]
	if not current then
		return nil
	end

	local parent_path = fs.get_parent(current.path)

	for i = current_idx - 1, 1, -1 do
		if visible_lines[i].path == parent_path then
			return i
		end
	end

	return nil
end

function M.find_parent_sibling_index(visible_lines, current_idx)
	local current = visible_lines[current_idx]
	if not current then
		return nil
	end

	local parent_path = fs.get_parent(current.path)
	local grandparent_path = fs.get_parent(parent_path)

	-- Find nodes at grandparent level after current position
	for i = current_idx + 1, #visible_lines do
		local node = visible_lines[i]
		local node_parent = fs.get_parent(node.path)

		-- If we find a sibling of the parent (same grandparent, different parent)
		if node_parent == grandparent_path and node.path ~= parent_path then
			return i
		end

		-- If depth decreases below grandparent level, stop
		if node.depth < current.depth - 1 then
			break
		end
	end

	return nil
end

function M.get_last_child_index(visible_lines, parent_idx)
	local parent = visible_lines[parent_idx]
	if not parent then
		return parent_idx
	end

	local last_idx = parent_idx

	for i = parent_idx + 1, #visible_lines do
		if visible_lines[i].depth <= parent.depth then
			break
		end
		last_idx = i
	end

	return last_idx
end

return M
