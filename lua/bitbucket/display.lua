local state = require('bitbucket.state')
local Job = require('plenary.job')
local M = {}

local ns_id = vim.api.nvim_create_namespace('bitbucket_comments')
local diff_ns_id = vim.api.nvim_create_namespace('bitbucket_diff')

-- No sign definitions needed: signs rendered via nvim_buf_set_extmark sign_text

-- Format a single comment for display
local function format_comment(comment)
  local author = comment.user and comment.user.display_name or 'Unknown'
  local content = comment.content and comment.content.raw or ''
  -- Check both resolved field and resolution object (Bitbucket uses resolution object)
  local resolved = comment.resolved or (comment.resolution ~= nil and type(comment.resolution) == 'table')

  -- Split content into lines
  local lines = vim.split(content, '\n', { plain = true })

  return {
    author = author,
    lines = lines,
    resolved = resolved,
    id = comment.id,
  }
end

-- Wrap text to fit within max width
local function wrap_text(text, width)
  local result = {}
  for _, line in ipairs(vim.split(text, '\n', { plain = true })) do
    if #line <= width then
      table.insert(result, line)
    else
      while #line > width do
        local break_at = line:sub(1, width):match('.*()%s') or width
        table.insert(result, line:sub(1, break_at - 1))
        line = line:sub(break_at):gsub('^%s+', '')
      end
      if #line > 0 then
        table.insert(result, line)
      end
    end
  end
  return result
end

-- Render a resolved comment (simple single-line format)
local function render_resolved_comment(formatted, indent)
  local virt_lines = {}
  local hl = 'BBCommentResolved'
  indent = indent or ''

  local text = 'Resolved comment from @' .. formatted.author
  local max_width = #text + 4

  -- Top border
  table.insert(virt_lines, { { indent .. '╭' .. string.rep('─', max_width) .. '╮', hl } })

  -- Content line
  local padding = max_width - vim.fn.strdisplaywidth(text)
  table.insert(virt_lines, {
    { indent .. '│ ', hl },
    { text .. string.rep(' ', math.max(0, padding)) .. ' ', hl },
    { '│', hl },
  })

  -- Bottom border
  table.insert(virt_lines, { { indent .. '╰' .. string.rep('─', max_width) .. '╯', hl } })

  return virt_lines
end

-- Render an active (unresolved) comment
local function render_active_comment(formatted, indent)
  local virt_lines = {}
  indent = indent or ''

  -- Fixed content width (leaving room for icon, author, borders)
  local content_width = 60
  local header_prefix = ' @' .. formatted.author .. ': '
  local first_line_width = content_width - #header_prefix

  -- Wrap all content lines
  local raw_content = table.concat(formatted.lines, '\n')
  local wrapped_lines = wrap_text(raw_content, content_width)

  -- Calculate max width based on wrapped content
  local max_width = #header_prefix + first_line_width + 2
  for _, l in ipairs(wrapped_lines) do
    max_width = math.max(max_width, #l + 4)
  end
  max_width = math.min(max_width, 80)

  -- Top border: ╭───────╮
  local top_border = indent .. '╭' .. string.rep('─', max_width) .. '╮'
  table.insert(virt_lines, { { top_border, 'BBCommentBorder' } })

  -- First line: │ 💬 @author: content │
  local first_line_text = wrapped_lines[1] or ''
  if #first_line_text > first_line_width then
    first_line_text = first_line_text:sub(1, first_line_width)
  end
  local icon = ' '
  local content = icon .. '@' .. formatted.author .. ': ' .. first_line_text
  local padding = max_width - vim.fn.strdisplaywidth(content)
  table.insert(virt_lines, {
    { indent .. '│ ', 'BBCommentBorder' },
    { icon, 'BBCommentIcon' },
    { '@' .. formatted.author .. ': ', 'BBCommentAuthor' },
    { first_line_text .. string.rep(' ', math.max(0, padding)) .. ' ', 'BBCommentText' },
    { '│', 'BBCommentBorder' },
  })

  -- Subsequent lines: │   content │
  for i = 2, #wrapped_lines do
    local line_text = wrapped_lines[i]
    if line_text and line_text ~= '' then
      local line_padding = max_width - vim.fn.strdisplaywidth(line_text) - 2
      table.insert(virt_lines, {
        { indent .. '│   ', 'BBCommentBorder' },
        { line_text .. string.rep(' ', math.max(0, line_padding)) .. ' ', 'BBCommentText' },
        { '│', 'BBCommentBorder' },
      })
    end
  end

  -- Bottom border: ╰───────╯
  local bottom_border = indent .. '╰' .. string.rep('─', max_width) .. '╯'
  table.insert(virt_lines, { { bottom_border, 'BBCommentBorder' } })

  return virt_lines
end

-- Render comments for a specific line
local function render_line_comments(bufnr, line, comments)
  local extmark_ids = {}

  -- Get line content and extract indentation
  local line_content = vim.api.nvim_buf_get_lines(bufnr, line - 1, line, false)[1] or ''
  local indent = line_content:match('^(%s*)') or ''

  for _, comment in ipairs(comments) do
    local formatted = format_comment(comment)

    -- Skip resolved replies (only show parent of resolved thread)
    if formatted.resolved and comment.parent then
      goto continue
    end

    local virt_lines
    if formatted.resolved then
      virt_lines = render_resolved_comment(formatted, indent)
    else
      virt_lines = render_active_comment(formatted, indent)
    end

    -- Create extmark with virtual lines below (pcall guards against out-of-range line)
    local ok, extmark_id = pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_id, line - 1, 0, {
      virt_lines = virt_lines,
      virt_lines_above = false,
    })
    if not ok then
      goto continue
    end

    table.insert(extmark_ids, extmark_id)

    ::continue::
  end

  return extmark_ids
end

-- Render file-level comments at line 1
local function render_file_comments(bufnr, comments)
  local extmark_ids = {}

  -- Get indentation from first line
  local line_content = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1] or ''
  local indent = line_content:match('^(%s*)') or ''

  for _, comment in ipairs(comments) do
    local formatted = format_comment(comment)

    -- Skip resolved replies (only show parent of resolved thread)
    if formatted.resolved and comment.parent then
      goto continue
    end

    local virt_lines

    if formatted.resolved then
      virt_lines = render_resolved_comment(formatted, indent)
    else
      -- Render active file-level comment
      virt_lines = {}

      local content_width = 60
      local header_prefix = ' @' .. formatted.author .. ' (file): '
      local first_line_width = content_width - #header_prefix

      local raw_content = table.concat(formatted.lines, '\n')
      local wrapped_lines = wrap_text(raw_content, content_width)

      local max_width = #header_prefix + first_line_width + 2
      for _, l in ipairs(wrapped_lines) do
        max_width = math.max(max_width, #l + 4)
      end
      max_width = math.min(max_width, 80)

      table.insert(virt_lines, { { indent .. '╭' .. string.rep('─', max_width) .. '╮', 'BBCommentBorder' } })

      local first_line_text = wrapped_lines[1] or ''
      if #first_line_text > first_line_width then
        first_line_text = first_line_text:sub(1, first_line_width)
      end
      local icon = ' '
      local content = icon .. '@' .. formatted.author .. ' (file): ' .. first_line_text
      local padding = max_width - vim.fn.strdisplaywidth(content)
      table.insert(virt_lines, {
        { indent .. '│ ', 'BBCommentBorder' },
        { icon, 'BBCommentIcon' },
        { '@' .. formatted.author .. ' (file): ', 'BBCommentAuthor' },
        { first_line_text .. string.rep(' ', math.max(0, padding)) .. ' ', 'BBCommentText' },
        { '│', 'BBCommentBorder' },
      })

      for i = 2, #wrapped_lines do
        local line_text = wrapped_lines[i]
        if line_text and line_text ~= '' then
          local line_padding = max_width - vim.fn.strdisplaywidth(line_text) - 2
          table.insert(virt_lines, {
            { indent .. '│   ', 'BBCommentBorder' },
            { line_text .. string.rep(' ', math.max(0, line_padding)) .. ' ', 'BBCommentText' },
            { '│', 'BBCommentBorder' },
          })
        end
      end

      table.insert(virt_lines, { { indent .. '╰' .. string.rep('─', max_width) .. '╯', 'BBCommentBorder' } })
    end

    local extmark_id = vim.api.nvim_buf_set_extmark(bufnr, ns_id, 0, 0, {
      virt_lines = virt_lines,
      virt_lines_above = true,
    })

    table.insert(extmark_ids, extmark_id)

    ::continue::
  end

  return extmark_ids
end

-- Render all comments for a buffer
function M.render_comments(bufnr)
  if not state.is_enabled() then
    return
  end

  -- Clear existing extmarks
  M.clear_comments(bufnr)

  local all_extmarks = {}

  -- Render line comments
  local comments_by_line = state.get_comments_for_buffer(bufnr)
  for line, comments in pairs(comments_by_line) do
    local extmarks = render_line_comments(bufnr, line, comments)
    vim.list_extend(all_extmarks, extmarks)
  end

  -- Render file-level comments
  local file_comments = state.get_file_comments_for_buffer(bufnr)
  if #file_comments > 0 then
    local extmarks = render_file_comments(bufnr, file_comments)
    vim.list_extend(all_extmarks, extmarks)
  end

  state.store_extmarks(bufnr, all_extmarks)
end

-- Clear all extmarks for a buffer
function M.clear_comments(bufnr)
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
  state.store_extmarks(bufnr, {})
end

-- Clear all extmarks for all buffers
function M.clear_all()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
    end
  end
end

-- Re-render comments for all loaded buffers
function M.refresh_all()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) and state.is_buffer_loaded(bufnr) then
      M.render_comments(bufnr)
    end
  end
end

-- Parse unified diff output and extract changed line numbers
-- Returns: { added = {line_nums...}, deleted = {line_nums...} }
local function parse_diff_hunks(diff_lines)
  local result = { added = {}, deleted = {} }
  local current_line = 0

  for _, line in ipairs(diff_lines) do
    -- Parse hunk header: @@ -old_start,old_count +new_start,new_count @@
    local new_start = line:match('^@@ %-[%d,]+ %+(%d+)')
    if new_start then
      current_line = tonumber(new_start) - 1
    elseif line:sub(1, 1) == '+' and line:sub(1, 3) ~= '+++' then
      -- Added line
      current_line = current_line + 1
      table.insert(result.added, current_line)
    elseif line:sub(1, 1) == '-' and line:sub(1, 3) ~= '---' then
      -- Deleted line (mark at current position)
      table.insert(result.deleted, current_line + 1)
    elseif line:sub(1, 1) == ' ' then
      -- Context line
      current_line = current_line + 1
    end
  end

  return result
end

-- Get diff for a file against target branch
local function get_file_diff(file_path, target_branch, callback)
  local git = require('bitbucket.git')

  git.get_git_root(function(err, repo_root)
    if err then
      callback(nil, { added = {}, deleted = {} })
      return
    end

    git.get_relative_path(file_path, function(err, rel_path)
      if err then
        callback(nil, { added = {}, deleted = {} })
        return
      end

      Job:new({
        command = 'git',
        args = { 'diff', 'origin/' .. target_branch .. '...HEAD', '--', rel_path },
        cwd = repo_root,
        on_exit = function(j, return_val)
          if return_val ~= 0 then
            vim.schedule(function()
              callback(nil, { added = {}, deleted = {} })
            end)
            return
          end

          local diff_lines = j:result()
          local hunks = parse_diff_hunks(diff_lines)
          vim.schedule(function()
            callback(nil, hunks)
          end)
        end,
      }):start()
    end)
  end)
end

-- Render diff signs and highlights for a buffer
function M.render_diff_signs(bufnr, callback)
  -- Wrap in vim.schedule to avoid fast event context errors
  vim.schedule(function()
    if not state.is_review_mode() then
      if callback then
        callback()
      end
      return
    end

    local target_branch = state.get_target_branch()
    if not target_branch then
      if callback then
        callback()
      end
      return
    end

    local file_path = vim.api.nvim_buf_get_name(bufnr)
    if file_path == '' then
      if callback then
        callback()
      end
      return
    end

    get_file_diff(file_path, target_branch, function(err, hunks)
    if err or not hunks then
      if callback then
        callback()
      end
      return
    end

    -- Clear existing diff signs for this buffer
    M.clear_diff_signs(bufnr)

    local buf_line_count = vim.api.nvim_buf_line_count(bufnr)

    -- Place signs for added lines using extmark sign_text
    for _, line in ipairs(hunks.added) do
      if line <= buf_line_count then
        vim.api.nvim_buf_set_extmark(bufnr, diff_ns_id, line - 1, 0, {
          sign_text = '+',
          sign_hl_group = 'BBDiffAdd',
          line_hl_group = 'BBDiffAddBg',
          priority = 5,
        })
      end
    end

    -- Place signs for deleted lines (show at next line)
    for _, line in ipairs(hunks.deleted) do
      if line <= buf_line_count and line > 0 then
        vim.api.nvim_buf_set_extmark(bufnr, diff_ns_id, line - 1, 0, {
          sign_text = '-',
          sign_hl_group = 'BBDiffDelete',
          priority = 5,
        })
      end
    end

    if callback then
      callback()
    end
    end)
  end)
end

-- Clear diff signs for a buffer
function M.clear_diff_signs(bufnr)
  vim.api.nvim_buf_clear_namespace(bufnr, diff_ns_id, 0, -1)
end

-- Clear diff signs for all buffers
function M.clear_all_diff_signs()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      M.clear_diff_signs(bufnr)
    end
  end
end

return M
