local M = {}

function M.open()
  local current_buf = vim.api.nvim_get_current_buf()
  local file_path = vim.api.nvim_buf_get_name(current_buf)

  -- Validate file exists
  if file_path == '' then
    vim.notify('No file in current buffer', vim.log.levels.WARN)
    return
  end

  -- Check if in git repo
  local git = require('git-history.git')
  git.get_git_root(function(err, root)
    if err then
      vim.schedule(function()
        vim.notify('Not in a git repository', vim.log.levels.WARN)
      end)
      return
    end

    -- Get relative path
    git.get_relative_path(file_path, function(err, rel_path)
      if err then
        vim.schedule(function()
          vim.notify('Could not determine file path', vim.log.levels.ERROR)
        end)
        return
      end

      -- Fetch commit history
      git.get_file_history(rel_path, function(err, commits)
        if err then
          vim.schedule(function()
            vim.notify('Error fetching git history: ' .. err, vim.log.levels.ERROR)
          end)
          return
        end

        if #commits == 0 then
          vim.schedule(function()
            vim.notify('No commits found for this file', vim.log.levels.INFO)
          end)
          return
        end

        -- Initialize state and create UI (must be scheduled to avoid fast event context)
        vim.schedule(function()
          local state = require('git-history.state')
          state.init_state(current_buf, rel_path, commits)

          -- Create and show UI
          local ui = require('git-history.ui')
          ui.create_and_show()
        end)
      end)
    end)
  end)
end

return M
