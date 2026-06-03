return {
  'stevearc/conform.nvim',
  event = { 'BufWritePre' },
  cmd = { 'ConformInfo' },
  keys = {
    { '<leader>cf', function() require('conform').format({ async = true, lsp_fallback = true }) end, mode = { 'n', 'x' }, desc = 'Format' },
  },
  opts = {
    formatters_by_ft = {
      go     = { 'goimports', 'gofumpt' },
      python = { 'ruff_format', 'ruff_organize_imports' },
      lua    = { 'stylua' },
      sh     = { 'shfmt' },
      bash   = { 'shfmt' },
      yaml   = { 'yamlfmt' },
      json   = { 'jq' },
      markdown = { 'prettier' },
      cs     = { 'csharpier' },
      http   = { 'kulala' },
    },
    format_on_save = function(bufnr)
      -- Disable autosave-format for huge files
      if vim.api.nvim_buf_line_count(bufnr) > 5000 then return end
      return { timeout_ms = 1500, lsp_fallback = true }
    end,
    formatters = {
      shfmt = { prepend_args = { '-i', '2', '-bn', '-ci' } },
      kulala = {
        command = 'kulala-fmt',
        args = { 'format', '$FILENAME' },
        stdin = false,
      },
    },
  },
  init = function()
    -- Use conform.formatexpr for `gq` motion
    vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
  end,
}
