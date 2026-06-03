-- ~/.config/nvim/lua/config/keymaps.lua
local map = vim.keymap.set

-- Smarter j/k: respect wrapped lines but treat counts as absolute
map({ "n", "x" }, "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })
map({ "n", "x" }, "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })

-- Save / quit shortcuts
map("n", "<leader>w", "<cmd>write<cr>", { desc = "Write file" })
map("n", "<leader>q", "<cmd>quit<cr>", { desc = "Quit window" })

-- Clear search highlight with <Esc>
map("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "Clear hlsearch" })

-- Better up/down when wrapping is on (kept for parity with first two lines)
-- Window navigation
map("n", "<C-h>", "<C-w>h", { desc = "Go to left window" })
map("n", "<C-j>", "<C-w>j", { desc = "Go to lower window" })
map("n", "<C-k>", "<C-w>k", { desc = "Go to upper window" })
map("n", "<C-l>", "<C-w>l", { desc = "Go to right window" })

-- Resize windows with arrows (yes, the one good use of arrow keys)
map("n", "<C-Up>", "<cmd>resize +2<cr>", { desc = "Increase height" })
map("n", "<C-Down>", "<cmd>resize -2<cr>", { desc = "Decrease height" })
map("n", "<C-Left>", "<cmd>vertical resize -2<cr>", { desc = "Decrease width" })
map("n", "<C-Right>", "<cmd>vertical resize +2<cr>", { desc = "Increase width" })

-- Buffer navigation
map("n", "<S-h>", "<cmd>bprevious<cr>", { desc = "Previous buffer" })
map("n", "<S-l>", "<cmd>bnext<cr>", { desc = "Next buffer" })
map("n", "<leader>bd", "<cmd>bdelete<cr>", { desc = "Delete buffer" })

-- Stay centered when scrolling
map("n", "<C-d>", "<C-d>zz")
map("n", "<C-u>", "<C-u>zz")
map("n", "n", "nzzzv")
map("n", "N", "Nzzzv")

-- Better indenting in Visual mode (keep selection after >/<)
map("x", "<", "<gv")
map("x", ">", ">gv")

-- Move selected lines up/down (Visual mode)
map("x", "J", ":move '>+1<cr>gv=gv", { desc = "Move selection down" })
map("x", "K", ":move '<-2<cr>gv=gv", { desc = "Move selection up" })

-- Paste over selection without losing the yank register
map("x", "p", [["_dP]], { desc = "Paste without clobbering register" })

-- Delete to the black hole register with <leader>d
map({ "n", "x" }, "<leader>d", [["_d]], { desc = "Delete without yanking" })

-- Quick split openers
map("n", "<leader>sv", "<C-w>v", { desc = "Vertical split" })
map("n", "<leader>sh", "<C-w>s", { desc = "Horizontal split" })
map("n", "<leader>se", "<C-w>=", { desc = "Equal width" })
map("n", "<leader>sx", "<cmd>close<cr>", { desc = "Close split" })
-- Custom opera
map("n", "<leader>oo", "o<Esc>", { desc = "Open blank line bellow (stay in normal)" })
