return {
  'williamboman/mason.nvim',
  cmd = { 'Mason', 'MasonInstall', 'MasonUninstall', 'MasonUpdate' },
  build = ':MasonUpdate',
  opts = {
    -- The Crashdummyy registry ships the `roslyn` package (the Roslyn
    -- language server that roslyn.nvim drives). Run `:MasonInstall roslyn`
    -- once after `:MasonUpdate`.
    registries = {
      'github:mason-org/mason-registry',
      'github:Crashdummyy/mason-registry',
    },
    ui = {
      icons = { package_installed = '✓', package_pending = '➜', package_uninstalled = '✗' },
    },
  },
}
