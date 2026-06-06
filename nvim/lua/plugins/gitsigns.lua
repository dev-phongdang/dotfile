return {
	"lewis6991/gitsigns.nvim",
	event = { "BufReadPre", "BufNewFile" },
	opts = {
		signs = {
			add = { text = "┃" },
			change = { text = "┃" },
			delete = { text = "_" },
			topdelete = { text = "‾" },
			changedelete = { text = "~" },
			untracked = { text = "┆" },
		},
		current_line_blame = false, -- toggle below with <leader>gB
		current_line_blame_opts = { delay = 600, virt_text_pos = "eol" },
		preview_config = { border = "rounded" },
		on_attach = function(bufnr)
			local gs = package.loaded.gitsigns
			local map = function(mode, lhs, rhs, desc)
				vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc, silent = true })
			end

			-- Navigation between hunks
			map("n", "]c", function()
				if vim.wo.diff then
					return "]c"
				end
				vim.schedule(gs.next_hunk)
				return "<Ignore>"
			end, "Next hunk")
			map("n", "[c", function()
				if vim.wo.diff then
					return "[c"
				end
				vim.schedule(gs.prev_hunk)
				return "<Ignore>"
			end, "Prev hunk")

			-- Actions
			map("n", "<leader>gs", gs.stage_hunk, "Stage hunk")
			map("n", "<leader>gr", gs.reset_hunk, "Reset hunk")
			map("v", "<leader>gs", function()
				gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
			end, "Stage selected")
			map("v", "<leader>gr", function()
				gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
			end, "Reset selected")
			map("n", "<leader>gS", gs.stage_buffer, "Stage buffer")
			map("n", "<leader>gR", gs.reset_buffer, "Reset buffer")
			map("n", "<leader>gu", gs.undo_stage_hunk, "Undo stage hunk")
			map("n", "<leader>gp", gs.preview_hunk, "Preview hunk")
			map("n", "<leader>gb", function()
				gs.blame_line({ full = true })
			end, "Blame line")
			map("n", "<leader>gB", gs.toggle_current_line_blame, "Toggle line blame")
			map("n", "<leader>gd", gs.diffthis, "Diff against index")
			map("n", "<leader>gD", function()
				gs.diffthis("~")
			end, "Diff against last commit")

			-- Text object for a hunk
			map({ "o", "x" }, "ih", ":<C-u>Gitsigns select_hunk<cr>", "Inner hunk")
		end,
	},
}
