return {
	"mistweaverco/kulala.nvim",
	ft = { "http", "rest", "javascript", "lua" },
	keys = {
		{ "<leader>Rs", desc = "Send request" },
		{ "<leader>Ra", desc = "Send all requests" },
		{ "<leader>Rb", desc = "Open scratchpad" },
	},
	opts = {
		global_keymaps = true,
		global_keymaps_prefix = "<leader>R",
		kulala_keymaps_prefix = "",
		kulala_keymaps = {
			["Previous tab"] = {
				"<S-h>",
				function()
					require("kulala.ui").show_previous_tab()
				end,
				mode = { "n" },
			},
			["Next tab"] = {
				"<S-l>",
				function()
					require("kulala.ui").show_next_tab()
				end,
				mode = { "n" },
			},
		},
	},
}
