local M = {}

-- Run git in `cwd`, returning the vim.system handle so callers can kill it.
-- The callback runs in a fast event context; schedule before touching the UI.
local function run(args, cwd, callback)
  local cmd = { 'git' }
  vim.list_extend(cmd, args)
  return vim.system(cmd, { text = true, cwd = cwd }, callback)
end

local function split_output(stdout)
  return vim.split(stdout or '', '\n', { plain = true, trimempty = true })
end

-- Resolve the repo root and the repo-relative path of `file_path` in one call.
function M.get_repo_info(file_path, callback)
  local dir = vim.fs.dirname(file_path)
  run({ 'rev-parse', '--show-toplevel', '--show-prefix' }, dir, function(res)
    if res.code ~= 0 then
      callback('Not a git repository')
      return
    end
    local lines = vim.split(res.stdout, '\n', { plain = true })
    callback(nil, lines[1], (lines[2] or '') .. vim.fs.basename(file_path))
  end)
end

function M.get_file_history(git_root, file_path, skip, limit, callback)
  run({
    'log',
    '--follow',
    '--name-only',
    '-n', tostring(limit),
    '--skip', tostring(skip),
    '--format=%H\x1f%h\x1f%an\x1f%ar\x1f%s',
    '--',
    file_path,
  }, git_root, function(res)
    if res.code == 0 then
      callback(nil, M.parse_commits(split_output(res.stdout), file_path))
    else
      callback('Git log failed: ' .. (res.stderr or ''))
    end
  end)
end

function M.get_file_at_commit(git_root, commit_hash, file_path, callback)
  run({ 'show', commit_hash .. ':' .. file_path }, git_root, function(res)
    if res.code == 0 then
      callback(nil, split_output(res.stdout))
    else
      callback('File not found in commit')
    end
  end)
end

function M.get_commit_diff(git_root, commit_hash, file_path, callback)
  return run({ 'show', commit_hash, '--', file_path }, git_root, function(res)
    if res.code == 0 then
      callback(nil, split_output(res.stdout))
    else
      callback('Could not get diff for commit')
    end
  end)
end

-- Each commit is a line containing \x1f, followed by its path (from --name-only)
-- as written in that commit, which differs from `fallback_path` across renames.
function M.parse_commits(lines, fallback_path)
  local commits = {}
  for _, line in ipairs(lines) do
    if line:find('\x1f', 1, true) then
      local parts = vim.split(line, '\x1f', { plain = true })
      if #parts >= 5 then
        table.insert(commits, {
          full_hash = parts[1],
          short_hash = parts[2],
          author = parts[3],
          relative_date = parts[4],
          message = parts[5],
          path = fallback_path,
        })
      end
    elseif #commits > 0 and line ~= '' then
      commits[#commits].path = line
    end
  end
  return commits
end

return M
