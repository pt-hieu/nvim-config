local M = {}

function M.open()
  local current_buf = vim.api.nvim_get_current_buf()
  local file_path = vim.api.nvim_buf_get_name(current_buf)

  -- Validate file exists
  if file_path == '' then
    vim.notify('No file in current buffer', vim.log.levels.WARN)
    return
  end

  -- Open the UI immediately with a loading placeholder, then fill it in
  local state = require('git-history.state')
  local ui = require('git-history.ui')
  state.init_state(current_buf, file_path)
  ui.create_and_show()
  local s = state.state

  require('git-history.git').get_repo_info(file_path, function(err, root, rel_path)
    vim.schedule(function()
      if state.state ~= s then
        return
      end
      if err then
        ui.close()
        vim.notify('Not in a git repository', vim.log.levels.WARN)
        return
      end
      s.git_root = root
      s.file_path = rel_path
      ui.load_more()
    end)
  end)
end

return M
