-- ~/.config/nvim/init.lua
-- Set leader BEFORE loading plugins; many plugins read it at setup time.
vim.g.mapleader = " "
vim.g.maplocalleader = ","

require("config.options")
require("config.keymaps")
require("config.autocmds")
require("config.lazy")

-- require('config.lazy')   -- uncomment in session 5
