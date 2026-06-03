return {
  'folke/which-key.nvim',
  event = 'VeryLazy',
  opts = {
    preset = 'modern',
    spec = {
      { '<leader>f', group = 'find' },
      { '<leader>b', group = 'buffer' },
      { '<leader>s', group = 'split' },
      { '<leader>g', group = 'git' },           -- session 11
      { '<leader>l', group = 'lsp' },           -- session 6
      { '<leader>d', group = 'debug/diag' },    -- session 8
      { '<leader>t', group = 'test' },          -- session 8
    },
  },
  keys = {
    { '<leader>?', function() require('which-key').show({ global = true }) end, desc = 'Keymaps' },
  },
}
