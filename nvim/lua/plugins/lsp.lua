return {
	"neovim/nvim-lspconfig",
	event = { "BufReadPre", "BufNewFile" },
	dependencies = {
		"mason-org/mason.nvim",
		"mason-org/mason-lspconfig.nvim",
		"Hoffs/omnisharp-extended-lsp.nvim",
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

				-- For OmniSharp, route gd/gi/gy/gr through omnisharp_extended
				-- so $metadata$ + source-generated URIs are materialised as
				-- read-only buffers before navigation. Stock vim.lsp.buf.*
				-- skips this resolution and shows "No location found".
				if client.name == "omnisharp" then
					local ext = require("omnisharp_extended")
					map("n", "gd", ext.lsp_definition, "Go to definition (omnisharp)")
					map("n", "gi", ext.lsp_implementation, "Implementation (omnisharp)")
					map("n", "gy", ext.lsp_type_definition, "Type definition (omnisharp)")
					map("n", "gr", ext.lsp_references, "References (omnisharp)")
				else
					map("n", "gd", vim.lsp.buf.definition, "Go to definition")
					map("n", "gi", vim.lsp.buf.implementation, "Implementation")
					map("n", "gy", vim.lsp.buf.type_definition, "Type definition")
					map("n", "gr", vim.lsp.buf.references, "References")
				end
				map("n", "gD", vim.lsp.buf.declaration, "Go to declaration")
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

				-- Document highlight.
				--
				-- OmniSharp's DocumentHighlight handler crashes with
				-- ArgumentOutOfRangeException when called on a buffer it
				-- hasn't fully synced — typically virtual $metadata$ buffers
				-- and during initial workspace load. We guard the autocmd
				-- so it only fires on real file:// buffers with content
				-- the server has acknowledged.
				if client:supports_method("textDocument/documentHighlight") then
					local group = vim.api.nvim_create_augroup("LspDocHighlight_" .. bufnr, { clear = true })
					vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
						buffer = bufnr,
						group = group,
						callback = function()
							-- Skip non-file buffers (metadata, scratch, etc).
							if vim.bo[0].buftype ~= "" then
								return
							end
							local name = vim.api.nvim_buf_get_name(0)
							if name == "" or name:match("^%w+://") then
								return
							end
							vim.lsp.buf.document_highlight()
						end,
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

		-- Filter OmniSharp's noisy InternalError responses at the LSP layer
		-- (NOT via vim.notify — noice.nvim owns that). OmniSharp throws
		-- ArgumentOutOfRangeException from a handful of handlers when the
		-- buffer it sees doesn't match what nvim asked about — typically
		-- DocumentHighlight, FindUsages, FoldingRange during mid-sync.
		-- We wrap each affected default handler so the specific known bug
		-- is swallowed and real errors still surface.
		local function silence_oor(method)
			local orig = vim.lsp.handlers[method]
			vim.lsp.handlers[method] = function(err, result, ctx, config)
				if err and err.code == -32603 and err.message and err.message:match("ArgumentOutOfRangeException") then
					return -- swallow OmniSharp's known sync bug
				end
				if orig then
					return orig(err, result, ctx, config)
				end
			end
		end
		silence_oor("textDocument/documentHighlight")
		silence_oor("textDocument/foldingRange")
		silence_oor("textDocument/codeAction")
		silence_oor("textDocument/references")

		-- Globally suppress noisy Roslyn/OmniSharp IDE analyzer diagnostics.
		-- omnisharp-roslyn does not honour `dotnet_diagnostic.<id>.severity =
		-- none` from .editorconfig for these IDE* code-style rules (confirmed:
		-- they keep surfacing at their default Hint severity after a cold
		-- restart), so we drop them client-side instead. Codes listed here
		-- never reach the diagnostic list, signs, or virtual text. IDE* codes
		-- are C#-only, so this is safe across all servers. Add `code = true`
		-- to disable one.
		--
		-- We wrap vim.diagnostic.set (not the publishDiagnostics handler)
		-- because nvim 0.11+ may receive these via *pull* diagnostics
		-- (textDocument/diagnostic), which bypass the push handler. Both push
		-- and pull paths funnel through vim.diagnostic.set, so this is the one
		-- chokepoint that catches every case.
		local suppressed_diagnostics = {
			["IDE0320"] = true, -- Make anonymous function static
		}
		local orig_set = vim.diagnostic.set
		---@diagnostic disable-next-line: duplicate-set-field
		vim.diagnostic.set = function(namespace, bufnr, diagnostics, opts)
			if diagnostics and #diagnostics > 0 then
				diagnostics = vim.tbl_filter(function(d)
					local code = d.code or (d.user_data and d.user_data.lsp and d.user_data.lsp.code)
					return not (code and suppressed_diagnostics[tostring(code)])
				end, diagnostics)
			end
			return orig_set(namespace, bufnr, diagnostics, opts)
		end

		-- ──────────────────────────────────────────────────────────────────────
		-- LSP progress → vim.notify
		--
		-- nvim 0.10+ surfaces every LSP `$/progress` notification as an
		-- `LspProgress` autocmd. OmniSharp is chatty during solution load
		-- (per-project parse, restore, analyzer setup), so we collapse
		-- per-client progress to a single rolling notification — replaced
		-- in place — and emit a one-shot toast when the workspace transitions
		-- to ready. Tokens distinguish concurrent operations.
		-- ──────────────────────────────────────────────────────────────────────
		local progress_state = {} -- [client_id][token] = { title, percent }
		local notify_handles = {} -- [client_id] = handle (for in-place replace)

		local function format_progress(client_id)
			local parts = {}
			for _, v in pairs(progress_state[client_id] or {}) do
				if v.percent then
					table.insert(parts, ("%s %d%%"):format(v.title, v.percent))
				else
					table.insert(parts, v.title)
				end
			end
			return table.concat(parts, " · ")
		end

		vim.api.nvim_create_autocmd("LspProgress", {
			group = vim.api.nvim_create_augroup("UserLspProgress", { clear = true }),
			callback = function(args)
				local client = vim.lsp.get_client_by_id(args.data.client_id)
				if not client then
					return
				end
				local token = args.data.params.token
				local value = args.data.params.value
				if not value then
					return
				end

				progress_state[client.id] = progress_state[client.id] or {}

				if value.kind == "begin" then
					progress_state[client.id][token] = {
						title = value.title or "working",
						percent = value.percentage,
					}
				elseif value.kind == "report" then
					if progress_state[client.id][token] then
						progress_state[client.id][token].percent = value.percentage
							or progress_state[client.id][token].percent
						if value.message then
							progress_state[client.id][token].title = value.message
						end
					end
				elseif value.kind == "end" then
					progress_state[client.id][token] = nil
				end

				local label = format_progress(client.id)
				if label == "" then
					-- All work done — emit a one-shot "ready" toast.
					if notify_handles[client.id] then
						notify_handles[client.id] = nil
						vim.notify(client.name .. ": ready", vim.log.levels.INFO, {
							title = "LSP",
							icon = "✓",
						})
					end
				else
					notify_handles[client.id] = vim.notify(label, vim.log.levels.INFO, {
						title = client.name,
						replace = notify_handles[client.id],
						hide_from_history = true,
						timeout = false, -- keep visible until "ready" replaces it
					})
				end
			end,
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
			-- OmniSharp. Decompilation + metadata navigation is enabled via
			-- ~/.omnisharp/omnisharp.json. The omnisharp_extended.* commands
			-- (wired in LspAttach above) handle $metadata$ URI resolution.
			omnisharp = {
				filetypes = { "cs" },
				root_markers = { "*.sln", "*.slnx", "*.csproj", ".git" },
				settings = {
					-- Surface the same settings via LSP for completeness;
					-- omnisharp.json takes precedence at runtime.
					["csharp"] = {
						format = { enable = true },
						semanticHighlighting = { enabled = true },
						symbolSearch = { includeReferenceAssemblies = true },
					},
				},
			},
		}
		for name, cfg in pairs(servers) do
			vim.lsp.config(name, cfg)
		end

		vim.lsp.enable(vim.tbl_keys(servers))
	end,
}
