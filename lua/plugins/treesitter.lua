return {
  {
    'nvim-treesitter/nvim-treesitter',
    build = ':TSUpdate',
    config = function()
      require('nvim-treesitter').setup()
      require('nvim-treesitter').install({ 'typescript', 'tsx', 'javascript', 'yaml', 'json', 'css', 'html', 'bash' })

      -- MDX has no parser of its own, so it borrows the markdown one
      vim.filetype.add({ extension = { mdx = 'mdx' } })
      vim.treesitter.language.register('markdown', 'mdx')

      vim.api.nvim_create_autocmd('FileType', {
        callback = function()
          pcall(vim.treesitter.start)
        end,
      })
    end,
  },
}
