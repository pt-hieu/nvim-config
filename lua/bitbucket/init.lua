local git = require('bitbucket.git')
local api = require('bitbucket.api')
local state = require('bitbucket.state')
local display = require('bitbucket.display')
local ui = require('bitbucket.ui')

local M = {}

local debounce_timer = nil
local DEBOUNCE_MS = 500

local function stop_debounce()
  if debounce_timer then
    debounce_timer:stop()
    debounce_timer:close()
    debounce_timer = nil
  end
end

-- Initialize PR detection (called once per session)
local function init_pr(callback)
  if state.has_pr() then
    callback(nil)
    return
  end

  git.get_remote_info(function(err, remote)
    if err then
      callback(err)
      return
    end

    git.get_current_branch(function(err, branch)
      if err then
        callback(err)
        return
      end

      api.find_pr_by_branch(remote.workspace, remote.repo, branch, function(err, pr)
        if err then
          callback(err)
          return
        end

        if not pr then
          -- No PR found - disable review mode
          state.set_review_mode(false)
          callback(nil)
          return
        end

        state.set_pr(pr, remote.workspace, remote.repo)

        -- Fetch detailed diffstat for review mode
        api.get_diffstat_detailed(remote.workspace, remote.repo, pr.id, function(err, files)
          if err then
            callback(err)
            return
          end

          -- Store both formats
          local files_set = {}
          for _, f in ipairs(files) do
            if f.path then
              files_set[f.path] = true
            end
          end
          state.set_pr_files(files_set)
          state.set_pr_files_detailed(files)

          -- Don't auto-enable review mode - only enable when user selects PR from list
          callback(nil)
        end)
      end)
    end)
  end)
end

-- Load comments for the current buffer
local function load_buffer_comments(bufnr, callback)
  local pr = state.get_pr()
  if not pr then
    callback(nil)
    return
  end

  local file_path = vim.api.nvim_buf_get_name(bufnr)
  if file_path == '' then
    callback(nil)
    return
  end

  git.get_relative_path(file_path, function(err, rel_path)
    if err then
      callback(err)
      return
    end

    -- Skip if file not in PR
    if not state.is_file_in_pr(rel_path) then
      callback(nil)
      return
    end

    -- Skip if already loaded
    if state.is_buffer_loaded(bufnr) then
      vim.schedule(function()
        display.render_comments(bufnr)
        display.render_diff_signs(bufnr)
      end)
      callback(nil)
      return
    end

    -- Fetch comments
    vim.schedule(function()
      vim.notify('BB: Fetching comments...', vim.log.levels.INFO)
    end)
    api.get_comments(pr.workspace, pr.repo, pr.id, function(err, comments)
      if err then
        vim.schedule(function()
          vim.notify('BB: ' .. err, vim.log.levels.ERROR)
        end)
        callback(err)
        return
      end

      vim.schedule(function()
        state.store_comments(bufnr, comments, rel_path)
        display.render_comments(bufnr)
        display.render_diff_signs(bufnr)
        vim.notify('BB: Comments loaded', vim.log.levels.INFO)
      end)

      callback(nil)
    end)
  end)
end

-- Public API

function M.enable()
  local bufnr = vim.api.nvim_get_current_buf()

  init_pr(function(err)
    if err then
      return
    end

    -- Buffer may have been closed during async init
    if not vim.api.nvim_buf_is_valid(bufnr) then
      return
    end

    if not state.has_pr() then
      return
    end

    load_buffer_comments(bufnr, function()
      -- Buffer may have been closed during async comment fetch
      if not vim.api.nvim_buf_is_valid(bufnr) then
        return
      end
      -- Also render diff signs even if file isn't in PR
      -- (comments will already render in load_buffer_comments)
      if state.is_review_mode() then
        display.render_diff_signs(bufnr)
      end
    end)
  end)
end

function M.disable()
  display.clear_all()
  display.clear_all_diff_signs()
  state.clear_all()
end

function M.toggle()
  local enabled = state.toggle_enabled()
  if enabled then
    display.refresh_all()
    vim.notify('BB comments: ON', vim.log.levels.INFO)
  else
    display.clear_all()
    vim.notify('BB comments: OFF', vim.log.levels.INFO)
  end
end

function M.refresh()
  local bufnr = vim.api.nvim_get_current_buf()
  state.clear_buffer(bufnr)

  init_pr(function(err)
    if err then
      vim.schedule(function()
        vim.notify('BB: ' .. err, vim.log.levels.ERROR)
      end)
      return
    end

    if not vim.api.nvim_buf_is_valid(bufnr) then
      return
    end

    if not state.has_pr() then
      vim.schedule(function()
        vim.notify('BB: No PR found for current branch', vim.log.levels.INFO)
      end)
      return
    end

    load_buffer_comments(bufnr, function(load_err)
      if load_err then
        vim.schedule(function()
          vim.notify('BB: ' .. load_err, vim.log.levels.ERROR)
        end)
      end
    end)
  end)
end

function M.reply()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1]

  local comments = state.get_comments_at_line(bufnr, line)
  if #comments == 0 then
    vim.notify('BB: No comment at cursor line', vim.log.levels.WARN)
    return
  end

  local function do_reply(comment)
    ui.show_reply_input(comment, function(content)
      local pr = state.get_pr()
      if not pr then
        vim.notify('BB: No PR context', vim.log.levels.ERROR)
        return
      end

      vim.notify('BB: Posting reply...', vim.log.levels.INFO)
      api.reply_to_comment(pr.workspace, pr.repo, pr.id, comment.id, content, function(err, _)
        if err then
          vim.notify('BB: ' .. err, vim.log.levels.ERROR)
          return
        end
        vim.notify('BB: Reply posted', vim.log.levels.INFO)
        M.refresh()
      end)
    end)
  end

  if #comments == 1 then
    do_reply(comments[1])
  else
    ui.select_comment(comments, do_reply)
  end
end

function M.resolve()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1]

  local comments = state.get_comments_at_line(bufnr, line)
  if #comments == 0 then
    vim.notify('BB: No comment at cursor line', vim.log.levels.WARN)
    return
  end

  -- Filter to unresolved comments only (check both resolved field and resolution object)
  local unresolved = vim.tbl_filter(function(c)
    local is_resolved = c.resolved or (c.resolution ~= nil and type(c.resolution) == 'table')
    return not is_resolved
  end, comments)

  if #unresolved == 0 then
    vim.notify('BB: All comments already resolved', vim.log.levels.INFO)
    return
  end

  local function do_resolve(comment)
    local pr = state.get_pr()
    if not pr then
      vim.notify('BB: No PR context', vim.log.levels.ERROR)
      return
    end

    vim.notify('BB: Resolving comment...', vim.log.levels.INFO)
    api.resolve_comment(pr.workspace, pr.repo, pr.id, comment.id, function(err, _)
      if err then
        vim.notify('BB: ' .. err, vim.log.levels.ERROR)
        return
      end
      vim.notify('BB: Comment resolved', vim.log.levels.INFO)
      M.refresh()
    end)
  end

  -- Find parent comment (no parent field = thread starter)
  local parent = nil
  for _, c in ipairs(unresolved) do
    if not c.parent then
      parent = c
      break
    end
  end

  -- If no explicit parent found, use first comment
  do_resolve(parent or unresolved[1])
end

function M.unresolve()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1]

  local comments = state.get_comments_at_line(bufnr, line)
  if #comments == 0 then
    vim.notify('BB: No comment at cursor line', vim.log.levels.WARN)
    return
  end

  -- Filter to resolved parent comments only (no parent field = thread starter)
  local resolved_parents = vim.tbl_filter(function(c)
    local is_resolved = c.resolved or (c.resolution ~= nil and type(c.resolution) == 'table')
    return is_resolved and not c.parent
  end, comments)

  if #resolved_parents == 0 then
    vim.notify('BB: No resolved comment thread at cursor line', vim.log.levels.INFO)
    return
  end

  local function do_unresolve(comment)
    local pr = state.get_pr()
    if not pr then
      vim.notify('BB: No PR context', vim.log.levels.ERROR)
      return
    end

    vim.notify('BB: Unresolving comment...', vim.log.levels.INFO)
    api.unresolve_comment(pr.workspace, pr.repo, pr.id, comment.id, function(err, _)
      if err then
        vim.notify('BB: ' .. err, vim.log.levels.ERROR)
        return
      end
      vim.notify('BB: Comment reopened', vim.log.levels.INFO)
      M.refresh()
    end)
  end

  -- Auto-pick first resolved parent
  do_unresolve(resolved_parents[1])
end

-- Internal: Checkout PR branch
local function checkout_pr(pr)
  local branch = pr.source and pr.source.branch and pr.source.branch.name
  if not branch then
    vim.notify('BB: Could not determine source branch', vim.log.levels.ERROR)
    return
  end

  git.branch_exists(branch, function(err, exists)
    if err then
      vim.notify('BB: ' .. err, vim.log.levels.ERROR)
      return
    end

    if exists then
      vim.notify('BB: Checking out ' .. branch .. '...', vim.log.levels.INFO)
      git.checkout_branch(branch, function(err)
        if err then
          vim.notify('BB: ' .. err, vim.log.levels.ERROR)
          return
        end
        vim.notify('BB: Checked out ' .. branch, vim.log.levels.INFO)
        state.reset()
        state.set_review_mode(true) -- Enable review mode when selecting PR
        vim.schedule(function()
          M.on_buf_enter()
          vim.cmd('checktime')
        end)
      end)
    else
      vim.notify('BB: Fetching origin...', vim.log.levels.INFO)
      git.fetch_origin(function(fetch_err)
        if fetch_err then
          vim.notify('BB: ' .. fetch_err, vim.log.levels.WARN)
        end

        vim.notify('BB: Checking out ' .. branch .. '...', vim.log.levels.INFO)
        git.checkout_remote_branch(branch, function(err)
          if err then
            vim.notify('BB: ' .. err, vim.log.levels.ERROR)
            return
          end
          vim.notify('BB: Checked out ' .. branch, vim.log.levels.INFO)
          state.reset()
          state.set_review_mode(true) -- Enable review mode when selecting PR
          vim.schedule(function()
            M.on_buf_enter()
            vim.cmd('checktime')
          end)
        end)
      end)
    end
  end)
end

-- Internal: Toggle approval for PR from list
local function toggle_approval(pr)
  local pr_list = state.get_pr_list()
  if not pr_list then
    return
  end

  -- Check if any approvals exist
  local has_approvals = false
  if pr.participants then
    for _, p in ipairs(pr.participants) do
      if p.approved then
        has_approvals = true
        break
      end
    end
  end

  if has_approvals then
    vim.notify('BB: Unapproving PR...', vim.log.levels.INFO)
    api.unapprove_pr(pr_list.workspace, pr_list.repo, pr.id, function(err)
      if err then
        vim.notify('BB: ' .. err, vim.log.levels.ERROR)
        return
      end
      vim.notify('BB: PR unapproved', vim.log.levels.INFO)
      M.list_prs()
    end)
  else
    vim.notify('BB: Approving PR...', vim.log.levels.INFO)
    api.approve_pr(pr_list.workspace, pr_list.repo, pr.id, function(err)
      if err then
        vim.notify('BB: ' .. err, vim.log.levels.ERROR)
        return
      end
      vim.notify('BB: PR approved', vim.log.levels.INFO)
      M.list_prs()
    end)
  end
end

-- Internal: Toggle draft status for PR from list
local function toggle_draft(pr)
  local pr_list = state.get_pr_list()
  if not pr_list then
    return
  end

  local new_draft = not pr.is_draft
  local action = new_draft and 'Marking as draft' or 'Marking as ready'

  vim.notify('BB: ' .. action .. '...', vim.log.levels.INFO)
  api.update_pr(pr_list.workspace, pr_list.repo, pr.id, { is_draft = new_draft }, function(err)
    if err then
      vim.notify('BB: ' .. err, vim.log.levels.ERROR)
      return
    end
    vim.notify('BB: PR ' .. (new_draft and 'marked as draft' or 'marked as ready'), vim.log.levels.INFO)
    M.list_prs()
  end)
end

-- List open PRs
function M.list_prs()
  git.is_worktree(function(err, is_wt)
    if err then
      vim.notify('BB: ' .. err, vim.log.levels.ERROR)
      return
    end

    if is_wt then
      vim.notify('BB: PR list disabled in worktree', vim.log.levels.WARN)
      return
    end

    git.get_remote_info(function(err, remote)
      if err then
        vim.notify('BB: ' .. err, vim.log.levels.ERROR)
        return
      end

      -- Get current branch for highlighting
      git.get_current_branch(function(err, current_branch)
        if err then
          current_branch = nil
        end

        vim.notify('BB: Fetching PRs...', vim.log.levels.INFO)
        api.list_prs(remote.workspace, remote.repo, function(err, prs)
          if err then
            vim.notify('BB: ' .. err, vim.log.levels.ERROR)
            return
          end

          if #prs == 0 then
            vim.notify('BB: No open PRs found', vim.log.levels.INFO)
            return
          end

          state.set_pr_list(remote.workspace, remote.repo, prs)

          vim.schedule(function()
            ui.show_pr_list(prs, current_branch, {
              on_select = function(pr)
                checkout_pr(pr)
              end,
              on_approve = function(pr)
                toggle_approval(pr)
              end,
              on_toggle_draft = function(pr)
                toggle_draft(pr)
              end,
            })
          end)
        end)
      end)
    end)
  end)
end

-- Toggle review mode
function M.toggle_review_mode()
  local new_state = not state.is_review_mode()
  state.set_review_mode(new_state)

  if new_state then
    -- Render diff signs for current buffer
    local bufnr = vim.api.nvim_get_current_buf()
    display.render_diff_signs(bufnr)
  else
    -- Clear all diff signs
    display.clear_all_diff_signs()
  end

  vim.notify('BB: Review mode ' .. (new_state and 'ON' or 'OFF'), vim.log.levels.INFO)
end

-- Check if review mode is active
function M.is_review_mode()
  return state.is_review_mode()
end

-- Telescope picker for PR files
function M.show_pr_files_telescope()
  if not state.has_pr() then
    vim.notify('BB: No PR context', vim.log.levels.WARN)
    return
  end

  local files = state.get_pr_files_detailed()
  if #files == 0 then
    vim.notify('BB: No changed files in PR', vim.log.levels.INFO)
    return
  end

  local pickers = require('telescope.pickers')
  local finders = require('telescope.finders')
  local conf = require('telescope.config').values
  local actions = require('telescope.actions')
  local action_state = require('telescope.actions.state')

  local status_icons = {
    added = ' ',
    modified = '󰏫 ',
    removed = ' ',
    renamed = '󰁕 ',
  }

  pickers
    .new({}, {
      prompt_title = 'PR Files',
      finder = finders.new_table({
        results = files,
        entry_maker = function(entry)
          local icon = status_icons[entry.status] or '? '
          local stats = string.format('+%d -%d', entry.lines_added or 0, entry.lines_removed or 0)
          local display = string.format('%s%s [%s]', icon, entry.path, stats)
          return {
            value = entry,
            display = display,
            ordinal = entry.path,
            path = entry.path,
          }
        end,
      }),
      sorter = conf.generic_sorter({}),
      previewer = conf.file_previewer({}),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          if selection and selection.value and selection.value.path then
            git.get_git_root(function(err, root)
              if err then
                vim.notify('BB: ' .. err, vim.log.levels.ERROR)
                return
              end
              local full_path = root .. '/' .. selection.value.path
              vim.schedule(function()
                if vim.fn.filereadable(full_path) == 1 then
                  vim.cmd('edit ' .. vim.fn.fnameescape(full_path))
                else
                  vim.notify('BB: File not found: ' .. selection.value.path, vim.log.levels.WARN)
                end
              end)
            end)
          end
        end)
        return true
      end,
    })
    :find()
end

-- Approve current PR
function M.approve()
  local pr = state.get_pr()
  if not pr then
    vim.notify('BB: No PR context', vim.log.levels.WARN)
    return
  end

  vim.notify('BB: Approving PR...', vim.log.levels.INFO)
  api.approve_pr(pr.workspace, pr.repo, pr.id, function(err)
    if err then
      vim.notify('BB: ' .. err, vim.log.levels.ERROR)
      return
    end
    vim.notify('BB: PR approved', vim.log.levels.INFO)
  end)
end

-- Unapprove current PR
function M.unapprove()
  local pr = state.get_pr()
  if not pr then
    vim.notify('BB: No PR context', vim.log.levels.WARN)
    return
  end

  vim.notify('BB: Unapproving PR...', vim.log.levels.INFO)
  api.unapprove_pr(pr.workspace, pr.repo, pr.id, function(err)
    if err then
      vim.notify('BB: ' .. err, vim.log.levels.ERROR)
      return
    end
    vim.notify('BB: PR unapproved', vim.log.levels.INFO)
  end)
end

-- Toggle draft status for current PR
function M.toggle_draft()
  local pr = state.get_pr()
  if not pr then
    vim.notify('BB: No PR context', vim.log.levels.WARN)
    return
  end

  api.get_pr(pr.workspace, pr.repo, pr.id, function(err, full_pr)
    if err then
      vim.notify('BB: ' .. err, vim.log.levels.ERROR)
      return
    end

    local new_draft = not full_pr.is_draft
    local action = new_draft and 'Marking as draft' or 'Marking as ready'

    vim.notify('BB: ' .. action .. '...', vim.log.levels.INFO)
    api.update_pr(pr.workspace, pr.repo, pr.id, { is_draft = new_draft }, function(err)
      if err then
        vim.notify('BB: ' .. err, vim.log.levels.ERROR)
        return
      end
      vim.notify('BB: PR ' .. (new_draft and 'marked as draft' or 'marked as ready'), vim.log.levels.INFO)
    end)
  end)
end

-- Auto-load on BufEnter with debounce
function M.on_buf_enter()
  if not state.is_enabled() then
    return
  end

  stop_debounce()

  local t = vim.uv.new_timer()
  debounce_timer = t
  t:start(DEBOUNCE_MS, 0, vim.schedule_wrap(function()
    t:stop()
    t:close()
    if debounce_timer == t then
      debounce_timer = nil
    end
    M.enable()
  end))
end

-- Re-fetch comments after save (line numbers may have shifted)
function M.on_buf_write()
  if not state.is_enabled() or not state.has_pr() then
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  if state.is_buffer_loaded(bufnr) then
    -- Just re-render with existing comments
    display.render_comments(bufnr)
    display.render_diff_signs(bufnr)
  end
end

-- Setup autocmds
function M.setup()
  local group = vim.api.nvim_create_augroup('BitbucketComments', { clear = true })

  vim.api.nvim_create_autocmd('BufEnter', {
    group = group,
    callback = function()
      M.on_buf_enter()
    end,
  })

  vim.api.nvim_create_autocmd('BufWritePost', {
    group = group,
    callback = function()
      M.on_buf_write()
    end,
  })

  -- Clean up stale state when buffers are closed (prevents memory leak)
  vim.api.nvim_create_autocmd('BufWipeout', {
    group = group,
    callback = function(ev)
      state.clear_buffer(ev.buf)
    end,
  })

  -- Trigger initial load for current buffer (already entered before plugin loaded)
  M.on_buf_enter()
end

return M
