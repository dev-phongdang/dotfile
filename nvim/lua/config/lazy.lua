local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
	vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"https://github.com/folke/lazy.nvim.git",
		"--branch=stable",
		lazypath,
	})
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
	spec = {
		{ import = "plugins" }, -- import every file under lua/plugins/
	},
	install = { colorscheme = { "kanagawa", "tokyonight", "habamax" } },
	checker = { enabled = true, notify = false }, -- silently check for updates
	change_detection = { notify = false },
})
