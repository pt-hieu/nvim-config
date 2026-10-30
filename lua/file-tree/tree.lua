local fs = require('file-tree.fs')
local state = require('file-tree.state')

local M = {}

function M.build_node(entry, depth)
	return {
		name = entry.name,
		lower_name = entry.lower_name,
		path = entry.path,
		type = entry.type,
		depth = depth,
		children = nil,
	}
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
		local child = M.build_node(entry, node.depth + 1)
		table.insert(node.children, child)
	end
end

-- Rescans an already loaded directory, keeping the existing node (and so its
-- loaded subtree) for every entry that is still there.
function M.refresh_directory(node)
	if node.children == nil then
		return
	end

	local existing = {}
	for _, child in ipairs(node.children) do
		existing[child.path] = child
	end

	node.children = {}

	for _, entry in ipairs(fs.scan_directory(node.path)) do
		local child = existing[entry.path]
		if not child or child.type ~= entry.type then
			child = M.build_node(entry, node.depth + 1)
		end
		table.insert(node.children, child)
	end
end

-- Finds a node by path, descending only through already loaded children.
function M.find_node(root, path)
	if path == root.path then
		return root
	end

	if path:sub(1, #root.path + 1) ~= root.path .. '/' then
		return nil
	end

	local node = root
	for part in path:sub(#root.path + 2):gmatch('[^/]+') do
		local next_node
		for _, child in ipairs(node.children or {}) do
			if child.name == part then
				next_node = child
				break
			end
		end
		if not next_node then
			return nil
		end
		node = next_node
	end

	return node
end

function M.build_tree(root_path)
	local root_name = fs.get_name(root_path)
	local root = {
		name = root_name,
		lower_name = root_name:lower(),
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

	-- Visible lines are in tree order, so the parent is the nearest line above
	-- that sits one level shallower.
	for i = current_idx - 1, 1, -1 do
		if visible_lines[i].depth < current.depth then
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

	-- A sibling of the parent sits one level shallower than the current node.
	-- Anything shallower than that is outside the grandparent, so stop.
	for i = current_idx + 1, #visible_lines do
		local depth = visible_lines[i].depth

		if depth == current.depth - 1 then
			return i
		end

		if depth < current.depth - 1 then
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
