local M = {}

-- Simple fuzzy match on text that is already lowercase: check if all pattern
-- chars appear in text in order
local function fuzzy_match_lower(pattern, text)
	if pattern == '' then
		return true, 0
	end

	local pattern_len = #pattern
	local pattern_idx = 1
	local pattern_byte = pattern:byte(1)
	local score = 0
	local consecutive = 0

	for i = 1, #text do
		if text:byte(i) == pattern_byte then
			pattern_idx = pattern_idx + 1
			consecutive = consecutive + 1
			-- Bonus for consecutive matches
			score = score + consecutive * 10
			-- Bonus for matching at start
			if i == 1 then
				score = score + 20
			end

			if pattern_idx > pattern_len then
				return true, score
			end
			pattern_byte = pattern:byte(pattern_idx)
		else
			consecutive = 0
		end
	end

	-- All pattern chars must be found
	return false, 0
end

function M.fuzzy_match(pattern, text)
	if not pattern or pattern == '' then
		return true, 0
	end

	return fuzzy_match_lower(pattern:lower(), text:lower())
end

-- Filter visible lines by pattern, keeping ancestors of matching nodes
function M.filter_tree(visible_lines, pattern)
	if not pattern or pattern == '' then
		return visible_lines
	end

	pattern = pattern:lower()

	-- First pass: find matching nodes
	local matching_paths = {}
	for _, node in ipairs(visible_lines) do
		local lower_name = node.lower_name or node.name:lower()
		local matches, _ = fuzzy_match_lower(pattern, lower_name)
		if matches then
			matching_paths[node.path] = true

			-- Also include all ancestors. Marking a path always marks its
			-- ancestors, so the first marked parent ends the walk.
			local parent = node.path:match('^(.*)/')
			while parent and parent ~= '' and not matching_paths[parent] do
				matching_paths[parent] = true
				parent = parent:match('^(.*)/')
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
