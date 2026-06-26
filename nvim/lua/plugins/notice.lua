return {
	"folke/noice.nvim",
	event = "VeryLazy",
	opts = {
		routes = {
			-- Drop malformed-RPC notifications. Some LSP servers occasionally
			-- send `vim.NIL` bodies; nvim surfaces these as RPC-level errors
			-- that pollute every save/cursor-move and none are actionable.
			{
				filter = {
					any = {
						{ event = "notify", find = "INVALID_SERVER_MESSAGE" },
						{ event = "msg_show", find = "INVALID_SERVER_MESSAGE" },
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
