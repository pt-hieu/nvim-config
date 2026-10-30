return {
  'lukas-reineke/indent-blankline.nvim',
  main = 'ibl',
  event = { 'BufReadPost', 'BufNewFile' },
  opts = {
    indent = {
      char = '▏',
    },
    -- hlchunk.nvim draws the current scope
    scope = {
      enabled = false,
    },
  },
  config = function(_, opts)
    local hooks = require('ibl.hooks')
    -- Set very subtle colors for low contrast
    hooks.register(hooks.type.HIGHLIGHT_SETUP, function()
      vim.api.nvim_set_hl(0, 'IblIndent', { fg = '#1a1a1a' })
      vim.api.nvim_set_hl(0, 'IblScope', { fg = '#a277ff' })
    end)
    hooks.register(hooks.type.ACTIVE, function(bufnr)
      return not require('config.large_file')(bufnr)
    end)
    require('ibl').setup(opts)
  end,
}
