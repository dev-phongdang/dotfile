return {
  'nvim-telescope/telescope.nvim',
  branch = 'master',
  dependencies = {
    'nvim-lua/plenary.nvim',
    -- Native fzf sorter (C extension) — much faster for big repos
    { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' },
    -- Route vim.ui.select() through telescope (e.g. the .NET debug project picker)
    'nvim-telescope/telescope-ui-select.nvim',
  },
  cmd = 'Telescope',
  keys = {
    { '<leader>ff', '<cmd>Telescope find_files<cr>',  desc = 'Find files' },
    { '<leader>fg', '<cmd>Telescope live_grep<cr>',   desc = 'Live grep' },
    { '<leader>fb', '<cmd>Telescope buffers<cr>',     desc = 'Buffers' },
    { '<leader>fh', '<cmd>Telescope help_tags<cr>',   desc = 'Help' },
    { '<leader>fr', '<cmd>Telescope oldfiles<cr>',    desc = 'Recent files' },
    { '<leader>fs', '<cmd>Telescope lsp_document_symbols<cr>', desc = 'Symbols (file)' },
    { '<leader>fw', '<cmd>Telescope lsp_dynamic_workspace_symbols<cr>', desc = 'Symbols (workspace)' },
    { '<leader>fd', '<cmd>Telescope diagnostics<cr>', desc = 'Diagnostics' },
    { '<leader>fk', '<cmd>Telescope keymaps<cr>',     desc = 'Keymaps' },
    { '<leader>fc', '<cmd>Telescope commands<cr>',    desc = 'Commands' },
    { '<leader>/',  '<cmd>Telescope current_buffer_fuzzy_find<cr>', desc = 'Search buffer' },
  },
  opts = {
    defaults = {
      path_display = { 'truncate' },
      mappings = {
        i = {
          ['<C-j>'] = 'move_selection_next',
          ['<C-k>'] = 'move_selection_previous',
          ['<C-q>'] = 'send_to_qflist',          -- everything to quickfix
          ['<Esc>'] = 'close',                   -- one tap to exit
        },
      },
    },
  },
  config = function(_, opts)
    local telescope = require('telescope')
    -- Render vim.ui.select() as a telescope dropdown. Without a UI backend the
    -- core inputlist prompt shows with no visible items under noice.nvim.
    opts.extensions = opts.extensions or {}
    opts.extensions['ui-select'] = { require('telescope.themes').get_dropdown() }
    telescope.setup(opts)
    pcall(telescope.load_extension, 'fzf')
    pcall(telescope.load_extension, 'ui-select')
  end,
}
