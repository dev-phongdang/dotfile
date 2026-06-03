return {
  'akinsho/bufferline.nvim',
  event = 'VeryLazy',
  dependencies = { 'nvim-tree/nvim-web-devicons' },
  keys = {
    { '<leader>bp', '<cmd>BufferLinePick<cr>',          desc = 'Pick buffer' },
    { '<leader>bP', '<cmd>BufferLinePickClose<cr>',     desc = 'Pick & close buffer' },
    { '[b',         '<cmd>BufferLineCyclePrev<cr>',     desc = 'Prev buffer' },
    { ']b',         '<cmd>BufferLineCycleNext<cr>',     desc = 'Next buffer' },
  },
  opts = {
    options = {
      mode = 'buffers',
      diagnostics = 'nvim_lsp',
      show_buffer_close_icons = false,
      offsets = { { filetype = 'neo-tree', text = 'Explorer', highlight = 'Directory' } },
    },
  },
}
