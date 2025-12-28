-- LLM Ghost Text Plugin
-- Local code completion via llama.cpp

return {
  dir = vim.fn.stdpath('config') .. '/lua/llm-ghost',
  name = 'llm-ghost',
  event = 'InsertEnter',
  config = function()
    local ghost = require('llm-ghost')

    ghost.setup({
      url = 'http://localhost:8080',
      debounce_ms = 300,
      max_tokens = 128,
      temperature = 0.2,
      context_lines = 50,
    })

    -- Trigger on text change in insert mode
    vim.api.nvim_create_autocmd('TextChangedI', {
      group = vim.api.nvim_create_augroup('LLMGhost', { clear = true }),
      callback = function()
        ghost.trigger()
      end,
    })

    -- Dismiss on cursor move (only significant movement)
    local last_col = 0
    vim.api.nvim_create_autocmd('CursorMovedI', {
      group = vim.api.nvim_create_augroup('LLMGhostMove', { clear = true }),
      callback = function()
        local col = vim.api.nvim_win_get_cursor(0)[2]
        -- Only dismiss if moved more than 1 char (allows typing to continue)
        if math.abs(col - last_col) > 1 then
          ghost.dismiss()
        end
        last_col = col
      end,
    })

    -- Cancel pending requests and dismiss on leaving insert mode
    vim.api.nvim_create_autocmd('InsertLeave', {
      group = vim.api.nvim_create_augroup('LLMGhostLeave', { clear = true }),
      callback = function()
        ghost.cancel()
      end,
    })

    -- Tab to accept (with fallback)
    vim.keymap.set('i', '<Tab>', function()
      if ghost.is_visible() then
        ghost.accept()
      else
        -- Fallback: insert tab or trigger completion
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Tab>', true, false, true), 'n', false)
      end
    end, { desc = 'Accept LLM suggestion or Tab' })

    -- Escape to dismiss
    vim.keymap.set('i', '<C-]>', function()
      if ghost.is_visible() then
        ghost.dismiss()
      end
    end, { desc = 'Dismiss LLM suggestion' })

    -- Manual trigger
    vim.keymap.set('i', '<C-g>', function()
      ghost.trigger()
    end, { desc = 'Trigger LLM completion' })
  end,
}
