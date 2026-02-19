local Job = require('plenary.job')
local M = {}

function M.get_git_root(callback)
  Job:new({
    command = 'git',
    args = { 'rev-parse', '--show-toplevel' },
    on_exit = function(j, return_val)
      if return_val == 0 then
        callback(nil, j:result()[1])
      else
        callback('Not a git repository')
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
        callback('File not tracked by git')
      end
    end,
  }):start()
end

function M.get_file_history(file_path, callback)
  Job:new({
    command = 'git',
    args = {
      'log',
      '--follow',
      '-n', '200',
      '--format=%H\x1f%h\x1f%an\x1f%ar\x1f%s',
      '--',
      file_path,
    },
    on_exit = function(j, return_val)
      if return_val == 0 then
        local commits = M.parse_commits(j:result())
        callback(nil, commits)
      else
        callback('Git log failed: ' .. table.concat(j:stderr_result(), '\n'))
      end
    end,
  }):start()
end

function M.get_file_at_commit(commit_hash, file_path, callback)
  Job:new({
    command = 'git',
    args = { 'show', commit_hash .. ':' .. file_path },
    on_exit = function(j, return_val)
      if return_val == 0 then
        callback(nil, j:result())
      else
        callback('File not found in commit')
      end
    end,
  }):start()
end

function M.get_commit_diff(commit_hash, file_path, callback)
  Job:new({
    command = 'git',
    args = {
      'show',
      commit_hash,
      '--',
      file_path,
    },
    on_exit = function(j, return_val)
      if return_val == 0 then
        callback(nil, j:result())
      else
        callback('Could not get diff for commit')
      end
    end,
  }):start()
end

function M.parse_commits(lines)
  local commits = {}
  for _, line in ipairs(lines) do
    local parts = vim.split(line, '\x1f', { plain = true })
    if #parts >= 5 then
      table.insert(commits, {
        full_hash = parts[1],
        short_hash = parts[2],
        author = parts[3],
        relative_date = parts[4],
        message = parts[5],
      })
    end
  end
  return commits
end

return M
