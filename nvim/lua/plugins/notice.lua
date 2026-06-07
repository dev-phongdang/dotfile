return {
	"folke/noice.nvim",
	event = "VeryLazy",
	opts = {
		routes = {
			-- Suppress known-noise LSP errors from OmniSharp. The server has
			-- a few cases where it sends malformed RPC bodies (`vim.NIL`)
			-- or throws ArgumentOutOfRangeException during sync mismatches.
			-- nvim reports both as RPC-level errors that pollute every
			-- save/cursor-move. None are actionable.
			{
				filter = {
					any = {
						{ event = "notify", find = "INVALID_SERVER_MESSAGE" },
						{ event = "notify", find = "omnisharp.-ArgumentOutOfRangeException" },
						{ event = "notify", find = "omnisharp.-Internal Error" },
						{ event = "msg_show", find = "INVALID_SERVER_MESSAGE" },
						{ event = "msg_show", find = "omnisharp.-ArgumentOutOfRangeException" },
					},
				},
				opts = { skip = true },
			},
		},
	},
	dependencies = {
		"MunifTanjim/nui.nvim",
		"rcarriga/nvim-notify",
	},
}
