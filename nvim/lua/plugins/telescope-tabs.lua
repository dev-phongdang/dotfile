return {
  'LukasPietzschmann/telescope-tabs',
  dependencies = { 'nvim-telescope/telescope.nvim' },
  keys = {
    {
      '<leader>ft',
      function() require('telescope-tabs').list_tabs() end,
      desc = 'Tabs',
    },
    {
      'g<Tab>',
      function() require('telescope-tabs').go_to_previous() end,
      desc = 'Previous tab (telescope-tabs stack)',
    },
  },
  config = function()
    require('telescope').load_extension('telescope-tabs')
    require('telescope-tabs').setup({})
  end,
}
