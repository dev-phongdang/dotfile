return {
	"akinsho/toggleterm.nvim",
	version = "*",
	opts = {
		open_mapping = [[<c-\>]],
		direction = "float",
	},
	config = function(_, opts)
		require("toggleterm").setup(opts)

		local function set_terminal_keymaps()
			local map_opts = { buffer = 0 }
			vim.keymap.set("t", "<esc><esc>", [[<C-\><C-n>]], map_opts)
			vim.keymap.set("t", "jk", [[<C-\><C-n>]], map_opts)
		end

		vim.keymap.set("n", "<leader>tv", function()
			local width = math.floor(vim.o.columns * 0.4)
			require("toggleterm").toggle(2, width, nil, "vertical")
		end, { desc = "Toggle vertical terminal (40%)" })

		vim.api.nvim_create_autocmd("TermOpen", {
			pattern = "term://*toggleterm#*",
			callback = set_terminal_keymaps,
		})
	end,
}
