return {
  'williamboman/mason.nvim',
  cmd = { 'Mason', 'MasonInstall', 'MasonUninstall', 'MasonUpdate' },
  build = ':MasonUpdate',
  opts = {
    ui = {
      icons = { package_installed = '✓', package_pending = '➜', package_uninstalled = '✗' },
    },
  },
}
