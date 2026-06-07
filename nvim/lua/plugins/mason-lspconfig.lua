return {
  'williamboman/mason-lspconfig.nvim',
  dependencies = { 'williamboman/mason.nvim' },
  opts = {
    ensure_installed = {
      'gopls',
      'basedpyright',     -- Pyright fork, more permissive license; use 'pyright' if you prefer
      'ruff',             -- Python linter+formatter as an LSP
      'lua_ls',
      'omnisharp',        -- C# LSP (Roslyn-based; replaces csharp-ls)
    },
    automatic_installation = true,
  },
}
