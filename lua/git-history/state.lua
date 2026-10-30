local M = {}

local function new_state()
  return {
    buffer = nil,
    file_path = nil,
    git_root = nil,
    commits = {},
    current_idx = 1,
    layout = nil,
    commit_popup = nil,
    preview_popup = nil,
    commit_buf = nil,
    preview_buf = nil,
    -- Paging: loading_page guards against overlapping fetches
    loading_page = false,
    exhausted = false,
    -- Preview: diff_cache is keyed by full_hash; preview_req tags each request
    diff_cache = {},
    preview_req = 0,
    preview_timer = nil,
    preview_proc = nil,
  }
end

M.state = new_state()

function M.init_state(buffer, file_path)
  M.state.buffer = buffer
  M.state.file_path = file_path
  M.state.current_idx = 1
end

function M.get_current_commit()
  return M.state.commits[M.state.current_idx]
end

function M.move_selection(direction)
  local new_idx = M.state.current_idx + direction
  if new_idx >= 1 and new_idx <= #M.state.commits then
    M.state.current_idx = new_idx
    return true
  end
  return false
end

function M.reset_state()
  local old = M.state
  -- Replace first so in-flight callbacks see a different state table and bail out
  M.state = new_state()
  if old.preview_timer then
    old.preview_timer:stop()
    old.preview_timer:close()
  end
  if old.preview_proc then
    old.preview_proc:kill(15)
  end
  if old.layout then
    old.layout:unmount()
  end
end

return M
