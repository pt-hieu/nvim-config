local Popup = require('nui.popup')
local Layout = require('nui.layout')
local state = require('git-history.state')
local git = require('git-history.git')

local M = {}

-- Layout: the commit list takes a quarter of the row, but never so little that
-- hashes and dates get truncated, so it is floored at MIN_COMMIT_WIDTH columns.
local LAYOUT_WIDTH_RATIO = 0.9
local LAYOUT_HEIGHT_RATIO = 0.8
local COMMIT_WIDTH_RATIO = 0.25
local MIN_COMMIT_WIDTH = 30

-- Module-level namespaces (created once, reused across renders)
local ns_commits = vim.api.nvim_create_namespace('git-history')
local ns_cursor = vim.api.nvim_create_namespace('git-history-cursor')

-- Diff syntax (and treesitter) groups remapped to the plugin's highlight groups
-- through 'winhighlight', so the user's global diff colors stay untouched.
local DIFF_WINHIGHLIGHT = table.concat({
  'diffAdded:GitHistoryDiffAdd',
  'diffRemoved:GitHistoryDiffDelete',
  'diffChanged:GitHistoryDiffHunk',
  'diffLine:GitHistoryDiffHunk',
  'diffSubname:GitHistoryDiffHunk',
  'diffFile:GitHistoryDiffHeader',
  'diffOldFile:GitHistoryDiffHeader',
  'diffNewFile:GitHistoryDiffHeader',
  'diffIndexLine:GitHistoryDiffHeader',
  '@diff.plus:GitHistoryDiffAdd',
  '@diff.minus:GitHistoryDiffDelete',
  '@diff.delta:GitHistoryDiffHunk',
}, ',')

function M.create_and_show()
  -- Create popups
  state.state.commit_popup = Popup({
    enter = true,
    focusable = true,
    border = {
      style = 'rounded',
      text = {
        top = ' Git History: ' .. vim.fn.fnamemodify(state.state.file_path, ':t') .. ' ',
        top_align = 'center',
      },
    },
  })

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

  -- Create layout (1:4 commits to preview, commits floored at MIN_COMMIT_WIDTH)
  local layout_width = math.floor(vim.o.columns * LAYOUT_WIDTH_RATIO)
  local commit_width = math.max(MIN_COMMIT_WIDTH, math.floor(layout_width * COMMIT_WIDTH_RATIO))
  commit_width = math.min(commit_width, layout_width - 1)
  local preview_width = layout_width - commit_width

  state.state.layout = Layout(
    {
      position = '50%',
      size = {
        width = layout_width,
        height = math.floor(vim.o.lines * LAYOUT_HEIGHT_RATIO),
      },
    },
    Layout.Box({
      Layout.Box(state.state.commit_popup, { size = { width = commit_width } }),
      Layout.Box(state.state.preview_popup, { size = { width = preview_width } }),
    }, { dir = 'row' })
  )

  -- Mount layout
  state.state.layout:mount()

  -- Create buffers
  state.state.commit_buf = state.state.commit_popup.bufnr
  state.state.preview_buf = state.state.preview_popup.bufnr

  -- Set buffer options
  vim.bo[state.state.commit_buf].modifiable = false
  vim.bo[state.state.commit_buf].buftype = 'nofile'
  vim.bo[state.state.preview_buf].modifiable = false
  vim.bo[state.state.preview_buf].buftype = 'nofile'
  vim.bo[state.state.preview_buf].filetype = 'diff'
  vim.wo[state.state.preview_popup.winid].number = true
  -- Map diff syntax groups to the Aura colors for this window only
  vim.wo[state.state.preview_popup.winid].winhighlight = DIFF_WINHIGHLIGHT

  -- Set up keymaps
  M.setup_keymaps()

  -- Placeholder until the first page of history arrives
  vim.bo[state.state.commit_buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.state.commit_buf, 0, -1, false, { 'Loading…' })
  vim.bo[state.state.commit_buf].modifiable = false
end

function M.setup_keymaps()
  local opts = { noremap = true, silent = true }

  -- Commit list keymaps
  state.state.commit_popup:map('n', 'j', function()
    M.move_cursor(1)
  end, opts)

  state.state.commit_popup:map('n', 'k', function()
    M.move_cursor(-1)
  end, opts)

  state.state.commit_popup:map('n', '<CR>', function()
    M.preview_selected_commit()
  end, opts)

  state.state.commit_popup:map('n', '<Tab>', function()
    vim.api.nvim_set_current_win(state.state.preview_popup.winid)
  end, opts)

  state.state.commit_popup:map('n', 'q', function()
    M.close()
  end, opts)

  state.state.commit_popup:map('n', '<Esc>', function()
    M.close()
  end, opts)

  -- Preview pane keymaps
  state.state.preview_popup:map('n', '<Tab>', function()
    vim.api.nvim_set_current_win(state.state.commit_popup.winid)
  end, opts)

  state.state.preview_popup:map('n', 'q', function()
    M.close()
  end, opts)

  state.state.preview_popup:map('n', '<Esc>', function()
    M.close()
  end, opts)
end

-- Commits are fetched in pages; the next page loads when the cursor is within
-- PAGE_PREFETCH commits of the end of the loaded list.
local PAGE_SIZE = 50
local PAGE_PREFETCH = 10
local PREVIEW_DEBOUNCE_MS = 75
local LINES_PER_COMMIT = 4

-- Append the lines and highlights for `commits` (starting at index `first_idx`)
-- to the commit buffer. The first append also replaces the loading placeholder.
function M.append_commits(commits, first_idx)
  local lines = {}
  local highlights = {}
  local base = (first_idx - 1) * LINES_PER_COMMIT

  for _, commit in ipairs(commits) do
    local line_start = base + #lines

    -- Line 1: ● hash  (date)
    local header = string.format('● %s  (%s)', commit.short_hash, commit.relative_date)
    table.insert(lines, header)
    table.insert(highlights, {
      line = line_start,
      col_start = 2,
      col_end = 2 + #commit.short_hash,
      hl_group = 'GitHistoryHash',
    })
    table.insert(highlights, {
      line = line_start,
      col_start = 2 + #commit.short_hash + 3,
      col_end = #header,
      hl_group = 'GitHistoryDate',
    })

    -- Line 2: author
    local author = '  ' .. commit.author
    table.insert(lines, author)
    table.insert(highlights, {
      line = line_start + 1,
      col_start = 2,
      col_end = #author,
      hl_group = 'GitHistoryAuthor',
    })

    -- Line 3: message
    local message = '  ' .. commit.message:sub(1, 50)
    table.insert(lines, message)
    table.insert(highlights, {
      line = line_start + 2,
      col_start = 2,
      col_end = #message,
      hl_group = 'GitHistoryMessage',
    })

    -- Line 4: blank
    table.insert(lines, '')
  end

  -- Update buffer (appends; the first page overwrites the loading line)
  vim.bo[state.state.commit_buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.state.commit_buf, base, -1, false, lines)
  vim.bo[state.state.commit_buf].modifiable = false

  -- Apply highlights for the appended chunk only
  for _, hl in ipairs(highlights) do
    vim.api.nvim_buf_set_extmark(state.state.commit_buf, ns_commits, hl.line, hl.col_start, {
      end_col = hl.col_end,
      hl_group = hl.hl_group,
    })
  end
end

-- Fetch the next page of history and append it to the list.
function M.load_more()
  local s = state.state
  if s.loading_page or s.exhausted or not s.git_root then
    return
  end
  s.loading_page = true

  local skip = #s.commits
  git.get_file_history(s.git_root, s.file_path, skip, PAGE_SIZE, function(err, commits)
    vim.schedule(function()
      if state.state ~= s then
        return
      end
      s.loading_page = false

      if err then
        M.close()
        vim.notify('Error fetching git history: ' .. err, vim.log.levels.ERROR)
        return
      end
      if #commits < PAGE_SIZE then
        s.exhausted = true
      end
      if #commits == 0 then
        if skip == 0 then
          M.close()
          vim.notify('No commits found for this file', vim.log.levels.INFO)
        end
        return
      end

      vim.list_extend(s.commits, commits)
      M.append_commits(commits, skip + 1)
      if skip == 0 then
        M.update_cursor_highlight()
        M.preview_selected_commit()
      end
    end)
  end)
end

function M.move_cursor(direction)
  if state.move_selection(direction) then
    -- Update visual cursor
    local cursor_line = (state.state.current_idx - 1) * LINES_PER_COMMIT + 1
    local win = state.state.commit_popup.winid
    vim.api.nvim_win_set_cursor(win, { cursor_line, 0 })

    -- Update highlight
    M.update_cursor_highlight()

    -- Auto-preview
    M.preview_selected_commit()

    -- Prefetch the next page near the end of the list
    if state.state.current_idx > #state.state.commits - PAGE_PREFETCH then
      M.load_more()
    end
  end
end

function M.update_cursor_highlight()
  vim.api.nvim_buf_clear_namespace(state.state.commit_buf, ns_cursor, 0, -1)

  -- Highlight 3 lines (skip blank line) using line_hl_group for full-line coverage
  local start_line = (state.state.current_idx - 1) * LINES_PER_COMMIT
  for i = 0, 2 do
    vim.api.nvim_buf_set_extmark(state.state.commit_buf, ns_cursor, start_line + i, 0, {
      line_hl_group = 'GitHistoryCursor',
    })
  end
end

local function render_preview(s, lines)
  if state.state ~= s or not vim.api.nvim_buf_is_valid(s.preview_buf) then
    return
  end
  vim.bo[s.preview_buf].modifiable = true
  vim.api.nvim_buf_set_lines(s.preview_buf, 0, -1, false, lines)
  vim.bo[s.preview_buf].modifiable = false
end

function M.preview_selected_commit()
  local s = state.state
  local commit = state.get_current_commit()
  if not commit then
    return
  end

  -- Update preview title to indicate diff view
  if s.preview_popup and s.preview_popup.winid and vim.api.nvim_win_is_valid(s.preview_popup.winid) then
    s.preview_popup.border:set_text('top', ' Diff @ ' .. commit.short_hash .. ' ', 'center')
  end

  -- Any newer selection supersedes the pending timer and in-flight request
  s.preview_req = s.preview_req + 1
  local req = s.preview_req
  if s.preview_timer then
    s.preview_timer:stop()
  end
  if s.preview_proc then
    s.preview_proc:kill(15)
    s.preview_proc = nil
  end

  local cached = s.diff_cache[commit.full_hash]
  if cached then
    render_preview(s, cached)
    return
  end

  s.preview_timer = s.preview_timer or vim.uv.new_timer()
  s.preview_timer:start(PREVIEW_DEBOUNCE_MS, 0, function()
    vim.schedule(function()
      if state.state ~= s or s.preview_req ~= req then
        return
      end
      s.preview_proc = git.get_commit_diff(s.git_root, commit.full_hash, commit.path, function(err, lines)
        vim.schedule(function()
          if state.state ~= s or s.preview_req ~= req then
            return
          end
          s.preview_proc = nil
          if err then
            lines = { '--- ' .. err .. ' ---' }
          else
            s.diff_cache[commit.full_hash] = lines
          end
          render_preview(s, lines)
        end)
      end)
    end)
  end)
end

function M.close()
  state.reset_state()
end

return M
