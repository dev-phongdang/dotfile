return {
	"saghen/blink.cmp",
	event = { "InsertEnter", "CmdlineEnter" },
	version = "*", -- prebuilt binaries; rebuild with `build = 'cargo build --release'` if you prefer
	dependencies = {
		"rafamadriz/friendly-snippets",
		{
			"L3MON4D3/LuaSnip",
			version = "v2.*",
			build = "make install_jsregexp", -- optional, for some snippet regex features
			config = function()
				require("luasnip.loaders.from_vscode").lazy_load()
			end,
		},
	},
	opts = {
		keymap = {
			preset = "enter", -- <CR> accepts, <Tab> expands snippet, <C-Space> opens menu
			["<Tab>"] = { "accept", "snippet_forward", "fallback" }, -- <Tab> also accepts the selection
			["<C-j>"] = { "select_next", "fallback" },
			["<C-k>"] = { "select_prev", "fallback" },
			["<C-d>"] = { "scroll_documentation_down", "fallback" },
			["<C-u>"] = { "scroll_documentation_up", "fallback" },
			["<C-e>"] = { "hide", "fallback" },
		},
		appearance = {
			use_nvim_cmp_as_default = true,
			nerd_font_variant = "mono",
		},
		completion = {
			accept = { auto_brackets = { enabled = true } }, -- function() inserts ()
			menu = {
				border = "rounded",
				draw = { treesitter = { "lsp" } }, -- syntax-highlight the suggestions
			},
			documentation = {
				auto_show = true,
				auto_show_delay_ms = 250,
				window = { border = "rounded" },
			},
			list = { selection = { preselect = false, auto_insert = false } },
			ghost_text = { enabled = true }, -- inline preview of the suggestion
		},
		sources = {
			default = { "lsp", "path", "snippets", "buffer" },
			providers = {
				snippets = { score_offset = -2 }, -- LSP suggestions beat snippets
			},
		},
		snippets = { preset = "luasnip" },
		signature = { enabled = true }, -- inline signature help
	},
	opts_extend = { "sources.default" },
}
