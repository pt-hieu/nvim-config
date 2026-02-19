-- LLM Ghost Text Completion
-- Virtual text suggestions from local llama.cpp server

local M = {}

-- State
local ns = vim.api.nvim_create_namespace('llm_ghost')
local state = {
  suggestion = nil, -- current suggestion text
  bufnr = nil, -- buffer where suggestion is shown
  timer = nil, -- debounce timer
  job = nil, -- current curl job
  loading = false, -- request in flight
  server_ok = false, -- server connection status
  health_timer = nil, -- periodic health check timer
}

-- Default config
M.config = {
  url = 'http://localhost:8080',
  debounce_ms = 300,
  max_tokens = 128,
  temperature = 0.2,
  context_lines = 50, -- lines before/after cursor for context
  stop = { '\n\n', '<|fim_pad|>', '<|endoftext|>', '<|fim_prefix|>', '<|fim_suffix|>', '<|fim_middle|>', '<cursor>' },
  filetypes_exclude = { 'TelescopePrompt', 'neo-tree', 'lazy', 'mason', 'help', 'qf' },
}

-- Check server health
local function check_server()
  vim.fn.jobstart({ 'curl', '-s', '-o', '/dev/null', '-w', '%{http_code}', M.config.url .. '/health' }, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      local code = data and table.concat(data, ''):gsub('%s+', '')
      state.server_ok = (code == '200')
    end,
    on_exit = function(_, exit_code)
      if exit_code ~= 0 then
        state.server_ok = false
      end
      vim.schedule(function()
        vim.cmd('redrawstatus')
      end)
    end,
  })
end

-- Setup with user config
function M.setup(opts)
  M.config = vim.tbl_deep_extend('force', M.config, opts or {})

  -- Start health check
  check_server()

  -- Periodic health check every 30s
  if state.health_timer then
    vim.fn.timer_stop(state.health_timer)
  end
  state.health_timer = vim.fn.timer_start(30000, function()
    check_server()
  end, { ['repeat'] = -1 })
end

-- Check if completion should trigger
local function should_trigger()
  -- Mode check
  if vim.fn.mode() ~= 'i' then
    return false
  end

  -- Skip special buffers (file-tree, popups, etc.)
  local buftype = vim.bo.buftype
  if buftype == 'nofile' or buftype == 'prompt' or buftype == 'popup' then
    return false
  end

  -- Filetype exclusion
  local ft = vim.bo.filetype
  for _, excluded in ipairs(M.config.filetypes_exclude) do
    if ft == excluded then
      return false
    end
  end

  -- Only trigger at end of line
  local cursor = vim.api.nvim_win_get_cursor(0)
  local col = cursor[2]
  local line = vim.api.nvim_get_current_line()
  if col < #line then
    return false
  end

  return true
end

-- Get code context around cursor (FIM format)
local function get_context()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row, col = cursor[1], cursor[2]

  -- Read only the lines needed for context (avoid full buffer read)
  local total_lines = vim.api.nvim_buf_line_count(bufnr)
  local start_line = math.max(1, row - M.config.context_lines)
  local fetch_end = math.min(total_lines, row + M.config.context_lines)
  local slice = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, fetch_end, false)

  local function get_line(line_num)
    return slice[line_num - start_line + 1] or ''
  end

  -- Build prefix (lines before cursor + current line up to cursor)
  local prefix_lines = {}
  for i = start_line, row - 1 do
    table.insert(prefix_lines, get_line(i))
  end
  local current_line = get_line(row)
  local prefix_part = current_line:sub(1, col)
  table.insert(prefix_lines, prefix_part)
  local prefix = table.concat(prefix_lines, '\n')

  -- Build suffix (rest of current line + lines after cursor)
  local suffix_lines = {}
  local suffix_part = current_line:sub(col + 1)
  if suffix_part ~= '' then
    table.insert(suffix_lines, suffix_part)
  end
  for i = row + 1, fetch_end do
    table.insert(suffix_lines, get_line(i))
  end
  local suffix = table.concat(suffix_lines, '\n')

  return prefix, suffix
end

-- Cancel pending request
local function cancel_request()
  if state.job then
    vim.fn.jobstop(state.job)
    state.job = nil
  end
  if state.timer then
    vim.fn.timer_stop(state.timer)
    state.timer = nil
  end
  state.loading = false
end

-- Clear ghost text
function M.dismiss()
  if state.bufnr and vim.api.nvim_buf_is_valid(state.bufnr) then
    vim.api.nvim_buf_clear_namespace(state.bufnr, ns, 0, -1)
  end
  state.suggestion = nil
  state.bufnr = nil
end

-- Cancel pending requests and dismiss ghost text
function M.cancel()
  cancel_request()
  M.dismiss()
end

-- Show loading indicator as ghost text
local function show_loading_indicator()
  M.dismiss()

  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)

  vim.api.nvim_buf_set_extmark(bufnr, ns, cursor[1] - 1, cursor[2], {
    virt_text = { { '  󰦖', 'Comment' } },
    virt_text_pos = 'inline',
  })

  state.bufnr = bufnr
end

-- Update loading state
local function set_loading(loading)
  state.loading = loading

  if loading then
    show_loading_indicator()
  end
end

-- Display ghost text at cursor
local function show_ghost_text(text)
  if not text or text == '' then
    return
  end

  M.dismiss()

  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1] - 1 -- 0-indexed

  -- Split multiline suggestion
  local lines = vim.split(text, '\n', { plain = true })

  -- First line as inline virtual text
  local virt_text = { { lines[1], 'Comment' } }

  -- Additional lines as virtual lines below
  local virt_lines = {}
  for i = 2, #lines do
    table.insert(virt_lines, { { lines[i], 'Comment' } })
  end

  vim.api.nvim_buf_set_extmark(bufnr, ns, row, cursor[2], {
    virt_text = virt_text,
    virt_text_pos = 'inline',
    virt_lines = #virt_lines > 0 and virt_lines or nil,
    hl_mode = 'combine',
  })

  state.suggestion = text
  state.bufnr = bufnr
end

-- Make completion request to llama.cpp
local function request_completion()
  if not should_trigger() then
    return
  end

  cancel_request()

  local prefix, suffix = get_context()

  -- FIM prompt format for Qwen
  local prompt = '<|fim_prefix|>' .. prefix .. '<|fim_suffix|>' .. suffix .. '<|fim_middle|>'

  local body = vim.fn.json_encode({
    prompt = prompt,
    n_predict = M.config.max_tokens,
    temperature = M.config.temperature,
    stop = M.config.stop,
    stream = false,
  })

  local cmd = {
    'curl',
    '-s',
    '-X',
    'POST',
    M.config.url .. '/completion',
    '-H',
    'Content-Type: application/json',
    '-d',
    body,
  }

  set_loading(true)

  state.job = vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      if not data or #data == 0 then
        return
      end
      local response = table.concat(data, '')
      if response == '' then
        return
      end

      vim.schedule(function()
        local ok, result = pcall(vim.fn.json_decode, response)
        if ok and result and result.content then
          local content = result.content
          -- Filter special tokens
          content = content:gsub('<cursor>', '')
          content = content:gsub('<|[^|]+|>', '')
          -- Trim leading/trailing whitespace but preserve internal structure
          content = content:gsub('^%s+', ''):gsub('%s+$', '')
          if content ~= '' then
            show_ghost_text(content)
          end
        end
      end)
    end,
    on_exit = function()
      state.job = nil
      set_loading(false)
    end,
  })
end

-- Trigger completion with debounce
function M.trigger()
  M.dismiss() -- Clear ghost text immediately on typing

  if not should_trigger() then
    return
  end

  cancel_request()

  state.timer = vim.fn.timer_start(M.config.debounce_ms, function()
    state.timer = nil
    request_completion()
  end)
end

-- Accept current suggestion
function M.accept()
  if not state.suggestion then
    return false
  end

  local suggestion = state.suggestion
  M.dismiss()

  -- Insert the suggestion at cursor
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row, col = cursor[1] - 1, cursor[2]
  local lines = vim.split(suggestion, '\n', { plain = true })

  if #lines == 1 then
    -- Single line: insert inline
    vim.api.nvim_buf_set_text(0, row, col, row, col, lines)
    vim.api.nvim_win_set_cursor(0, { row + 1, col + #lines[1] })
  else
    -- Multiline: insert all lines
    local current_line = vim.api.nvim_buf_get_lines(0, row, row + 1, false)[1] or ''
    local before = current_line:sub(1, col)
    local after = current_line:sub(col + 1)

    -- First line joins with text before cursor
    lines[1] = before .. lines[1]
    -- Last line joins with text after cursor
    lines[#lines] = lines[#lines] .. after

    vim.api.nvim_buf_set_lines(0, row, row + 1, false, lines)

    -- Move cursor to end of insertion
    local new_row = row + #lines
    local new_col = #lines[#lines] - #after
    vim.api.nvim_win_set_cursor(0, { new_row, new_col })
  end

  return true
end

-- Check if suggestion is visible
function M.is_visible()
  return state.suggestion ~= nil
end

-- Check if request is in flight
function M.is_loading()
  return state.loading
end

-- Check if server is connected
function M.is_server_ok()
  return state.server_ok
end

return M
