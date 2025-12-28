local M = {}

-- Simple fuzzy match: check if all pattern chars appear in text in order
function M.fuzzy_match(pattern, text)
	if not pattern or pattern == '' then
		return true, 0
	end

	pattern = pattern:lower()
	text = text:lower()

	local pattern_idx = 1
	local score = 0
	local consecutive = 0

	for i = 1, #text do
		if pattern_idx > #pattern then
			break
		end

		local tc = text:sub(i, i)
		local pc = pattern:sub(pattern_idx, pattern_idx)

		if tc == pc then
			pattern_idx = pattern_idx + 1
			consecutive = consecutive + 1
			-- Bonus for consecutive matches
			score = score + consecutive * 10
			-- Bonus for matching at start
			if i == 1 then
				score = score + 20
			end
		else
			consecutive = 0
		end
	end

	-- All pattern chars must be found
	if pattern_idx > #pattern then
		return true, score
	end

	return false, 0
end

-- Filter visible lines by pattern, keeping ancestors of matching nodes
function M.filter_tree(visible_lines, pattern)
	if not pattern or pattern == '' then
		return visible_lines
	end

	-- First pass: find matching nodes
	local matching_paths = {}
	for _, node in ipairs(visible_lines) do
		local matches, _ = M.fuzzy_match(pattern, node.name)
		if matches then
			matching_paths[node.path] = true

			-- Also include all ancestors
			local parent = vim.fn.fnamemodify(node.path, ':h')
			while parent and parent ~= '' do
				matching_paths[parent] = true
				local new_parent = vim.fn.fnamemodify(parent, ':h')
				if new_parent == parent then
					break
				end
				parent = new_parent
			end
		end
	end

	-- Second pass: filter to only matching nodes and ancestors
	local filtered = {}
	for _, node in ipairs(visible_lines) do
		if matching_paths[node.path] then
			table.insert(filtered, node)
		end
	end

	return filtered
end

return M
