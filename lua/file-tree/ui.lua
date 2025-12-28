local Popup = require('nui.popup')
local Layout = require('nui.layout')
local Input = require('nui.input')
local Menu = require('nui.menu')
local state = require('file-tree.state')
local tree_mod = require('file-tree.tree')
local icons = require('file-tree.icons')
local fs = require('file-tree.fs')
local filter = require('file-tree.filter')

local M = {}

-- Debounce timer for preview panel
local preview_timer = nil
local PREVIEW_DEBOUNCE_MS = 300

local function debounced_preview()
	if preview_timer then
		vim.fn.timer_stop(preview_timer)
	end
	preview_timer = vim.fn.timer_start(PREVIEW_DEBOUNCE_MS, function()
		vim.schedule(function()
			M.preview_current()
		end)
	end)
end

-- Custom UI components with Aura purple border

function M.show_select(items, opts, callback)
	local menu_items = {}
	for _, item in ipairs(items) do
		table.insert(menu_items, Menu.item(item))
	end

	local menu = Menu({
		position = '50%',
		size = {
			width = 30,
			height = #items,
		},
		border = {
			style = 'rounded',
			text = {
				top = opts.prompt and (' ' .. opts.prompt .. ' ') or '',
				top_align = 'center',
			},
			padding = { 0, 1 },
		},
		win_options = {
			winhighlight = 'Normal:Normal,FloatBorder:FileTreeBorder',
		},
	}, {
		lines = menu_items,
		keymap = {
			focus_next = { 'j', '<Down>' },
			focus_prev = { 'k', '<Up>' },
			close = { '<Esc>', 'q' },
			submit = { '<CR>' },
		},
		on_submit = function(item)
			callback(item.text)
		end,
		on_close = function()
			callback(nil)
		end,
	})

	menu:mount()
end

function M.show_input(opts, callback)
	local input = Input({
		position = '50%',
		size = {
			width = 40,
		},
		border = {
			style = 'rounded',
			text = {
				top = opts.prompt and (' ' .. opts.prompt .. ' ') or '',
				top_align = 'center',
			},
			padding = { 0, 1 },
		},
		win_options = {
			winhighlight = 'Normal:Normal,FloatBorder:FileTreeBorder',
		},
	}, {
		prompt = '',
		default_value = opts.default or '',
		on_submit = function(value)
			callback(value)
		end,
		on_close = function()
			callback(nil)
		end,
	})

	input:mount()

	input:map('n', '<Esc>', function()
		input:unmount()
		callback(nil)
	end, { noremap = true })
end

function M.show_inline_input(opts, callback)
	local depth = opts.depth or 0
	local parent_idx = opts.parent_idx or state.state.current_idx

	-- Find position at end of folder's children
	local last_child_idx = tree_mod.get_last_child_index(state.state.visible_lines, parent_idx)

	-- Insert placeholder line in tree buffer to make space for input
	local tree_buf = state.state.tree_buf
	vim.api.nvim_buf_set_option(tree_buf, 'modifiable', true)
	vim.api.nvim_buf_set_lines(tree_buf, last_child_idx, last_child_idx, false, { '' })
	vim.api.nvim_buf_set_option(tree_buf, 'modifiable', false)

	-- Calculate position relative to tree popup window
	local tree_win = state.state.tree_popup.winid
	local tree_pos = vim.api.nvim_win_get_position(tree_win)
	local tree_width = vim.api.nvim_win_get_width(tree_win)

	-- Row: at the placeholder line we just inserted
	local row = tree_pos[1] + last_child_idx -- placeholder is at this row

	-- Column: indented to match depth
	local guide_width = 3 -- "│ " display width
	local indent_width = depth * guide_width
	local col = tree_pos[2] + indent_width

	-- Icon prefix based on type
	local icon = opts.is_directory and ' ' or ' '

	local input_width = tree_width - indent_width - 4
	if input_width < 20 then
		input_width = 20
	end

	-- Cleanup function to remove placeholder line
	local function cleanup()
		if vim.api.nvim_buf_is_valid(tree_buf) then
			vim.api.nvim_buf_set_option(tree_buf, 'modifiable', true)
			vim.api.nvim_buf_set_lines(tree_buf, last_child_idx, last_child_idx + 1, false, {})
			vim.api.nvim_buf_set_option(tree_buf, 'modifiable', false)
		end
	end

	local input = Input({
		relative = 'editor',
		position = { row = row, col = col },
		size = { width = input_width },
		border = 'none',
		win_options = {
			winhighlight = 'Normal:Normal',
		},
	}, {
		prompt = icon,
		default_value = opts.default or '',
		on_submit = function(value)
			cleanup()
			callback(value)
		end,
		on_close = function()
			cleanup()
			callback(nil)
		end,
	})

	input:mount()

	input:map('n', '<Esc>', function()
		input:unmount()
		cleanup()
		callback(nil)
	end, { noremap = true })
end

function M.create_and_show()
	local root_name = fs.get_name(state.state.root)

	-- Create tree popup (left pane)
	state.state.tree_popup = Popup({
		enter = true,
		focusable = true,
		border = {
			style = 'rounded',
			text = {
				top = '  ' .. root_name .. ' ',
				top_align = 'center',
			},
		},
	})

	-- Create preview popup (right pane)
	state.state.preview_popup = Popup({
		focusable = true,
		border = {
			style = 'rounded',
			text = {
				top = ' Preview ',
				top_align = 'center',
			},
		},
	})

	-- Create layout (40% tree, 60% preview)
	state.state.layout = Layout(
		{
			position = '50%',
			size = {
				width = '90%',
				height = '80%',
			},
		},
		Layout.Box({
			Layout.Box(state.state.tree_popup, { size = '40%' }),
			Layout.Box(state.state.preview_popup, { size = '60%' }),
		}, { dir = 'row' })
	)

	-- Mount layout
	state.state.layout:mount()

	-- Store buffer references
	state.state.tree_buf = state.state.tree_popup.bufnr
	state.state.preview_buf = state.state.preview_popup.bufnr

	-- Set buffer options
	vim.api.nvim_buf_set_option(state.state.tree_buf, 'modifiable', false)
	vim.api.nvim_buf_set_option(state.state.tree_buf, 'buftype', 'nofile')
	vim.api.nvim_buf_set_option(state.state.preview_buf, 'modifiable', false)
	vim.api.nvim_buf_set_option(state.state.preview_buf, 'buftype', 'nofile')

	-- Set up keymaps
	M.setup_keymaps()

	-- Render tree
	M.render_tree()

	-- Preview first item if it's a file
	M.preview_current()
end

function M.setup_keymaps()
	local opts = { noremap = true, silent = true }

	-- Tree pane keymaps
	state.state.tree_popup:map('n', 'j', function()
		M.move_cursor(1)
	end, opts)

	state.state.tree_popup:map('n', 'k', function()
		M.move_cursor(-1)
	end, opts)

	state.state.tree_popup:map('n', 'l', function()
		M.action_expand_or_open()
	end, opts)

	state.state.tree_popup:map('n', 'h', function()
		M.action_collapse_or_parent()
	end, opts)

	state.state.tree_popup:map('n', '<CR>', function()
		M.action_open_and_close()
	end, opts)

	state.state.tree_popup:map('n', '{', function()
		M.jump_to_parent()
	end, opts)

	state.state.tree_popup:map('n', '}', function()
		M.jump_to_parent_sibling()
	end, opts)

	state.state.tree_popup:map('n', '<Tab>', function()
		vim.api.nvim_set_current_win(state.state.preview_popup.winid)
	end, opts)

	state.state.tree_popup:map('n', 'q', function()
		M.close()
	end, opts)

	state.state.tree_popup:map('n', '<Esc>', function()
		M.close()
	end, opts)

	-- CRUD keymaps
	state.state.tree_popup:map('n', 'a', function()
		M.action_create()
	end, opts)

	state.state.tree_popup:map('n', 'r', function()
		M.action_rename()
	end, opts)

	state.state.tree_popup:map('n', 'd', function()
		M.action_delete()
	end, opts)

	-- Filter keymap
	state.state.tree_popup:map('n', '/', function()
		M.enter_filter_mode()
	end, opts)

	-- Grep in path keymap
	state.state.tree_popup:map('n', 'f', function()
		M.action_grep_in_path()
	end, opts)

	-- Preview pane keymaps
	state.state.preview_popup:map('n', '<Tab>', function()
		vim.api.nvim_set_current_win(state.state.tree_popup.winid)
	end, opts)

	state.state.preview_popup:map('n', 'q', function()
		M.close()
	end, opts)

	state.state.preview_popup:map('n', '<Esc>', function()
		M.close()
	end, opts)
end

function M.render_tree()
	-- Flatten visible lines
	local all_lines = tree_mod.flatten_visible(state.state.tree, state.state.expanded_paths)

	-- Apply filter if active
	if state.state.filter_text ~= '' then
		state.state.visible_lines = filter.filter_tree(all_lines, state.state.filter_text)
	else
		state.state.visible_lines = all_lines
	end

	local lines = {}
	local highlights = {}

	-- Indent guide character
	local guide = '│ '
	local guide_len = #guide

	-- Get window width for full-width lines
	local win_width = vim.api.nvim_win_get_width(state.state.tree_popup.winid) - 2

	for i, node in ipairs(state.state.visible_lines) do
		local line_idx = i - 1
		local indent = string.rep(guide, node.depth)
		local is_expanded = state.is_expanded(node.path)
		local icon, icon_hl = icons.get_icon(node.name, node.type, is_expanded)

		-- Build content (indent + icon + name)
		local content = indent .. icon .. ' ' .. node.name
		local content_len = vim.fn.strdisplaywidth(content)

		-- Add git status indicator (right-aligned)
		local git_status = state.state.git_status[node.path]
		local git_icon, git_hl = icons.get_git_indicator(git_status)

		local line
		if git_icon then
			local git_len = vim.fn.strdisplaywidth(git_icon)
			local padding = win_width - content_len - git_len - 1
			if padding > 0 then
				line = content .. string.rep(' ', padding) .. git_icon
			else
				line = content .. ' ' .. git_icon
			end
		else
			-- Pad to full width for consistent selection highlight
			local padding = win_width - content_len
			if padding > 0 then
				line = content .. string.rep(' ', padding)
			else
				line = content
			end
		end

		table.insert(lines, line)

		-- Highlight each indent guide
		for d = 0, node.depth - 1 do
			local col_start = d * guide_len
			table.insert(highlights, {
				line = line_idx,
				col_start = col_start,
				col_end = col_start + guide_len,
				hl_group = 'FileTreeIndent',
			})
		end

		-- Highlight icon
		local icon_start = node.depth * guide_len
		local icon_end = icon_start + #icon
		table.insert(highlights, {
			line = line_idx,
			col_start = icon_start,
			col_end = icon_end,
			hl_group = icon_hl,
		})

		-- Highlight name
		local name_start = icon_end + 1
		local name_end = name_start + #node.name
		local name_hl = node.type == 'directory' and 'FileTreeFolder' or 'FileTreeFile'
		if node.is_root then
			name_hl = 'FileTreeRootName'
		end
		table.insert(highlights, {
			line = line_idx,
			col_start = name_start,
			col_end = name_end,
			hl_group = name_hl,
		})

		-- Highlight git indicator (at end of line)
		if git_icon and git_hl then
			local git_start = #line - #git_icon
			table.insert(highlights, {
				line = line_idx,
				col_start = git_start,
				col_end = -1,
				hl_group = git_hl,
			})
		end
	end

	-- Update buffer
	vim.api.nvim_buf_set_option(state.state.tree_buf, 'modifiable', true)
	vim.api.nvim_buf_set_lines(state.state.tree_buf, 0, -1, false, lines)
	vim.api.nvim_buf_set_option(state.state.tree_buf, 'modifiable', false)

	-- Apply highlights
	local ns_id = vim.api.nvim_create_namespace('file-tree')
	vim.api.nvim_buf_clear_namespace(state.state.tree_buf, ns_id, 0, -1)
	for _, hl in ipairs(highlights) do
		vim.api.nvim_buf_add_highlight(state.state.tree_buf, ns_id, hl.hl_group, hl.line, hl.col_start, hl.col_end)
	end

	-- Update cursor highlight
	M.update_cursor_highlight()

	-- Sync cursor position
	M.sync_cursor_position()
end

function M.move_cursor(direction)
	if state.move_selection(direction) then
		M.update_cursor_highlight()
		M.sync_cursor_position()
		debounced_preview()
	end
end

function M.sync_cursor_position()
	local win = state.state.tree_popup.winid
	if vim.api.nvim_win_is_valid(win) then
		vim.api.nvim_win_set_cursor(win, { state.state.current_idx, 0 })
	end
end

function M.update_cursor_highlight()
	local ns_id = vim.api.nvim_create_namespace('file-tree-cursor')
	vim.api.nvim_buf_clear_namespace(state.state.tree_buf, ns_id, 0, -1)

	local line = state.state.current_idx - 1
	vim.api.nvim_buf_add_highlight(state.state.tree_buf, ns_id, 'FileTreeSelection', line, 0, -1)
end

function M.action_expand_or_open()
	local node = state.get_current_node()
	if not node then
		return
	end

	if node.type == 'directory' then
		-- Expand directory
		state.set_expanded(node.path, true)
		M.render_tree()
	else
		-- Open file
		M.open_file(node.path)
	end
end

function M.action_collapse_or_parent()
	local node = state.get_current_node()
	if not node then
		return
	end

	if node.type == 'directory' and state.is_expanded(node.path) then
		-- Collapse directory
		state.set_expanded(node.path, false)
		M.render_tree()
	else
		-- Go to parent
		M.jump_to_parent()
	end
end

function M.action_open_and_close()
	local node = state.get_current_node()
	if not node then
		return
	end

	if node.type == 'file' then
		M.open_file(node.path)
		M.close()
	else
		-- Toggle directory
		state.toggle_expanded(node.path)
		M.render_tree()
	end
end

function M.jump_to_parent()
	local parent_idx = tree_mod.find_parent_index(state.state.visible_lines, state.state.current_idx)
	if parent_idx then
		state.set_selection(parent_idx)
		M.update_cursor_highlight()
		M.sync_cursor_position()
		debounced_preview()
	end
end

function M.jump_to_parent_sibling()
	local sibling_idx = tree_mod.find_parent_sibling_index(state.state.visible_lines, state.state.current_idx)
	if sibling_idx then
		state.set_selection(sibling_idx)
		M.update_cursor_highlight()
		M.sync_cursor_position()
		debounced_preview()
	end
end

function M.open_file(path)
	M.close()
	vim.cmd('edit ' .. vim.fn.fnameescape(path))
end

function M.preview_current()
	local node = state.get_current_node()
	if not node then
		return
	end

	if node.type == 'directory' then
		-- Show directory info
		state.state.preview_popup.border:set_text('top', '  ' .. node.name .. '/ ', 'center')

		local children_nodes = {}
		local children = {}
		if node.children then
			children_nodes = node.children
		else
			-- Load children for preview
			tree_mod.load_children(node)
			if node.children then
				children_nodes = node.children
			end
		end

		for _, child in ipairs(children_nodes) do
			local icon, _ = icons.get_icon(child.name, child.type, false)
			table.insert(children, icon .. ' ' .. child.name)
		end

		if #children == 0 then
			children = { '(empty directory)' }
		end

		vim.api.nvim_buf_set_option(state.state.preview_buf, 'modifiable', true)
		vim.api.nvim_buf_set_lines(state.state.preview_buf, 0, -1, false, children)
		vim.api.nvim_buf_set_option(state.state.preview_buf, 'modifiable', false)
		vim.api.nvim_buf_set_option(state.state.preview_buf, 'filetype', '')

		-- Apply highlights to folder preview
		local ns_id = vim.api.nvim_create_namespace('file-tree-preview')
		vim.api.nvim_buf_clear_namespace(state.state.preview_buf, ns_id, 0, -1)
		for i, child in ipairs(children_nodes) do
			local icon, icon_hl = icons.get_icon(child.name, child.type, false)
			local name_hl = child.type == 'directory' and 'FileTreeFolder' or 'FileTreeFile'
			-- Highlight icon
			vim.api.nvim_buf_add_highlight(state.state.preview_buf, ns_id, icon_hl, i - 1, 0, #icon)
			-- Highlight name
			vim.api.nvim_buf_add_highlight(state.state.preview_buf, ns_id, name_hl, i - 1, #icon + 1, -1)
		end
	else
		-- Preview file contents
		state.state.preview_popup.border:set_text('top', '  ' .. node.name .. ' ', 'center')
		M.preview_file(node.path)
	end
end

function M.preview_file(path)
	-- Check if binary
	local ext = vim.fn.fnamemodify(path, ':e')
	local binary_extensions = { 'png', 'jpg', 'jpeg', 'gif', 'bmp', 'ico', 'pdf', 'zip', 'tar', 'gz', 'exe', 'dll', 'so', 'dylib' }

	for _, bin_ext in ipairs(binary_extensions) do
		if ext:lower() == bin_ext then
			vim.api.nvim_buf_set_option(state.state.preview_buf, 'modifiable', true)
			vim.api.nvim_buf_set_lines(state.state.preview_buf, 0, -1, false, { '[Binary file]' })
			vim.api.nvim_buf_set_option(state.state.preview_buf, 'modifiable', false)
			vim.api.nvim_buf_set_option(state.state.preview_buf, 'filetype', '')
			return
		end
	end

	-- Read file contents (first 200 lines)
	local lines = {}
	local file = io.open(path, 'r')
	if file then
		local count = 0
		for line in file:lines() do
			if count >= 200 then
				table.insert(lines, '...')
				break
			end
			table.insert(lines, line)
			count = count + 1
		end
		file:close()
	else
		lines = { '[Cannot read file]' }
	end

	vim.api.nvim_buf_set_option(state.state.preview_buf, 'modifiable', true)
	vim.api.nvim_buf_set_lines(state.state.preview_buf, 0, -1, false, lines)
	vim.api.nvim_buf_set_option(state.state.preview_buf, 'modifiable', false)

	-- Set filetype for syntax highlighting
	local filetype = vim.filetype.match({ filename = path })
	vim.api.nvim_buf_set_option(state.state.preview_buf, 'filetype', filetype or '')
end

function M.close()
	if preview_timer then
		vim.fn.timer_stop(preview_timer)
		preview_timer = nil
	end
	state.reset_state()
end

-- CRUD Operations

function M.refresh_tree()
	local tree_builder = require('file-tree.tree')
	local git = require('file-tree.git')

	-- Rebuild tree
	state.state.tree = tree_builder.build_tree(state.state.root)

	-- Re-render
	M.render_tree()

	-- Refresh git status
	git.get_status(state.state.root, function(status_map)
		vim.schedule(function()
			state.state.git_status = status_map
			if state.state.tree_buf and vim.api.nvim_buf_is_valid(state.state.tree_buf) then
				M.render_tree()
			end
		end)
	end)
end

function M.action_create()
	local node = state.get_current_node()
	if not node then
		return
	end

	-- Determine parent directory and depth for inline input
	local parent_dir
	local depth
	local parent_idx

	if node.type == 'directory' then
		parent_dir = node.path
		depth = node.depth + 1
		parent_idx = state.state.current_idx

		-- Expand folder if collapsed so we can show input at end of children
		if not state.is_expanded(node.path) then
			state.set_expanded(node.path, true)
			M.render_tree()
		end
	else
		parent_dir = fs.get_parent(node.path)
		depth = node.depth
		-- Find parent folder's index for positioning
		parent_idx = tree_mod.find_parent_index(state.state.visible_lines, state.state.current_idx)
	end

	-- Ask file or folder
	M.show_select({ 'File', 'Directory' }, { prompt = 'Create' }, function(choice)
		if not choice then
			return
		end

		local is_directory = choice == 'Directory'
		M.show_inline_input({ is_directory = is_directory, depth = depth, parent_idx = parent_idx }, function(name)
			if not name or name == '' then
				return
			end

			local new_path = parent_dir .. '/' .. name
			local ok

			if choice == 'File' then
				ok = fs.create_file(new_path)
			else
				ok = fs.create_directory(new_path)
			end

			if ok then
				-- Expand parent and refresh
				state.set_expanded(parent_dir, true)
				M.refresh_tree()

				-- Try to select the new item
				vim.schedule(function()
					local idx = state.find_node_index(new_path)
					if idx then
						state.set_selection(idx)
						M.update_cursor_highlight()
						M.sync_cursor_position()
						M.preview_current()
					end
				end)
			else
				vim.notify('Failed to create ' .. name, vim.log.levels.ERROR)
			end
		end)
	end)
end

function M.action_rename()
	local node = state.get_current_node()
	if not node or node.is_root then
		return
	end

	local old_name = node.name
	local parent_dir = fs.get_parent(node.path)

	M.show_select({ 'Rename' }, { prompt = 'Rename "' .. old_name .. '"?' }, function(choice)
		if not choice then
			return
		end

		M.show_input({ prompt = 'New name', default = old_name }, function(new_name)
			if not new_name or new_name == '' or new_name == old_name then
				return
			end

			local new_path = parent_dir .. '/' .. new_name
			local ok = fs.rename(node.path, new_path)

			if ok then
				M.refresh_tree()

				-- Try to select the renamed item
				vim.schedule(function()
					local idx = state.find_node_index(new_path)
					if idx then
						state.set_selection(idx)
						M.update_cursor_highlight()
						M.sync_cursor_position()
						M.preview_current()
					end
				end)
			else
				vim.notify('Failed to rename ' .. old_name, vim.log.levels.ERROR)
			end
		end)
	end)
end

function M.action_delete()
	local node = state.get_current_node()
	if not node or node.is_root then
		return
	end

	local type_str = node.type == 'directory' and 'directory' or 'file'
	local prompt = string.format('Delete %s "%s"?', type_str, node.name)

	M.show_select({ 'Yes', 'No' }, { prompt = prompt }, function(choice)
		if choice ~= 'Yes' then
			return
		end

		local ok = fs.delete(node.path)

		if ok then
			M.refresh_tree()
		else
			vim.notify('Failed to delete ' .. node.name, vim.log.levels.ERROR)
		end
	end)
end

function M.action_grep_in_path()
	local node = state.get_current_node()
	if not node then
		vim.notify('No node selected', vim.log.levels.WARN)
		return
	end

	local search_path = node.path
	local is_file = node.type == 'file'

	M.close()

	-- Use defer_fn to ensure file-tree is fully closed before opening telescope
	vim.defer_fn(function()
		local ok, err = pcall(function()
			if is_file then
				-- For files, use grep_string with search empty and path filter
				require('telescope.builtin').live_grep({
					cwd = vim.fn.fnamemodify(search_path, ':h'),
					glob_pattern = vim.fn.fnamemodify(search_path, ':t'),
					prompt_title = 'Grep in ' .. vim.fn.fnamemodify(search_path, ':t'),
				})
			else
				-- For directories, search entire directory
				require('telescope.builtin').live_grep({
					cwd = search_path,
					prompt_title = 'Grep in ' .. vim.fn.fnamemodify(search_path, ':t'),
				})
			end
		end)
		if not ok then
			vim.notify('Grep error: ' .. tostring(err), vim.log.levels.ERROR)
		end
	end, 100)
end

-- Filter Mode

function M.enter_filter_mode()
	state.state.filter_mode = true

	-- Position filter input centered (command palette style)
	state.state.filter_input = Input({
		relative = 'editor',
		position = '50%',
		size = {
			width = 40,
		},
		border = {
			style = 'rounded',
			text = {
				top = ' Filter ',
				top_align = 'center',
			},
			padding = { 1, 2 },
		},
		zindex = 100,
		win_options = {
			winhighlight = 'Normal:Normal,FloatBorder:FileTreeBorder',
		},
	}, {
		prompt = ' ',
		default_value = state.state.filter_text or '',
		on_change = function(value)
			state.state.filter_text = value
			-- Defer to avoid E565 error during text input
			vim.schedule(function()
				M.apply_filter()
			end)
		end,
		on_submit = function(value)
			state.state.filter_text = value
			state.state.filter_mode = false
			M.update_tree_title()
			if state.state.filter_input then
				state.state.filter_input:unmount()
				state.state.filter_input = nil
			end
			-- Return focus to tree
			vim.api.nvim_set_current_win(state.state.tree_popup.winid)
		end,
		on_close = function()
			state.state.filter_mode = false
			state.state.filter_text = ''
			state.state.current_idx = 1
			M.update_tree_title()
			M.render_tree()
			state.state.filter_input = nil
			-- Return focus to tree
			vim.api.nvim_set_current_win(state.state.tree_popup.winid)
		end,
	})

	state.state.filter_input:mount()

	-- Add Esc mapping to close filter
	state.state.filter_input:map('i', '<Esc>', function()
		state.state.filter_mode = false
		state.state.filter_text = ''
		state.state.current_idx = 1
		M.update_tree_title()
		M.render_tree()
		if state.state.filter_input then
			state.state.filter_input:unmount()
			state.state.filter_input = nil
		end
		vim.api.nvim_set_current_win(state.state.tree_popup.winid)
	end, { noremap = true })
end

function M.update_tree_title()
	local root_name = fs.get_name(state.state.root)
	if state.state.filter_text and state.state.filter_text ~= '' then
		-- Show filter badge in title
		state.state.tree_popup.border:set_text('top', '  ' .. root_name .. '  󰈲 ' .. state.state.filter_text .. ' ', 'center')
	else
		state.state.tree_popup.border:set_text('top', '  ' .. root_name .. ' ', 'center')
	end
end

function M.apply_filter()
	-- Re-render with current filter
	M.render_tree()

	-- Reset selection to first visible item
	if #state.state.visible_lines > 0 then
		state.state.current_idx = 1
		M.update_cursor_highlight()
		M.sync_cursor_position()
		M.preview_current()
	end
end

return M
