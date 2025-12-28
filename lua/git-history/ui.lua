local Popup = require('nui.popup')
local Layout = require('nui.layout')
local state = require('git-history.state')
local git = require('git-history.git')

local M = {}

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

  -- Create layout
  state.state.layout = Layout(
    {
      position = '50%',
      size = {
        width = '90%',
        height = '80%',
      },
    },
    Layout.Box({
      Layout.Box(state.state.commit_popup, { size = '40%' }),
      Layout.Box(state.state.preview_popup, { size = '60%' }),
    }, { dir = 'row' })
  )

  -- Mount layout
  state.state.layout:mount()

  -- Create buffers
  state.state.commit_buf = state.state.commit_popup.bufnr
  state.state.preview_buf = state.state.preview_popup.bufnr

  -- Set buffer options
  vim.api.nvim_buf_set_option(state.state.commit_buf, 'modifiable', false)
  vim.api.nvim_buf_set_option(state.state.commit_buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(state.state.preview_buf, 'modifiable', false)
  vim.api.nvim_buf_set_option(state.state.preview_buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(state.state.preview_buf, 'number', true)

  -- Set up keymaps
  M.setup_keymaps()

  -- Render commit list
  M.render_commit_list()

  -- Preview first commit
  M.preview_selected_commit()
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

function M.render_commit_list()
  local lines = {}
  local highlights = {}

  for i, commit in ipairs(state.state.commits) do
    local line_start = #lines

    -- Line 1: ● hash  (date)
    table.insert(lines, string.format('● %s  (%s)', commit.short_hash, commit.relative_date))
    table.insert(highlights, {
      line = line_start,
      col_start = 2,
      col_end = 2 + #commit.short_hash,
      hl_group = 'GitHistoryHash',
    })
    table.insert(highlights, {
      line = line_start,
      col_start = 2 + #commit.short_hash + 3,
      col_end = -1,
      hl_group = 'GitHistoryDate',
    })

    -- Line 2: author
    table.insert(lines, '  ' .. commit.author)
    table.insert(highlights, {
      line = line_start + 1,
      col_start = 2,
      col_end = -1,
      hl_group = 'GitHistoryAuthor',
    })

    -- Line 3: message
    local message = commit.message:sub(1, 50)
    table.insert(lines, '  ' .. message)
    table.insert(highlights, {
      line = line_start + 2,
      col_start = 2,
      col_end = -1,
      hl_group = 'GitHistoryMessage',
    })

    -- Line 4: blank
    table.insert(lines, '')
  end

  -- Update buffer
  vim.api.nvim_buf_set_option(state.state.commit_buf, 'modifiable', true)
  vim.api.nvim_buf_set_lines(state.state.commit_buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(state.state.commit_buf, 'modifiable', false)

  -- Apply highlights
  local ns_id = vim.api.nvim_create_namespace('git-history')
  for _, hl in ipairs(highlights) do
    vim.api.nvim_buf_add_highlight(state.state.commit_buf, ns_id, hl.hl_group, hl.line, hl.col_start, hl.col_end)
  end

  -- Highlight first commit
  M.update_cursor_highlight()
end

function M.move_cursor(direction)
  if state.move_selection(direction) then
    -- Update visual cursor
    local cursor_line = (state.state.current_idx - 1) * 4 + 1
    local win = state.state.commit_popup.winid
    vim.api.nvim_win_set_cursor(win, { cursor_line, 0 })

    -- Update highlight
    M.update_cursor_highlight()

    -- Auto-preview
    M.preview_selected_commit()
  end
end

function M.update_cursor_highlight()
  local ns_id = vim.api.nvim_create_namespace('git-history-cursor')
  vim.api.nvim_buf_clear_namespace(state.state.commit_buf, ns_id, 0, -1)

  -- Highlight 3 lines (skip blank line)
  local start_line = (state.state.current_idx - 1) * 4
  for i = 0, 2 do
    vim.api.nvim_buf_add_highlight(state.state.commit_buf, ns_id, 'GitHistoryCursor', start_line + i, 0, -1)
  end
end

function M.preview_selected_commit()
  local commit = state.get_current_commit()

  -- Update preview title to indicate diff view
  state.state.preview_popup.border:set_text('top', ' Diff @ ' .. commit.short_hash .. ' ', 'center')

  -- Fetch commit diff
  git.get_commit_diff(commit.full_hash, state.state.file_path, function(err, lines)
    if err then
      lines = { '--- ' .. err .. ' ---' }
    end

    -- Update preview buffer
    vim.schedule(function()
      vim.api.nvim_buf_set_option(state.state.preview_buf, 'modifiable', true)
      vim.api.nvim_buf_set_lines(state.state.preview_buf, 0, -1, false, lines)
      vim.api.nvim_buf_set_option(state.state.preview_buf, 'modifiable', false)

      -- Set filetype to diff for syntax highlighting
      vim.api.nvim_buf_set_option(state.state.preview_buf, 'filetype', 'diff')

      -- Apply custom highlights
      M.apply_diff_highlights()
    end)
  end)
end

function M.apply_diff_highlights()
  local ns_id = vim.api.nvim_create_namespace('git-history-diff')
  vim.api.nvim_buf_clear_namespace(state.state.preview_buf, ns_id, 0, -1)

  local lines = vim.api.nvim_buf_get_lines(state.state.preview_buf, 0, -1, false)

  for i, line in ipairs(lines) do
    local hl_group = nil

    if line:match('^%+') and not line:match('^%+%+%+') then
      -- Addition line (starts with + but not +++)
      hl_group = 'GitHistoryDiffAdd'
    elseif line:match('^%-') and not line:match('^%-%-%- ') then
      -- Deletion line (starts with - but not ---)
      hl_group = 'GitHistoryDiffDelete'
    elseif line:match('^@@') then
      -- Hunk header
      hl_group = 'GitHistoryDiffHunk'
    elseif line:match('^diff ') or line:match('^index ') or line:match('^%+%+%+ ') or line:match('^%-%-%- ') then
      -- Diff header lines
      hl_group = 'GitHistoryDiffHeader'
    else
      -- Context lines (unchanged)
      hl_group = 'GitHistoryDiffContext'
    end

    if hl_group then
      vim.api.nvim_buf_add_highlight(state.state.preview_buf, ns_id, hl_group, i - 1, 0, -1)
    end
  end
end

function M.close()
  state.reset_state()
end

return M
