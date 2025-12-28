return {
  {
    dir = vim.fn.stdpath('config') .. '/lua/git-history',
    name = 'git-history',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'MunifTanjim/nui.nvim',
      'nvim-tree/nvim-web-devicons',
    },
    cmd = 'GitHistory',
    keys = {
      { '<leader>gh', '<cmd>GitHistory<cr>', desc = 'Git [H]istory' },
    },
    config = function()
      local git_history = require('git-history')

      vim.api.nvim_create_user_command('GitHistory', function()
        git_history.open()
      end, { desc = 'Open git history for current buffer' })

      -- Set up Aura theme highlight groups
      vim.api.nvim_set_hl(0, 'GitHistoryHash', { fg = '#a277ff', bold = true })
      vim.api.nvim_set_hl(0, 'GitHistoryDate', { fg = '#6d6d6d' })
      vim.api.nvim_set_hl(0, 'GitHistoryAuthor', { fg = '#61ffca' })
      vim.api.nvim_set_hl(0, 'GitHistoryMessage', { fg = '#edecee' })
      vim.api.nvim_set_hl(0, 'GitHistoryCursor', { bg = '#3d375e' })
      vim.api.nvim_set_hl(0, 'GitHistoryBorder', { fg = '#a277ff' })

      -- Diff view highlight groups
      vim.api.nvim_set_hl(0, 'GitHistoryDiffAdd', { fg = '#61ffca' })
      vim.api.nvim_set_hl(0, 'GitHistoryDiffDelete', { fg = '#ff6767' })
      vim.api.nvim_set_hl(0, 'GitHistoryDiffContext', { fg = '#edecee' })
      vim.api.nvim_set_hl(0, 'GitHistoryDiffHunk', { fg = '#82e2ff' })
      vim.api.nvim_set_hl(0, 'GitHistoryDiffHeader', { fg = '#a277ff' })
    end,
  },
}
