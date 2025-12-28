local Input = require('nui.input')
local Menu = require('nui.menu')

local M = {}

-- Show menu to select a comment when multiple on same line
function M.select_comment(comments, callback)
  local lines = {}
  for i, c in ipairs(comments) do
    local author = c.user and c.user.display_name or 'Unknown'
    local preview = (c.content and c.content.raw or ''):sub(1, 40):gsub('\n', ' ')
    table.insert(lines, Menu.item(string.format('%d. @%s: %s', i, author, preview), { comment = c }))
  end

  local menu = Menu({
    position = '50%',
    size = {
      width = 60,
      height = math.min(#lines + 2, 10),
    },
    border = {
      style = 'rounded',
      text = {
        top = ' Select Comment ',
        top_align = 'center',
      },
    },
    win_options = {
      winhighlight = 'Normal:Normal,FloatBorder:BBCommentBorder',
    },
  }, {
    lines = lines,
    keymap = {
      focus_next = { 'j', '<Down>', '<Tab>' },
      focus_prev = { 'k', '<Up>', '<S-Tab>' },
      close = { '<Esc>', 'q' },
      submit = { '<CR>' },
    },
    on_submit = function(item)
      callback(item.comment)
    end,
  })

  menu:mount()
end

-- Show input dialog for reply text
function M.show_reply_input(comment, callback)
  local author = comment.user and comment.user.display_name or 'Unknown'

  local input = Input({
    position = '50%',
    size = {
      width = 60,
    },
    border = {
      style = 'rounded',
      text = {
        top = string.format(' Reply to @%s ', author),
        top_align = 'center',
      },
    },
    win_options = {
      winhighlight = 'Normal:Normal,FloatBorder:BBCommentBorder',
    },
  }, {
    prompt = '> ',
    on_submit = function(value)
      if value and value ~= '' then
        callback(value)
      end
    end,
  })

  input:mount()

  -- Start in insert mode
  vim.cmd('startinsert!')
end

-- Show PR list menu
function M.show_pr_list(prs, current_branch, callbacks)
  local lines = {}
  local current_pr_idx = nil

  for idx, pr in ipairs(prs) do
    local author = pr.author and pr.author.display_name or 'Unknown'
    local branch = pr.source and pr.source.branch and pr.source.branch.name or '?'
    local title = pr.title or 'No title'

    -- Check if this PR matches current branch
    local is_current = current_branch and branch == current_branch
    if is_current then
      current_pr_idx = idx
    end

    -- State indicators
    local indicators = {}

    -- Draft indicator (check multiple possible field names)
    local is_draft = pr.is_draft or pr.draft or false
    if is_draft then
      table.insert(indicators, '[DRAFT]')
    end

    -- Check if has any approvals
    local approval_count = 0
    if pr.participants then
      for _, p in ipairs(pr.participants) do
        if p.approved then
          approval_count = approval_count + 1
        end
      end
    end
    if approval_count > 0 then
      table.insert(indicators, string.format('✓%d', approval_count))
    end

    local indicator_str = #indicators > 0 and ' ' .. table.concat(indicators, ' ') or ''

    -- Prefix with ◉ for current branch
    local prefix = is_current and '◉ ' or '  '

    local display = string.format(
      '%s#%d: %s (%s) by %s%s',
      prefix,
      pr.id,
      title:sub(1, 33),
      branch:sub(1, 16),
      author,
      indicator_str
    )

    table.insert(lines, Menu.item(display, { pr = pr, is_current = is_current }))
  end

  local menu = Menu({
    position = '50%',
    size = {
      width = 80,
      height = math.min(#lines + 2, 20),
    },
    border = {
      style = 'rounded',
      text = {
        top = ' Open Pull Requests ',
        top_align = 'center',
        bottom = ' <CR>=checkout  a=approve  d=draft  q=close ',
        bottom_align = 'center',
      },
    },
    win_options = {
      winhighlight = 'Normal:Normal,FloatBorder:BBCommentBorder',
    },
  }, {
    lines = lines,
    keymap = {
      focus_next = { 'j', '<Down>' },
      focus_prev = { 'k', '<Up>' },
      close = { '<Esc>', 'q' },
      submit = { '<CR>' },
    },
    on_submit = function(item)
      if callbacks.on_select then
        callbacks.on_select(item.pr)
      end
    end,
  })

  -- Custom keymaps for actions
  menu:map('n', 'a', function()
    local node = menu.tree:get_node()
    if node and node.pr and callbacks.on_approve then
      menu:unmount()
      callbacks.on_approve(node.pr)
    end
  end, { noremap = true })

  menu:map('n', 'd', function()
    local node = menu.tree:get_node()
    if node and node.pr and callbacks.on_toggle_draft then
      menu:unmount()
      callbacks.on_toggle_draft(node.pr)
    end
  end, { noremap = true })

  menu:mount()

  -- Move cursor to current PR if found
  if current_pr_idx then
    vim.schedule(function()
      local win = menu.winid
      if win and vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_set_cursor(win, { current_pr_idx, 0 })
      end
    end)
  end

  return menu
end

return M
