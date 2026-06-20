-- conform hides the real formatter error behind a generic
-- "See :ConformInfo for details" message for execution errors (e.g. jq
-- choking on invalid JSON). The full message (including the formatter's
-- stderr) is still handed to the format() callback, so surface it directly.
local function notify_format_error(err)
	if err then
		vim.notify(err, vim.log.levels.ERROR, { title = "Conform" })
	end
end

return {
	"stevearc/conform.nvim",
	event = { "BufWritePre" },
	cmd = { "ConformInfo" },
	keys = {
		{
			"<leader>cf",
			function()
				require("conform").format({ async = true, lsp_fallback = true }, notify_format_error)
			end,
			mode = { "n", "x" },
			desc = "Format",
		},
	},
	opts = {
		-- Don't show the generic notification; our callbacks surface the
		-- actual error message instead.
		notify_on_error = false,
		formatters_by_ft = {
			go = { "goimports", "gofumpt" },
			python = { "ruff_format", "ruff_organize_imports" },
			lua = { "stylua" },
			sh = { "shfmt" },
			bash = { "shfmt" },
			yaml = { "yamlfmt" },
			json = { "jq" },
			markdown = { "prettier" },
			cs = { "csharpier" },
			http = { "kulala" },
		},
		format_on_save = function(bufnr)
			-- Disable autosave-format for huge files
			if vim.api.nvim_buf_line_count(bufnr) > 5000 then
				return
			end
			return { timeout_ms = 1500, lsp_fallback = true }, notify_format_error
		end,
		formatters = {
			shfmt = { prepend_args = { "-i", "2", "-bn", "-ci" } },
			kulala = {
				command = "kulala-fmt",
				args = { "format", "$FILENAME" },
				stdin = false,
			},
		},
	},
	init = function()
		-- Use conform.formatexpr for `gq` motion
		vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
	end,
}
