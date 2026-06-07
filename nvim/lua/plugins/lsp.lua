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

		-- ──────────────────────────────────────────────────────────────────────
		-- csharp_ls metadata / decompilation support
		--
		-- csharp-language-server >=0.24 returns `csharp:` URIs for external
		-- symbols when `useMetadataUris=true`. URI format:
		--   csharp:/<absolute-path-to-csproj>/decompiled/<symbolMetadataName>.cs
		--
		-- Hook via a BufReadCmd autocmd: when nvim is asked to open a
		-- csharp:* path, we send `csharp/metadata` to the server and stream
		-- the decompiled source into the buffer. The standard
		-- vim.lsp.buf.definition -> show_document -> bufload chain then
		-- fires the cmd automatically.
		--
		-- Known upstream bug (razzmatazz/csharp-language-server#319): the
		-- *second* gd into a NuGet symbol after metadata has been fetched
		-- returns an empty array. Run :CsharpReset to restart the server
		-- and wipe cached buffers.
		-- ──────────────────────────────────────────────────────────────────────

		local function get_csharp_client()
			for _, c in pairs(vim.lsp.get_clients({ name = "csharp_ls" })) do
				return c
			end
		end

		-- Workaround for csharp-ls v0.24 URI-parser bug:
		-- the metadata handler does `TrimEnd(['.', 'c', 's'])` on the symbol
		-- name, which over-eats trailing chars in that set. Types like
		-- `ApiConstants`, `Options`, `Settings` get truncated to
		-- `ApiConstant`/`Option`/`Setting` and the symbol lookup returns null
		-- (empty response, no decompilation).
		--
		-- Fix: double-URL-encode trailing chars in the trim set. After the
		-- server's one-pass LocalPath decode, the escapes survive (e.g. `s`
		-- → `%2573` → `%73`), TrimEnd stops at the `3`, and the final
		-- UnescapeDataString turns it back into `s`.
		local function patch_csharp_uri(uri)
			local marker = "/decompiled/"
			local idx = uri:find(marker, 1, true)
			if not idx then
				return uri
			end

			local prefix = uri:sub(1, idx + #marker - 1)
			local rest = uri:sub(idx + #marker)

			local suffix = ""
			if rest:sub(-3) == ".cs" then
				suffix = ".cs"
				rest = rest:sub(1, -4)
			end

			local trim_set = { ["."] = true, ["c"] = true, ["s"] = true }
			local encoded = ""
			while #rest > 0 do
				local last = rest:sub(-1)
				if trim_set[last] then
					encoded = string.format("%%25%02X", string.byte(last)) .. encoded
					rest = rest:sub(1, -2)
				else
					break
				end
			end

			return prefix .. rest .. encoded .. suffix
		end

		-- Synchronously fetch decompiled source for a csharp: URI and dump it
		-- into the buffer that nvim just opened for that URI.
		local function csharp_buf_read(args)
			local bufnr = args.buf
			local uri = args.file
			local client = get_csharp_client()
			if not client then
				vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "// csharp_ls not attached" })
				return
			end

			local request_uri = patch_csharp_uri(uri)
			local res, err = client:request_sync("csharp/metadata", {
				textDocument = { uri = request_uri },
			}, 10000, 0)

			if err then
				local msg = "// csharp/metadata err: " .. vim.inspect(err)
				vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(msg, "\n"))
				return
			end

			local meta = res and res.result
			if not meta or not meta.source then
				local msg = "// csharp/metadata returned no source.\n"
					.. "// If this is the *second* gd into a NuGet symbol, csharp-ls\n"
					.. "// v0.24 has lost its workspace state (upstream bug #319).\n"
					.. "// Run :CsharpReset to restart the server."
				vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(msg, "\n"))
				return
			end

			local source = (meta.source):gsub("\r\n", "\n")
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(source, "\n", { plain = true }))
			vim.bo[bufnr].filetype = "cs"
			vim.bo[bufnr].buftype = "nofile"
			vim.bo[bufnr].swapfile = false
			vim.bo[bufnr].modifiable = false
			vim.bo[bufnr].readonly = true

			-- NOTE: do NOT attach the LSP client to this buffer. Sending
			-- didOpen with the virtual csharp: URI corrupts csharp-ls's
			-- document tracking. Bind gd/gD to Vim's built-in word search
			-- for in-buffer navigation instead.
			vim.keymap.set("n", "gd", function()
				vim.cmd("normal! gd")
			end, { buffer = bufnr, desc = "Go to declaration (in-buffer)", silent = true })
			vim.keymap.set("n", "gD", function()
				vim.cmd("normal! gD")
			end, { buffer = bufnr, desc = "Go to declaration global (in-buffer)", silent = true })

			-- csharp-ls returns range {0,0,0,0} for decompiled-file
			-- definitions, so show_document leaves the cursor at line 1.
			-- We use the cword captured at the originating gd keymap to
			-- jump to the right member, falling back to the type decl.
			local sym_idx = uri:find("/decompiled/", 1, true)
			if not sym_idx then
				return
			end
			local sym_path = uri:sub(sym_idx + #"/decompiled/"):gsub("%.cs$", "")
			sym_path = sym_path:gsub("%%(%x%x)", function(h)
				return string.char(tonumber(h, 16))
			end)
			local class_simple = (sym_path:match("([^.]+)$") or sym_path):gsub("`%d+$", "")
			local user_word = vim.g.csharp_ls_jump_word
			vim.g.csharp_ls_jump_word = nil

			vim.defer_fn(function()
				if not vim.api.nvim_buf_is_valid(bufnr) then
					return
				end
				local target_win
				for _, w in ipairs(vim.api.nvim_list_wins()) do
					if vim.api.nvim_win_get_buf(w) == bufnr then
						target_win = w
						break
					end
				end
				if not target_win then
					return
				end
				local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

				-- 1st pass: the exact symbol the user pressed gd on.
				if user_word and user_word ~= "" and user_word ~= class_simple then
					local esc = vim.pesc(user_word)
					for i, line in ipairs(lines) do
						local col = line:find("%f[%w_]" .. esc .. "%f[^%w_]")
						if col then
							pcall(vim.api.nvim_win_set_cursor, target_win, { i, col - 1 })
							return
						end
					end
				end

				-- 2nd pass: the containing type declaration.
				local keywords = { "class", "interface", "struct", "enum", "record", "delegate" }
				local esc = vim.pesc(class_simple)
				for i, line in ipairs(lines) do
					for _, kw in ipairs(keywords) do
						if line:find("%f[%w]" .. kw .. "%s+" .. esc .. "%f[^%w_]") then
							local col = (line:find(class_simple, 1, true) or 1) - 1
							pcall(vim.api.nvim_win_set_cursor, target_win, { i, col })
							return
						end
					end
				end
			end, 30)
		end

		vim.api.nvim_create_autocmd("BufReadCmd", {
			group = vim.api.nvim_create_augroup("CSharpMetadataRead", { clear = true }),
			pattern = { "csharp:/*", "csharp:*" },
			callback = csharp_buf_read,
		})

		-- :CsharpReset — workaround for csharp-language-server#319.
		-- The first csharp/metadata call mutates wf state in a way that breaks
		-- subsequent textDocument/definition. nvim's `:LspRestart` can be too
		-- gentle (reuses the process in some flows), so this does a hard kill
		-- + respawn, and re-attaches the client to every loaded .cs buffer.
		vim.api.nvim_create_user_command("CsharpReset", function()
			-- 1. Wipe all virtual decompiled buffers.
			for _, b in ipairs(vim.api.nvim_list_bufs()) do
				if vim.api.nvim_buf_is_valid(b) and vim.api.nvim_buf_get_name(b):match("^csharp:") then
					pcall(vim.api.nvim_buf_delete, b, { force = true })
				end
			end

			-- 2. Force-stop every csharp_ls client, killing the process.
			local clients = vim.lsp.get_clients({ name = "csharp_ls" })
			local pids = {}
			for _, c in ipairs(clients) do
				if c.rpc and c.rpc.pid then
					table.insert(pids, c.rpc.pid)
				end
				vim.lsp.stop_client(c.id, true) -- force = true
			end
			-- Belt + suspenders: kill any leftover process by PID.
			for _, pid in ipairs(pids) do
				pcall(vim.fn.system, { "kill", "-9", tostring(pid) })
			end

			vim.notify("csharp_ls stopped — re-enabling…", vim.log.levels.INFO)

			-- 3. Wait for the process to actually die, then re-enable. The
			--    client gets attached on the next BufEnter for a .cs buffer.
			vim.defer_fn(function()
				vim.lsp.enable("csharp_ls")
				-- Trigger a re-attach for any currently-loaded .cs buffer.
				for _, b in ipairs(vim.api.nvim_list_bufs()) do
					if vim.api.nvim_buf_is_loaded(b) and vim.bo[b].filetype == "cs" then
						vim.api.nvim_buf_call(b, function()
							vim.cmd("edit")
						end)
					end
				end
				vim.notify(
					"csharp_ls restarted. Wait ~10s for workspace load, then retry gd.",
					vim.log.levels.INFO
				)
			end, 500)
		end, { desc = "Hard-restart csharp_ls + wipe csharp: buffers (works around upstream #319)" })

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

				-- For csharp_ls source buffers, capture the cword before firing
				-- the LSP request so the BufReadCmd handler can place the
				-- cursor on the right member inside the decompiled file.
				-- Also detect the empty-result case (#319 bug) and tell the
				-- user to run :CsharpReset.
				if client.name == "csharp_ls" then
					local function csharp_goto(method)
						return function()
							vim.g.csharp_ls_jump_word = vim.fn.expand("<cword>")
							local enc = client.offset_encoding or "utf-16"
							local params = vim.lsp.util.make_position_params(0, enc)
							client:request(method, params, function(err, result)
								if err then
									vim.notify("LSP " .. method .. ": " .. err.message, vim.log.levels.ERROR)
									return
								end
								if not result or (vim.islist(result) and vim.tbl_isempty(result)) then
									vim.notify(
										"csharp_ls returned no locations.\n"
											.. "If this is a *repeated* gd into a NuGet symbol, csharp-ls\n"
											.. "v0.24 has lost its workspace state (upstream bug #319).\n"
											.. "Run :CsharpReset to restart the server.",
										vim.log.levels.WARN
									)
									return
								end
								local first = vim.islist(result) and result[1] or result
								vim.lsp.util.show_document(first, enc, { focus = true })
							end, bufnr)
						end
					end
					map("n", "gd", csharp_goto("textDocument/definition"), "Go to definition")
					map("n", "gi", csharp_goto("textDocument/implementation"), "Implementation")
					map("n", "gy", csharp_goto("textDocument/typeDefinition"), "Type definition")
				else
					map("n", "gd", vim.lsp.buf.definition, "Go to definition")
					map("n", "gi", vim.lsp.buf.implementation, "Implementation")
					map("n", "gy", vim.lsp.buf.type_definition, "Type definition")
				end
				map("n", "gD", vim.lsp.buf.declaration, "Go to declaration")
				map("n", "gr", vim.lsp.buf.references, "References")
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
				init_options = {
					AutomaticWorkspaceInit = true,
				},
				-- Force `csharp:` URIs for external-symbol definitions; the
				-- BufReadCmd autocmd above fetches the decompiled source.
				settings = {
					csharp = {
						useMetadataUris = true,
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
