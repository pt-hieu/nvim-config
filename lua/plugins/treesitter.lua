return {
  {
    'nvim-treesitter/nvim-treesitter',
    build = function()
      local ts = require('nvim-treesitter')
      ts.install({ 'typescript', 'tsx', 'javascript', 'yaml', 'json', 'css', 'html', 'bash' })
      ts.update()
    end,
    config = function()
      require('nvim-treesitter').setup()

      -- MDX has no parser of its own, so it borrows the markdown one
      vim.filetype.add({ extension = { mdx = 'mdx' } })
      vim.treesitter.language.register('markdown', 'mdx')

      vim.api.nvim_create_autocmd('FileType', {
        callback = function(event)
          if require('config.large_file')(event.buf) then
            return
          end
          pcall(vim.treesitter.start)
        end,
      })
    end,
  },
}
