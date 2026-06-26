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

				-- Navigation. roslyn.nvim materialises decompiled/metadata and
				-- source-generated targets through standard LSP, so the stock
				-- handlers resolve C# definitions too — no per-server routing.
				map("n", "gd", vim.lsp.buf.definition, "Go to definition")
				map("n", "gi", vim.lsp.buf.implementation, "Implementation")
				map("n", "gy", vim.lsp.buf.type_definition, "Type definition")
				map("n", "gr", vim.lsp.buf.references, "References")
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

				-- roslyn: re-pick the target solution for this buffer. Use when a
				-- .cs file lands in the canonical miscellaneous-files project
				-- (stuck "Restoring Canonical.csproj") so it binds to the right .sln.
				if client.name == "roslyn" then
					map("n", "<leader>lR", "<cmd>Roslyn target<cr>", "Roslyn: target solution")
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

				-- Document highlight. Guarded to fire only on real file://
				-- buffers, skipping decompiled/metadata and source-generated
				-- buffers (custom URI schemes), where highlighting content the
				-- server has not yet acknowledged is wasteful at best.
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

		-- Globally suppress noisy Roslyn IDE analyzer diagnostics. These IDE*
		-- code-style rules keep surfacing at their default Hint severity even
		-- when silenced via .editorconfig, so we drop them client-side instead.
		-- Codes listed here never reach the diagnostic list, signs, or virtual
		-- text. IDE* codes are C#-only, so this is safe across all servers. Add
		-- `code = true` to disable one.
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
		-- `LspProgress` autocmd. Roslyn is chatty during solution load
		-- (per-project parse, restore, analyzer setup), so we collapse
		-- per-client progress to a single rolling notification — replaced
		-- in place — and emit a one-shot toast when the workspace transitions
		-- to ready. Tokens distinguish concurrent operations.
		-- ──────────────────────────────────────────────────────────────────────
		local progress_state = {} -- [client_id][token] = { title, percent, updated }
		local notify_handles = {} -- [client_id] = handle (for in-place replace)
		-- Safety net: a token that begins/reports but never sends `end` would
		-- otherwise pin its toast forever. Roslyn does exactly this for its
		-- internal "Restoring Canonical.csproj" miscellaneous-files project (a
		-- synthetic ~/T/roslyn-canonical-misc project it spins up for .cs files
		-- not covered by the loaded solution, then tries to restore and never
		-- finishes — dotnet/roslyn#82999). Evict any token idle past this.
		local PROGRESS_STALE_MS = 8000

		local function format_progress(client_id)
			local now = vim.uv.now()
			local parts = {}
			for token, v in pairs(progress_state[client_id] or {}) do
				if now - (v.updated or 0) > PROGRESS_STALE_MS then
					progress_state[client_id][token] = nil -- orphaned/stuck; drop it
				elseif v.percent then
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
				-- This toast pipeline exists only to tame Roslyn's chatty
				-- solution-load progress. Every other server (basedpyright in
				-- workspace mode especially) re-emits begin→end cycles
				-- constantly, which spammed a "ready" toast per cycle. Let
				-- noice render their progress in its quiet mini-view instead.
				if client.name ~= "roslyn" then
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
						updated = vim.uv.now(),
					}
				elseif value.kind == "report" then
					if progress_state[client.id][token] then
						progress_state[client.id][token].percent = value.percentage
							or progress_state[client.id][token].percent
						if value.message then
							progress_state[client.id][token].title = value.message
						end
						progress_state[client.id][token].updated = vim.uv.now()
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
						-- Auto-dismiss if reports stop; active progress keeps
						-- replacing this in place, so it stays during real work
						-- but never pins on a stalled token.
						timeout = PROGRESS_STALE_MS,
					})
				end
			end,
		})

		-- C# / Roslyn. The roslyn.nvim plugin (lua/plugins/roslyn.lua) owns
		-- solution/target detection and enables the "roslyn" client itself, so
		-- it is configured here but deliberately kept OUT of the `servers` table
		-- + vim.lsp.enable() below: enabling it twice would spawn a second,
		-- mis-targeted client. Settings use Roslyn's `csharp|*` namespaced keys
		-- (the same options the VS Code C# extension exposes).
		vim.lsp.config("roslyn", {
			settings = {
				["csharp|background_analysis"] = {
					dotnet_analyzer_diagnostics_scope = "fullSolution",
					dotnet_compiler_diagnostics_scope = "fullSolution",
				},
				["csharp|inlay_hints"] = {
					csharp_enable_inlay_hints_for_implicit_object_creation = true,
					csharp_enable_inlay_hints_for_implicit_variable_types = true,
					csharp_enable_inlay_hints_for_lambda_parameter_types = true,
					csharp_enable_inlay_hints_for_types = true,
					dotnet_enable_inlay_hints_for_indexer_parameters = true,
					dotnet_enable_inlay_hints_for_literal_parameters = true,
					dotnet_enable_inlay_hints_for_object_creation_parameters = true,
					dotnet_enable_inlay_hints_for_other_parameters = true,
					dotnet_enable_inlay_hints_for_parameters = true,
				},
				["csharp|code_lens"] = {
					dotnet_enable_references_code_lens = true,
				},
				["csharp|completion"] = {
					dotnet_show_completion_items_from_unimported_namespaces = true,
					dotnet_show_name_completion_suggestions = true,
				},
				["csharp|symbol_search"] = {
					dotnet_search_reference_assemblies = true,
				},
				-- Go-to-definition into external assemblies. The VS Code C#
				-- extension defaults these to true *client-side* and pushes them
				-- to the server; a bare LSP client like nvim must send them
				-- explicitly or the server returns no location for metadata
				-- symbols (no decompiled buffer to jump to).
				["csharp|navigation"] = {
					dotnet_navigate_to_decompiled_sources = true,
					dotnet_navigate_to_source_link_and_embedded_sources = true,
				},
				["csharp|formatting"] = {
					dotnet_organize_imports_on_format = true,
				},
			},
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
		}
		for name, cfg in pairs(servers) do
			vim.lsp.config(name, cfg)
		end

		vim.lsp.enable(vim.tbl_keys(servers))
	end,
}
