return {
  'williamboman/mason-lspconfig.nvim',
  dependencies = { 'williamboman/mason.nvim' },
  opts = {
    ensure_installed = {
      'gopls',
      'basedpyright',     -- Pyright fork, more permissive license; use 'pyright' if you prefer
      'ruff',             -- Python linter+formatter as an LSP
      'lua_ls',
      -- C# (roslyn) is installed via mason directly, not mason-lspconfig —
      -- see lua/plugins/mason.lua and lua/plugins/roslyn.lua.
    },
    automatic_installation = true,
  },
}
