local M = {}

M.state = {
  buffer = nil,
  file_path = nil,
  commits = {},
  current_idx = 1,
  layout = nil,
  commit_popup = nil,
  preview_popup = nil,
  commit_buf = nil,
  preview_buf = nil,
}

function M.init_state(buffer, file_path, commits)
  M.state.buffer = buffer
  M.state.file_path = file_path
  M.state.commits = commits
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
  if M.state.layout then
    M.state.layout:unmount()
  end
  M.state = {
    buffer = nil,
    file_path = nil,
    commits = {},
    current_idx = 1,
    layout = nil,
    commit_popup = nil,
    preview_popup = nil,
    commit_buf = nil,
    preview_buf = nil,
  }
end

return M
