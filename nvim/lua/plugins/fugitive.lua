return {
	"tpope/vim-fugitive",
	cmd = { "Git", "G" },
	keys = {
		{ "<leader>gg", "<cmd>Git<cr>", desc = "Git status (fugitive)" },
		{ "<leader>gc", "<cmd>Git commit<cr>", desc = "Git commit" },
		{ "<leader>gP", "<cmd>Git push<cr>", desc = "Git push" },
		{ "<leader>gF", "<cmd>Git pull --rebase<cr>", desc = "Git pull --rebase" },
		{ "<leader>gl", "<cmd>Git log --oneline --decorate --graph<cr>", desc = "Git log" },
	},
}
