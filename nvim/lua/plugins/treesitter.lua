return {
	{
		"nvim-treesitter/nvim-treesitter",
		branch = "main",
		build = ":TSUpdate",
		event = { "BufReadPost", "BufNewFile" },
		dependencies = {
			{ "nvim-treesitter/nvim-treesitter-textobjects", branch = "main" },
		},
		config = function()
			local ts = require("nvim-treesitter")

			-- Install parsers if missing
			local ensure_installed = {
				"bash",
				"c",
				"lua",
				"vim",
				"vimdoc",
				"query",
				"markdown",
				"markdown_inline",
				"regex",
				"json",
				"yaml",
				"toml",
				"html",
				"go",
				"gomod",
				"gosum",
				"gowork",
				"python",
				"c_sharp",
				"dockerfile",
				"sql",
			}
			local installed = require("nvim-treesitter.config").get_installed()
			local to_install = vim.iter(ensure_installed)
				:filter(function(p)
					return not vim.tbl_contains(installed, p)
				end)
				:totable()
			if #to_install > 0 then
				ts.install(to_install)
			end

			-- Enable highlighting + indentation via autocmd (new API)
			vim.api.nvim_create_autocmd("FileType", {
				callback = function()
					pcall(vim.treesitter.start)
					vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
				end,
			})

			-- Incremental selection
			require("nvim-treesitter-textobjects").setup({
				select = {
					enable = true,
					lookahead = true,
					keymaps = {
						["af"] = "@function.outer",
						["if"] = "@function.inner",
						["ac"] = "@class.outer",
						["ic"] = "@class.inner",
						["aa"] = "@parameter.outer",
						["ia"] = "@parameter.inner",
						["ai"] = "@conditional.outer",
						["ii"] = "@conditional.inner",
						["al"] = "@loop.outer",
						["il"] = "@loop.inner",
					},
				},
				move = {
					enable = true,
					set_jumps = true,
					goto_next_start = { ["]f"] = "@function.outer", ["]c"] = "@class.outer" },
					goto_next_end = { ["]F"] = "@function.outer", ["]C"] = "@class.outer" },
					goto_previous_start = { ["[f"] = "@function.outer", ["[c"] = "@class.outer" },
					goto_previous_end = { ["[F"] = "@function.outer", ["[C"] = "@class.outer" },
				},
			})

			-- Tree-sitter-driven folds
			vim.opt.foldmethod = "expr"
			vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
		end,
	},
}
