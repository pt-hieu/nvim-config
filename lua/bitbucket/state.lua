local M = {}

M.state = {
  enabled = true, -- global toggle
  pr = nil, -- { id, title, workspace, repo }
  pr_files = {}, -- set of file paths in PR
  pr_files_detailed = {}, -- list of { path, status, lines_added, lines_removed }
  comments = {}, -- { [bufnr] = { [line] = {comment, ...} } }
  file_comments = {}, -- { [bufnr] = {comment, ...} } (no line)
  extmarks = {}, -- { [bufnr] = {extmark_id, ...} }
  loaded_buffers = {}, -- { [bufnr] = true } buffers with comments loaded
  pr_list = nil, -- { workspace, repo, prs = {...} } for PR list view
  selected_pr = nil, -- PR object from list for actions
  review_mode = false, -- PR review mode toggle
}

function M.set_pr(pr_data, workspace, repo)
  if pr_data then
    -- Extract target branch from destination
    local target_branch = nil
    if pr_data.destination and pr_data.destination.branch then
      target_branch = pr_data.destination.branch.name
    end

    M.state.pr = {
      id = pr_data.id,
      title = pr_data.title,
      workspace = workspace,
      repo = repo,
      target_branch = target_branch,
    }
    vim.schedule(function()
      vim.cmd('redrawstatus')
    end)
  else
    M.state.pr = nil
  end
end

function M.set_pr_files(files)
  M.state.pr_files = files or {}
end

function M.is_file_in_pr(rel_path)
  return M.state.pr_files[rel_path] == true
end

function M.has_pr()
  return M.state.pr ~= nil
end

function M.get_pr()
  return M.state.pr
end

function M.get_target_branch()
  return M.state.pr and M.state.pr.target_branch
end

-- Check if a comment is resolved
local function is_comment_resolved(comment)
  return comment.resolved or (comment.resolution ~= nil and type(comment.resolution) == 'table')
end

-- Store comments for a buffer, indexed by line
function M.store_comments(bufnr, comments, rel_path)
  M.state.comments[bufnr] = {}
  M.state.file_comments[bufnr] = {}

  -- Build resolution map: comment_id -> resolved status
  local resolution_map = {}
  for _, comment in ipairs(comments) do
    resolution_map[comment.id] = is_comment_resolved(comment)
  end

  -- Propagate resolution from parent to children
  for _, comment in ipairs(comments) do
    if comment.parent and comment.parent.id then
      local parent_resolved = resolution_map[comment.parent.id]
      if parent_resolved then
        resolution_map[comment.id] = true
      end
    end
  end

  for _, comment in ipairs(comments) do
    -- Apply propagated resolution status
    comment.resolved = resolution_map[comment.id] or false

    -- Filter comments for this file
    if comment.inline and comment.inline.path == rel_path then
      local line = comment.inline.to or comment.inline.from
      if line then
        if not M.state.comments[bufnr][line] then
          M.state.comments[bufnr][line] = {}
        end
        table.insert(M.state.comments[bufnr][line], comment)
      else
        -- File-level comment (no line)
        table.insert(M.state.file_comments[bufnr], comment)
      end
    elseif not comment.inline then
      -- General PR comment - skip for now (not file-specific)
    end
  end

  M.state.loaded_buffers[bufnr] = true
end

function M.get_comments_for_buffer(bufnr)
  return M.state.comments[bufnr] or {}
end

function M.get_file_comments_for_buffer(bufnr)
  return M.state.file_comments[bufnr] or {}
end

function M.get_comments_at_line(bufnr, line)
  local comments_by_line = M.state.comments[bufnr]
  if not comments_by_line then
    return {}
  end
  return comments_by_line[line] or {}
end

function M.is_buffer_loaded(bufnr)
  return M.state.loaded_buffers[bufnr] == true
end

function M.store_extmarks(bufnr, extmark_ids)
  M.state.extmarks[bufnr] = extmark_ids
end

function M.get_extmarks(bufnr)
  return M.state.extmarks[bufnr] or {}
end

function M.clear_buffer(bufnr)
  M.state.comments[bufnr] = nil
  M.state.file_comments[bufnr] = nil
  M.state.extmarks[bufnr] = nil
  M.state.loaded_buffers[bufnr] = nil
end

function M.clear_all()
  M.state.comments = {}
  M.state.file_comments = {}
  M.state.extmarks = {}
  M.state.loaded_buffers = {}
end

function M.toggle_enabled()
  M.state.enabled = not M.state.enabled
  return M.state.enabled
end

function M.is_enabled()
  return M.state.enabled
end

function M.reset()
  M.state = {
    enabled = true,
    pr = nil,
    pr_files = {},
    pr_files_detailed = {},
    comments = {},
    file_comments = {},
    extmarks = {},
    loaded_buffers = {},
    pr_list = nil,
    selected_pr = nil,
    review_mode = false,
  }
end

function M.set_review_mode(enabled)
  M.state.review_mode = enabled
  vim.schedule(function()
    vim.cmd('redrawstatus')
  end)
end

function M.is_review_mode()
  return M.state.review_mode
end

function M.set_pr_files_detailed(files)
  M.state.pr_files_detailed = files or {}
end

function M.get_pr_files_detailed()
  return M.state.pr_files_detailed
end

function M.set_pr_list(workspace, repo, prs)
  M.state.pr_list = {
    workspace = workspace,
    repo = repo,
    prs = prs,
  }
end

function M.get_pr_list()
  return M.state.pr_list
end

function M.set_selected_pr(pr)
  M.state.selected_pr = pr
end

function M.get_selected_pr()
  return M.state.selected_pr
end

return M
