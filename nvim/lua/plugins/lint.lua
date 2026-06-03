return {
	"mfussenegger/nvim-lint",
	event = { "BufReadPost", "BufWritePost" },
	config = function()
		local lint = require("lint")
		lint.linters_by_ft = {
			sh = { "shellcheck" },
			bash = { "shellcheck" },
			dockerfile = { "hadolint" },
			yaml = { "yamllint" },
			markdown = { "markdownlint" },
		}

		local group = vim.api.nvim_create_augroup("Lint", { clear = true })
		vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost", "InsertLeave" }, {
			group = group,
			callback = function()
				lint.try_lint()
			end,
		})
	end,
}
