return {
  dir = vim.fn.stdpath('config'),
  name = 'bitbucket',
  dependencies = { 'nvim-lua/plenary.nvim', 'MunifTanjim/nui.nvim' },
  event = 'VeryLazy',
  keys = {
    {
      '<leader>bc',
      function()
        require('bitbucket').toggle()
      end,
      desc = 'Toggle BB comments',
    },
    {
      '<leader>bf',
      function()
        require('bitbucket').refresh()
      end,
      desc = 'Fetch BB comments',
    },
    {
      '<leader>br',
      function()
        require('bitbucket').reply()
      end,
      desc = 'Reply to BB comment',
    },
    {
      '<leader>bs',
      function()
        require('bitbucket').resolve()
      end,
      desc = 'Resolve BB comment',
    },
    {
      '<leader>bu',
      function()
        require('bitbucket').unresolve()
      end,
      desc = 'Unresolve BB comment',
    },
    -- PR management keymaps
    {
      '<leader>bp',
      function()
        require('bitbucket').list_prs()
      end,
      desc = 'List BB PRs',
    },
    {
      '<leader>bv',
      function()
        require('bitbucket').show_pr_files_telescope()
      end,
      desc = 'Telescope BB PR files',
    },
    {
      '<leader>bm',
      function()
        require('bitbucket').toggle_review_mode()
      end,
      desc = 'Toggle BB review mode',
    },
    {
      '<leader>ba',
      function()
        require('bitbucket').approve()
      end,
      desc = 'Approve BB PR',
    },
    {
      '<leader>bA',
      function()
        require('bitbucket').unapprove()
      end,
      desc = 'Unapprove BB PR',
    },
    {
      '<leader>bd',
      function()
        require('bitbucket').toggle_draft()
      end,
      desc = 'Toggle BB PR draft',
    },
  },
  cmd = {
    'BBComments',
    'BBRefresh',
    'BBReply',
    'BBResolve',
    'BBUnresolve',
    'BBList',
    'BBPRFiles',
    'BBReviewMode',
    'BBApprove',
    'BBUnapprove',
    'BBToggleDraft',
  },
  config = function()
    -- Aura theme highlight groups
    vim.api.nvim_set_hl(0, 'BBCommentIcon', { fg = '#a277ff' }) -- purple
    vim.api.nvim_set_hl(0, 'BBCommentAuthor', { fg = '#61ffca' }) -- green
    vim.api.nvim_set_hl(0, 'BBCommentText', { fg = '#edecee' }) -- white
    vim.api.nvim_set_hl(0, 'BBCommentBorder', { fg = '#a277ff' }) -- purple border
    vim.api.nvim_set_hl(0, 'BBCommentResolved', { fg = '#6d6d6d' }) -- gray

    -- File status highlight groups
    vim.api.nvim_set_hl(0, 'BBFileAdded', { fg = '#61ffca' }) -- green
    vim.api.nvim_set_hl(0, 'BBFileModified', { fg = '#ffca85' }) -- orange
    vim.api.nvim_set_hl(0, 'BBFileRemoved', { fg = '#ff6767' }) -- red
    vim.api.nvim_set_hl(0, 'BBFileRenamed', { fg = '#82e2ff' }) -- blue

    -- Diff annotation highlight groups (review mode)
    vim.api.nvim_set_hl(0, 'BBDiffAdd', { fg = '#61ffca' }) -- green sign
    vim.api.nvim_set_hl(0, 'BBDiffChange', { fg = '#ffca85' }) -- orange sign
    vim.api.nvim_set_hl(0, 'BBDiffDelete', { fg = '#ff6767' }) -- red sign
    vim.api.nvim_set_hl(0, 'BBDiffAddBg', { bg = '#1a3a2a' }) -- subtle green bg
    vim.api.nvim_set_hl(0, 'BBDiffDeleteBg', { bg = '#3a1a1a' }) -- subtle red bg

    -- User commands
    vim.api.nvim_create_user_command('BBComments', function()
      require('bitbucket').toggle()
    end, { desc = 'Toggle Bitbucket PR comments' })

    vim.api.nvim_create_user_command('BBRefresh', function()
      require('bitbucket').refresh()
    end, { desc = 'Refresh Bitbucket PR comments' })

    vim.api.nvim_create_user_command('BBReply', function()
      require('bitbucket').reply()
    end, { desc = 'Reply to Bitbucket PR comment at cursor' })

    vim.api.nvim_create_user_command('BBResolve', function()
      require('bitbucket').resolve()
    end, { desc = 'Resolve Bitbucket PR comment at cursor' })

    vim.api.nvim_create_user_command('BBUnresolve', function()
      require('bitbucket').unresolve()
    end, { desc = 'Unresolve Bitbucket PR comment at cursor' })

    -- PR management commands
    vim.api.nvim_create_user_command('BBList', function()
      require('bitbucket').list_prs()
    end, { desc = 'List open Bitbucket PRs' })

    vim.api.nvim_create_user_command('BBPRFiles', function()
      require('bitbucket').show_pr_files_telescope()
    end, { desc = 'Telescope PR changed files' })

    vim.api.nvim_create_user_command('BBReviewMode', function()
      require('bitbucket').toggle_review_mode()
    end, { desc = 'Toggle PR review mode' })

    vim.api.nvim_create_user_command('BBApprove', function()
      require('bitbucket').approve()
    end, { desc = 'Approve current PR' })

    vim.api.nvim_create_user_command('BBUnapprove', function()
      require('bitbucket').unapprove()
    end, { desc = 'Unapprove current PR' })

    vim.api.nvim_create_user_command('BBToggleDraft', function()
      require('bitbucket').toggle_draft()
    end, { desc = 'Toggle PR draft status' })

    -- Setup autocmds
    require('bitbucket').setup()
  end,
}
