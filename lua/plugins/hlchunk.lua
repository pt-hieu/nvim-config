local colors = require 'config.colors'

-- Bracket around the code block under the cursor, ending in an arrow
return {
  'shellRaining/hlchunk.nvim',
  event = { 'BufReadPre', 'BufNewFile' },
  opts = {
    chunk = {
      enable = true,
      chars = {
        horizontal_line = '─',
        vertical_line = '│',
        left_top = '╭',
        left_bottom = '╰',
        right_arrow = '>',
      },
      style = { colors.orange, colors.red },
      duration = 0,
      delay = 0,
    },
  },
}
