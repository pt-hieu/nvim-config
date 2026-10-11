return {
  {
    'nvim-treesitter/nvim-treesitter',
    build = ':TSUpdate',
    config = function()
      require('nvim-treesitter').setup()
      require('nvim-treesitter').install({ 'typescript', 'tsx', 'javascript', 'yaml', 'json', 'css', 'html', 'bash' })
      vim.api.nvim_create_autocmd('FileType', {
        callback = function()
          pcall(vim.treesitter.start)
        end,
      })
    end,
  },
}
