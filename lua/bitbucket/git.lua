local Job = require('plenary.job')
local M = {}

-- Cache for session
M._cache = {
  branch = nil,
  remote_info = nil,
  git_root = nil,
}

function M.get_git_root(callback)
  if M._cache.git_root then
    callback(nil, M._cache.git_root)
    return
  end

  Job:new({
    command = 'git',
    args = { 'rev-parse', '--show-toplevel' },
    on_exit = function(j, return_val)
      if return_val == 0 then
        M._cache.git_root = j:result()[1]
        callback(nil, M._cache.git_root)
      else
        callback('Not a git repository')
      end
    end,
  }):start()
end

function M.get_current_branch(callback)
  if M._cache.branch then
    callback(nil, M._cache.branch)
    return
  end

  Job:new({
    command = 'git',
    args = { 'rev-parse', '--abbrev-ref', 'HEAD' },
    on_exit = function(j, return_val)
      if return_val == 0 then
        M._cache.branch = j:result()[1]
        callback(nil, M._cache.branch)
      else
        callback('Could not get current branch')
      end
    end,
  }):start()
end

-- Parse remote URL to extract workspace and repo
-- Supports: git@bitbucket.org:workspace/repo.git
--           https://bitbucket.org/workspace/repo.git
function M.parse_remote_url(url)
  -- SSH format: git@bitbucket.org:workspace/repo.git
  local workspace, repo = url:match('git@bitbucket%.org:([^/]+)/([^/%.]+)')
  if workspace and repo then
    return { workspace = workspace, repo = repo }
  end

  -- HTTPS format: https://bitbucket.org/workspace/repo.git
  workspace, repo = url:match('https://bitbucket%.org/([^/]+)/([^/%.]+)')
  if workspace and repo then
    return { workspace = workspace, repo = repo }
  end

  -- HTTPS with credentials: https://user@bitbucket.org/workspace/repo.git
  workspace, repo = url:match('https://[^@]+@bitbucket%.org/([^/]+)/([^/%.]+)')
  if workspace and repo then
    return { workspace = workspace, repo = repo }
  end

  return nil
end

function M.get_remote_info(callback)
  if M._cache.remote_info then
    callback(nil, M._cache.remote_info)
    return
  end

  Job:new({
    command = 'git',
    args = { 'remote', 'get-url', 'origin' },
    on_exit = function(j, return_val)
      if return_val ~= 0 then
        callback('Could not get remote URL')
        return
      end

      local url = j:result()[1]
      local info = M.parse_remote_url(url)
      if info then
        M._cache.remote_info = info
        callback(nil, info)
      else
        callback('Could not parse Bitbucket URL: ' .. url)
      end
    end,
  }):start()
end

function M.get_relative_path(file_path, callback)
  Job:new({
    command = 'git',
    args = { 'ls-files', '--full-name', file_path },
    on_exit = function(j, return_val)
      if return_val == 0 and #j:result() > 0 then
        callback(nil, j:result()[1])
      else
        -- Try relative to git root for untracked files
        M.get_git_root(function(err, root)
          if err then
            callback(err)
            return
          end
          -- Strip git root from file path
          local rel = file_path:gsub('^' .. vim.pesc(root) .. '/', '')
          callback(nil, rel)
        end)
      end
    end,
  }):start()
end

-- Clear cache (useful when switching branches)
function M.clear_cache()
  M._cache = {
    branch = nil,
    remote_info = nil,
    git_root = nil,
  }
end

-- Check if currently in a git worktree (not main working directory)
function M.is_worktree(callback)
  Job:new({
    command = 'git',
    args = { 'rev-parse', '--git-common-dir' },
    on_exit = function(j, return_val)
      if return_val ~= 0 then
        callback('Not a git repository', false)
        return
      end

      local common_dir = j:result()[1]

      Job:new({
        command = 'git',
        args = { 'rev-parse', '--git-dir' },
        on_exit = function(j2, return_val2)
          if return_val2 ~= 0 then
            callback('Not a git repository', false)
            return
          end

          local git_dir = j2:result()[1]

          -- In worktree: git-dir differs from git-common-dir
          local is_wt = git_dir ~= common_dir or git_dir:match('%.git/worktrees/')
          callback(nil, is_wt)
        end,
      }):start()
    end,
  }):start()
end

-- Checkout branch
function M.checkout_branch(branch, callback)
  Job:new({
    command = 'git',
    args = { 'checkout', branch },
    on_exit = function(j, return_val)
      if return_val == 0 then
        M.clear_cache()
        callback(nil)
      else
        local stderr = table.concat(j:stderr_result(), '\n')
        callback('Checkout failed: ' .. stderr)
      end
    end,
  }):start()
end

-- Checkout remote branch (creates local tracking branch)
function M.checkout_remote_branch(branch, callback)
  Job:new({
    command = 'git',
    args = { 'checkout', '-b', branch, 'origin/' .. branch },
    on_exit = function(j, return_val)
      if return_val == 0 then
        M.clear_cache()
        callback(nil)
      else
        local stderr = table.concat(j:stderr_result(), '\n')
        callback('Checkout failed: ' .. stderr)
      end
    end,
  }):start()
end

-- Fetch from remote
function M.fetch_origin(callback)
  Job:new({
    command = 'git',
    args = { 'fetch', 'origin' },
    on_exit = function(j, return_val)
      if return_val == 0 then
        callback(nil)
      else
        local stderr = table.concat(j:stderr_result(), '\n')
        callback('Fetch failed: ' .. stderr)
      end
    end,
  }):start()
end

-- Check if branch exists locally
function M.branch_exists(branch, callback)
  Job:new({
    command = 'git',
    args = { 'rev-parse', '--verify', 'refs/heads/' .. branch },
    on_exit = function(_, return_val)
      callback(nil, return_val == 0)
    end,
  }):start()
end

return M
