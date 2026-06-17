-- ~/.config/nvim/lua/config/options.lua
local opt = vim.opt
vim.g.clipboard = {
    name = 'pbcopy',
    copy = {
        ['+'] = 'pbcopy',
        ['*'] = 'pbcopy',
    },
    paste = {
        ['+'] = 'pbpaste',
        ['*'] = 'pbpaste',
    },
    cache_enabled = 0,
}
-- Line numbers
opt.number = true         -- absolute number on the current line
opt.relativenumber = true -- relative numbers on the rest; great with motions

-- Indentation
opt.expandtab = true -- spaces, not tabs
opt.tabstop = 4      -- a tab character renders as 4 spaces
opt.shiftwidth = 4   -- >> and << shift by 4
opt.softtabstop = 4  -- <Tab> in Insert inserts 4 spaces
opt.smartindent = true

-- Search
opt.ignorecase = true -- case-insensitive search...
opt.smartcase = true  -- ...unless the pattern has uppercase
opt.hlsearch = true   -- highlight matches
opt.incsearch = true  -- show matches as you type

-- UI
opt.termguicolors = true      -- 24-bit colour
opt.signcolumn = "yes"        -- always show the sign column; avoids text shifting
opt.cursorline = true         -- highlight the current line
opt.scrolloff = 8             -- keep 8 lines visible above/below cursor
opt.sidescrolloff = 8
opt.wrap = false              -- no soft wrap; horizontal scroll instead
opt.list = true               -- show whitespace markers
opt.listchars = { tab = "› ", trail = "·", nbsp = "␣" }
opt.fillchars = { eob = " " } -- hide ~ on empty lines
opt.cmdheight = 1
opt.showmode = false          -- statusline will tell us the mode
opt.laststatus = 3            -- one global statusline, not per-window

-- Files
opt.swapfile = false
opt.backup = false
opt.undofile = true  -- persistent undo across restarts
opt.undodir = vim.fn.stdpath("state") .. "/undo"
opt.updatetime = 250 -- faster CursorHold (diagnostics, gitsigns)
opt.timeoutlen = 400 -- which-key will feel snappier

-- Behaviour
opt.mouse = "a"               -- mouse works in all modes (yes really, useful for resizing splits)
opt.clipboard = "unnamedplus" -- yank and paste integrate with the OS clipboard
opt.splitright = true         -- :vsplit opens to the right
opt.splitbelow = true         -- :split opens below
opt.completeopt = { "menu", "menuone", "noselect" }
opt.confirm = true            -- ask before discarding unsaved changes

-- Folding (real values get set after Treesitter; defaults are fine for now)
opt.foldlevel = 99
opt.foldlevelstart = 99
opt.foldenable = true
