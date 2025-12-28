local curl = require('plenary.curl')
local M = {}

local BASE_URL = 'https://api.bitbucket.org/2.0'

-- Get auth header from env vars
local function get_auth_header()
  local username = os.getenv('BITBUCKET_USERNAME')
  local token = os.getenv('BITBUCKET_TOKEN')

  if not username or not token then
    return nil, 'Missing BITBUCKET_USERNAME or BITBUCKET_TOKEN env vars'
  end

  -- Base64 encode credentials
  local credentials = username .. ':' .. token
  local encoded = vim.base64.encode(credentials)
  return 'Basic ' .. encoded, nil
end

-- Make authenticated POST request
local function api_post(path, body, callback)
  local auth, err = get_auth_header()
  if not auth then
    vim.schedule(function()
      callback(err, nil)
    end)
    return
  end

  local url = BASE_URL .. path

  curl.post(url, {
    headers = {
      authorization = auth,
      content_type = 'application/json',
    },
    body = vim.json.encode(body),
    callback = function(response)
      vim.schedule(function()
        if response.status ~= 201 and response.status ~= 200 then
          callback('API error: ' .. response.status .. ' - ' .. (response.body or ''), nil)
          return
        end

        local ok, data = pcall(vim.json.decode, response.body)
        if not ok then
          callback('JSON parse error', nil)
          return
        end

        callback(nil, data)
      end)
    end,
  })
end

-- Make authenticated DELETE request
local function api_delete(path, callback)
  local auth, err = get_auth_header()
  if not auth then
    vim.schedule(function()
      callback(err, nil)
    end)
    return
  end

  local url = BASE_URL .. path

  curl.delete(url, {
    headers = {
      authorization = auth,
    },
    callback = function(response)
      vim.schedule(function()
        if response.status ~= 204 and response.status ~= 200 then
          callback('API error: ' .. response.status .. ' - ' .. (response.body or ''), nil)
          return
        end

        callback(nil, {})
      end)
    end,
  })
end

-- Make authenticated PUT request
local function api_put(path, body, callback)
  local auth, err = get_auth_header()
  if not auth then
    vim.schedule(function()
      callback(err, nil)
    end)
    return
  end

  local url = BASE_URL .. path

  curl.put(url, {
    headers = {
      authorization = auth,
      content_type = 'application/json',
    },
    body = vim.json.encode(body),
    callback = function(response)
      vim.schedule(function()
        if response.status ~= 200 then
          callback('API error: ' .. response.status .. ' - ' .. (response.body or ''), nil)
          return
        end

        local ok, data = pcall(vim.json.decode, response.body)
        if not ok then
          callback('JSON parse error', nil)
          return
        end

        callback(nil, data)
      end)
    end,
  })
end

-- Make authenticated GET request
local function api_get(path, params, callback)
  local auth, err = get_auth_header()
  if not auth then
    vim.schedule(function()
      callback(err, nil)
    end)
    return
  end

  local url = BASE_URL .. path
  if params then
    local query_parts = {}
    for k, v in pairs(params) do
      table.insert(query_parts, k .. '=' .. vim.uri_encode(tostring(v)))
    end
    if #query_parts > 0 then
      url = url .. '?' .. table.concat(query_parts, '&')
    end
  end

  curl.get(url, {
    headers = {
      authorization = auth,
      content_type = 'application/json',
    },
    callback = function(response)
      vim.schedule(function()
        if response.status ~= 200 then
          callback('API error: ' .. response.status .. ' - ' .. (response.body or ''), nil)
          return
        end

        local ok, data = pcall(vim.json.decode, response.body)
        if not ok then
          callback('JSON parse error', nil)
          return
        end

        callback(nil, data)
      end)
    end,
  })
end

-- Find PR by source branch
-- Returns PR object or nil if not found
function M.find_pr_by_branch(workspace, repo, branch, callback)
  local query = string.format('source.branch.name="%s" AND state="OPEN"', branch)
  local path = string.format('/repositories/%s/%s/pullrequests', workspace, repo)

  api_get(path, { q = query, pagelen = 1 }, function(err, data)
    if err then
      callback(err, nil)
      return
    end

    if data.values and #data.values > 0 then
      callback(nil, data.values[1])
    else
      -- No PR found - not an error, just nil
      callback(nil, nil)
    end
  end)
end

-- Get all comments for a PR
-- Returns list of comments with inline info
function M.get_comments(workspace, repo, pr_id, callback)
  local path = string.format('/repositories/%s/%s/pullrequests/%d/comments', workspace, repo, pr_id)
  local all_comments = {}

  local function fetch_page(page)
    api_get(path, { pagelen = 100, page = page }, function(err, data)
      if err then
        callback(err, nil)
        return
      end

      -- Append comments
      for _, comment in ipairs(data.values or {}) do
        table.insert(all_comments, comment)
      end

      -- Check for next page
      if data.next then
        fetch_page(page + 1)
      else
        callback(nil, all_comments)
      end
    end)
  end

  fetch_page(1)
end

-- Get diffstat to know which files are in the PR
function M.get_diffstat(workspace, repo, pr_id, callback)
  local path = string.format('/repositories/%s/%s/pullrequests/%d/diffstat', workspace, repo, pr_id)

  api_get(path, { pagelen = 100 }, function(err, data)
    if err then
      callback(err, nil)
      return
    end

    local files = {}
    for _, entry in ipairs(data.values or {}) do
      -- entry.new/old can be nil, table, or cjson.null (userdata)
      if type(entry.new) == 'table' and entry.new.path then
        files[entry.new.path] = true
      end
      if type(entry.old) == 'table' and entry.old.path then
        files[entry.old.path] = true
      end
    end

    callback(nil, files)
  end)
end

-- Reply to a comment
function M.reply_to_comment(workspace, repo, pr_id, parent_id, content, callback)
  local path = string.format('/repositories/%s/%s/pullrequests/%d/comments', workspace, repo, pr_id)

  local body = {
    content = { raw = content },
    parent = { id = parent_id },
  }

  api_post(path, body, callback)
end

-- Resolve a comment thread
function M.resolve_comment(workspace, repo, pr_id, comment_id, callback)
  local path = string.format(
    '/repositories/%s/%s/pullrequests/%d/comments/%d/resolve',
    workspace,
    repo,
    pr_id,
    comment_id
  )

  api_post(path, {}, callback)
end

-- Unresolve (reopen) a comment thread
function M.unresolve_comment(workspace, repo, pr_id, comment_id, callback)
  local path = string.format(
    '/repositories/%s/%s/pullrequests/%d/comments/%d/resolve',
    workspace,
    repo,
    pr_id,
    comment_id
  )

  api_delete(path, callback)
end

-- List all open PRs for repository
function M.list_prs(workspace, repo, callback)
  local path = string.format('/repositories/%s/%s/pullrequests', workspace, repo)

  api_get(path, { state = 'OPEN', pagelen = 50 }, function(err, data)
    if err then
      callback(err, nil)
      return
    end
    callback(nil, data.values or {})
  end)
end

-- Get single PR details
function M.get_pr(workspace, repo, pr_id, callback)
  local path = string.format('/repositories/%s/%s/pullrequests/%d', workspace, repo, pr_id)

  api_get(path, nil, function(err, data)
    if err then
      callback(err, nil)
      return
    end
    callback(nil, data)
  end)
end

-- Approve PR
function M.approve_pr(workspace, repo, pr_id, callback)
  local path = string.format('/repositories/%s/%s/pullrequests/%d/approve', workspace, repo, pr_id)

  api_post(path, {}, callback)
end

-- Unapprove PR
function M.unapprove_pr(workspace, repo, pr_id, callback)
  local path = string.format('/repositories/%s/%s/pullrequests/%d/approve', workspace, repo, pr_id)

  api_delete(path, callback)
end

-- Update PR (for draft status, title, etc.)
function M.update_pr(workspace, repo, pr_id, updates, callback)
  local path = string.format('/repositories/%s/%s/pullrequests/%d', workspace, repo, pr_id)

  api_put(path, updates, callback)
end

-- Get diffstat with full details (status, lines added/removed)
function M.get_diffstat_detailed(workspace, repo, pr_id, callback)
  local path = string.format('/repositories/%s/%s/pullrequests/%d/diffstat', workspace, repo, pr_id)

  api_get(path, { pagelen = 100 }, function(err, data)
    if err then
      callback(err, nil)
      return
    end

    local files = {}
    for _, entry in ipairs(data.values or {}) do
      local file = {
        status = entry.status,
        old_path = type(entry.old) == 'table' and entry.old.path or nil,
        new_path = type(entry.new) == 'table' and entry.new.path or nil,
        lines_added = entry.lines_added or 0,
        lines_removed = entry.lines_removed or 0,
      }
      file.path = file.new_path or file.old_path
      if file.path then
        table.insert(files, file)
      end
    end

    callback(nil, files)
  end)
end

return M
