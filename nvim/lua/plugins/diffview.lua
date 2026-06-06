return {
	"sindrets/diffview.nvim",
	cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewFileHistory" },
	keys = {
		{ "<leader>gv", "<cmd>DiffviewOpen<cr>", desc = "Diffview: working tree vs HEAD" },
		{ "<leader>gV", "<cmd>DiffviewClose<cr>", desc = "Diffview: close" },
		{ "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", desc = "Diffview: file history" },
		{ "<leader>gH", "<cmd>DiffviewFileHistory<cr>", desc = "Diffview: repo history" },
	},
	opts = {
		enhanced_diff_hl = true,
		view = { default = { winbar_info = true } },
	},
}
