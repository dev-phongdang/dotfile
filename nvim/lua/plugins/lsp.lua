return {
	"neovim/nvim-lspconfig",
	event = { "BufReadPre", "BufNewFile" },
	dependencies = {
		"mason-org/mason.nvim",
		"mason-org/mason-lspconfig.nvim",
	},
	config = function()
		-- Diagnostics UI (signs now live inside diagnostic.config, not sign_define)
		vim.diagnostic.config({
			virtual_text = { spacing = 2, prefix = "●" },
			underline = true,
			update_in_insert = false,
			severity_sort = true,
			float = { border = "rounded", source = "if_many" },
			signs = {
				text = {
					[vim.diagnostic.severity.ERROR] = " ",
					[vim.diagnostic.severity.WARN] = " ",
					[vim.diagnostic.severity.HINT] = " ",
					[vim.diagnostic.severity.INFO] = " ",
				},
			},
		})

		-- One LspAttach autocmd replaces the per-server on_attach.
		vim.api.nvim_create_autocmd("LspAttach", {
			group = vim.api.nvim_create_augroup("UserLspAttach", { clear = true }),
			callback = function(args)
				local bufnr = args.buf
				local client = vim.lsp.get_client_by_id(args.data.client_id)
				if not client then
					return
				end

				local map = function(mode, lhs, rhs, desc)
					vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc, silent = true })
				end

				map("n", "gd", vim.lsp.buf.definition, "Go to definition")
				map("n", "gD", vim.lsp.buf.declaration, "Go to declaration")
				map("n", "gr", vim.lsp.buf.references, "References")
				map("n", "gi", vim.lsp.buf.implementation, "Implementation")
				map("n", "gy", vim.lsp.buf.type_definition, "Type definition")
				map("n", "K", vim.lsp.buf.hover, "Hover docs")
				map("n", "<C-k>", vim.lsp.buf.signature_help, "Signature help")
				map("i", "<C-k>", vim.lsp.buf.signature_help, "Signature help")
				map("n", "<leader>rn", vim.lsp.buf.rename, "Rename symbol")
				map({ "n", "x" }, "<leader>ca", vim.lsp.buf.code_action, "Code action")

				map("n", "<leader>ld", vim.diagnostic.open_float, "Line diagnostics")
				map("n", "[d", function()
					vim.diagnostic.jump({ count = -1, float = true })
				end, "Prev diagnostic")
				map("n", "]d", function()
					vim.diagnostic.jump({ count = 1, float = true })
				end, "Next diagnostic")

				-- ruff: let basedpyright own hover/defs
				if client.name == "ruff" then
					client.server_capabilities.hoverProvider = false
				end

				-- Inlay hints
				if client:supports_method("textDocument/inlayHint") then
					vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
					map("n", "<leader>lh", function()
						vim.lsp.inlay_hint.enable(
							not vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr }),
							{ bufnr = bufnr }
						)
					end, "Toggle inlay hints")
				end

				-- Document highlight
				if client:supports_method("textDocument/documentHighlight") then
					local group = vim.api.nvim_create_augroup("LspDocHighlight_" .. bufnr, { clear = true })
					vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
						buffer = bufnr,
						group = group,
						callback = vim.lsp.buf.document_highlight,
					})
					vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
						buffer = bufnr,
						group = group,
						callback = vim.lsp.buf.clear_references,
					})
				end
			end,
		})

		-- Capabilities once, globally, for every server.
		vim.lsp.config("*", {
			capabilities = require("blink.cmp").get_lsp_capabilities(),
		})

		-- Per-server overrides. These deep-merge over nvim-lspconfig's shipped
		-- defaults (cmd, root markers, filetypes) and over the '*' config above.
		local servers = {
			gopls = {
				settings = {
					gopls = {
						usePlaceholders = true,
						completeUnimported = true,
						staticcheck = true,
						gofumpt = true,
						hints = {
							assignVariableTypes = true,
							compositeLiteralFields = true,
							compositeLiteralTypes = true,
							constantValues = true,
							functionTypeParameters = true,
							parameterNames = true,
							rangeVariableTypes = true,
						},
						analyses = {
							unusedparams = true,
							shadow = true,
							fieldalignment = true,
							nilness = true,
							useany = true,
						},
						codelenses = {
							gc_details = true,
							generate = true,
							test = true,
							tidy = true,
							upgrade_dependency = true,
							vendor = true,
						},
					},
				},
			},
			basedpyright = {
				settings = {
					basedpyright = {
						analysis = {
							autoSearchPaths = true,
							useLibraryCodeForTypes = true,
							diagnosticMode = "workspace",
							inlayHints = {
								variableTypes = true,
								functionReturnTypes = true,
								callArgumentNames = true,
							},
							typeCheckingMode = "standard",
						},
					},
				},
			},
			ruff = {},
			lua_ls = {
				settings = {
					Lua = {
						workspace = { checkThirdParty = false },
						diagnostics = { globals = { "vim" } },
						telemetry = { enable = false },
						hint = { enable = true },
					},
				},
			},
			csharp_ls = {
				filetypes = { "cs" },
				root_markers = { "*.sln", "*.slnx", "*.csproj", ".git" },
				init_options = { AutomaticWorkspaceInit = true },
			},
		}
		for name, cfg in pairs(servers) do
			vim.lsp.config(name, cfg)
		end

		vim.lsp.enable(vim.tbl_keys(servers))
	end,
}

