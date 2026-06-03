-- ~/.config/nvim/lua/config/autocmds.lua
local au = vim.api.nvim_create_autocmd
local group = vim.api.nvim_create_augroup

-- Briefly highlight yanked text
au("TextYankPost", {
	group = group("YankHighlight", { clear = true }),
	callback = function()
		vim.highlight.on_yank({ timeout = 200 })
	end,
})

-- Strip trailing whitespace on save (skip filetypes where it matters)
au("BufWritePre", {
	group = group("TrimWhitespace", { clear = true }),
	callback = function()
		local ft = vim.bo.filetype
		if ft == "markdown" or ft == "diff" then
			return
		end
		local view = vim.fn.winsaveview()
		vim.cmd([[%s/\s\+$//e]])
		vim.fn.winrestview(view)
	end,
})

-- Restore cursor to last edit position on file open
au("BufReadPost", {
	group = group("LastLocation", { clear = true }),
	callback = function(args)
		local mark = vim.api.nvim_buf_get_mark(args.buf, [["]])
		local line_count = vim.api.nvim_buf_line_count(args.buf)
		if mark[1] > 0 and mark[1] <= line_count then
			pcall(vim.api.nvim_win_set_cursor, 0, mark)
		end
	end,
})

-- Filetype-specific indentation: Go uses real tabs
au("FileType", {
	pattern = { "go", "gomod" },
	callback = function()
		vim.bo.expandtab = false
		vim.bo.tabstop = 4
		vim.bo.shiftwidth = 4
	end,
})

-- Python keeps 4 spaces (already the default, just being explicit)
au("FileType", {
	pattern = "python",
	callback = function()
		vim.bo.expandtab = true
		vim.bo.tabstop = 4
		vim.bo.shiftwidth = 4
		vim.bo.textwidth = 88 -- ruff/black default
	end,
})
-- Markdown wrap a Visual selection in backticks
au("FileType", {
	pattern = "markdown",
	callback = function(args)
		vim.keymap.set(
			"x",
			"<leader>mp",
			[[c`<C-r>"`<Esc>]],
			{ buffer = args.buf, desc = "Wrap selection in backticks" }
		)
	end,
})

au("CursorHold", {
	group = group("LspDiagnosticsHover", { clear = true }),
	callback = function()
		local ok, _ = pcall(vim.diagnostic.open_float, nil, {
			focusable = false,
			close_events = { "BufLeave", "CursorMoved", "InsertEnter", "FocusLost" },
			border = "rounded",
			source = "if_many",
			prefix = " ",
			scope = "cursor",
		})
		-- ignore failures (e.g. when no diagnostics at cursor)
	end,
})
