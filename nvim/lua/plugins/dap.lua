-- ── .NET multi-project debug discovery ─────────────────────────────────────
-- Clean Architecture solutions have many projects but only a few *runnable*
-- apps (Api, Worker, …) — exactly the ones with Properties/launchSettings.json.
-- We discover those, build the chosen one (+ its project references), resolve
-- its dll, set the content-root cwd, and pull ASPNETCORE_* from launchSettings.
-- Discovery is per-project, NOT cwd-relative, so it works from a solution root.

local function dotnet_launchable_projects()
	local files = vim.fn.glob(vim.fn.getcwd() .. "/**/Properties/launchSettings.json", true, true)
	local projects = {}
	for _, f in ipairs(files) do
		if not f:match("/bin/") and not f:match("/obj/") then
			projects[#projects + 1] = vim.fn.fnamemodify(f, ":h:h") -- strip /Properties/launchSettings.json
		end
	end
	return projects
end

local function dotnet_dll_for(project_dir)
	-- a project's own output dir holds exactly one *.runtimeconfig.json (its app dll)
	local rc = vim.fn.glob(project_dir .. "/bin/Debug/net*/*.runtimeconfig.json", true, true)[1]
	return rc and (rc:gsub("%.runtimeconfig%.json$", ".dll")) or nil
end

local function dotnet_env_for(project_dir)
	local env = { ASPNETCORE_ENVIRONMENT = "Development" }
	local path = project_dir .. "/Properties/launchSettings.json"
	if vim.fn.filereadable(path) == 1 then
		local ok, data = pcall(vim.fn.json_decode, table.concat(vim.fn.readfile(path), "\n"))
		if ok and type(data) == "table" and data.profiles then
			-- prefer the http profile (deterministic, no dev-cert dance); else first Project profile
			local profile = data.profiles.http
			if not profile then
				for _, p in pairs(data.profiles) do
					if p.commandName == "Project" then
						profile = p
						break
					end
				end
			end
			if profile then
				env = vim.tbl_extend("force", env, profile.environmentVariables or {})
				if profile.applicationUrl and not env.ASPNETCORE_URLS then
					env.ASPNETCORE_URLS = profile.applicationUrl
				end
			end
		end
	end
	return env
end

-- Build the chosen project (pulls in its ProjectReferences). Blocks briefly.
local function dotnet_build(project_dir)
	local out = vim.fn.system({ "dotnet", "build", "-c", "Debug", project_dir })
	if vim.v.shell_error ~= 0 then
		vim.notify("dotnet build failed:\n" .. out, vim.log.levels.ERROR, { title = "dap" })
		return false
	end
	return true
end

local function debug_dotnet()
	local dap = require("dap")
	local projects = dotnet_launchable_projects()
	if #projects == 0 then
		return vim.notify(
			"No launchable .NET project (Properties/launchSettings.json) found under cwd",
			vim.log.levels.WARN
		)
	end
	local function go(dir)
		if not dotnet_build(dir) then
			return
		end
		local dll = dotnet_dll_for(dir)
		if not dll then
			return vim.notify("Build produced no runnable dll in " .. dir, vim.log.levels.WARN)
		end
		dap.run({
			type = "coreclr",
			request = "launch",
			name = "Launch " .. vim.fn.fnamemodify(dll, ":t"),
			program = dll,
			cwd = dir, -- content root → appsettings*.json resolve
			env = dotnet_env_for(dir), -- ASPNETCORE_ENVIRONMENT/URLS from launchSettings.json
			stopAtEntry = false,
		})
	end
	-- Always show the picker — even for a single project — so launching is an
	-- explicit choice, never an auto-start.
	table.sort(projects)
	vim.ui.select(projects, {
		prompt = "Debug which .NET project?",
		format_item = function(p)
			return vim.fn.fnamemodify(p, ":~:.")
		end,
	}, function(c)
		if c then
			go(c)
		end
	end)
end

return {
	"mfussenegger/nvim-dap",
	dependencies = {
		{ "rcarriga/nvim-dap-ui", dependencies = { "nvim-neotest/nvim-nio" } },
		"theHamsta/nvim-dap-virtual-text",
		"williamboman/mason.nvim",
		"jay-babu/mason-nvim-dap.nvim",
		"Cliffback/netcoredbg-macOS-arm64.nvim", -- arm64 netcoredbg (no official macOS arm64 build)
	},
	keys = {
		{
			"<F5>",
			function()
				local dap = require("dap")
				-- In a C# buffer with no live session, start via the multi-project
				-- discovery (build + pick launchable project). Otherwise behave as
				-- the normal continue/start (resume, or Go/Python configurations).
				if not dap.session() and vim.bo.filetype == "cs" then
					debug_dotnet()
				else
					dap.continue()
				end
			end,
			desc = "Debug: continue / start",
		},
		{
			"<leader>dc",
			function()
				require("dap").continue()
			end,
			desc = "Debug: step continue",
		},
		{
			"<leader>di",
			function()
				require("dap").step_into()
			end,
			desc = "Debug: step into",
		},
		{
			"<leader>do",
			function()
				require("dap").step_over()
			end,
			desc = "Debug: step over",
		},
		{
			"<leader>d0",
			function()
				require("dap").step_out()
			end,
			desc = "Debug: step out",
		},
		{
			"<leader>db",
			function()
				require("dap").toggle_breakpoint()
			end,
			desc = "Breakpoint toggle",
		},
		{
			"<leader>dB",
			function()
				require("dap").set_breakpoint(vim.fn.input("Condition: "))
			end,
			desc = "Conditional breakpoint",
		},
		{
			"<leader>dr",
			function()
				require("dap").repl.open()
			end,
			desc = "REPL",
		},
		{
			"<leader>dl",
			function()
				require("dap").run_last()
			end,
			desc = "Run last",
		},
		{
			"<leader>du",
			function()
				require("dapui").toggle()
			end,
			desc = "Toggle DAP UI",
		},
		{
			"<leader>de",
			function()
				require("dapui").eval()
			end,
			mode = { "n", "v" },
			desc = "Eval under cursor",
		},
		{
			"<leader>dt",
			function()
				require("dap").terminate()
			end,
			desc = "Terminate",
		},
		{
			"<leader>dn",
			function()
				debug_dotnet()
			end,
			desc = "Debug .NET (build + pick project)",
		},
		{
			"<leader>da",
			function()
				require("dap").run({
					type = "coreclr",
					request = "attach",
					name = "Attach (.NET)",
					processId = require("dap.utils").pick_process,
				})
			end,
			desc = "Debug: attach .NET process",
		},
	},
	config = function()
		local dap, dapui = require("dap"), require("dapui")

		-- mason-nvim-dap auto-installs DAP adapters via Mason
		require("mason-nvim-dap").setup({
			ensure_installed = { "delve", "python", "netcoredbg" },
			automatic_installation = true,
			handlers = {}, -- use default handlers, customise per-language below
		})

		dapui.setup({
			layouts = {
				{
					elements = {
						{ id = "scopes", size = 0.40 },
						{ id = "breakpoints", size = 0.20 },
						{ id = "stacks", size = 0.20 },
						{ id = "watches", size = 0.20 },
					},
					position = "left",
					size = 40,
				},
				{
					-- netcoredbg streams app stdout as output events, which land
					-- in the REPL (the `console` terminal element only fills via
					-- runInTerminal, which netcoredbg doesn't use). So give the
					-- REPL the whole bottom panel instead of a dead console pane.
					elements = { { id = "repl", size = 1.0 } },
					position = "bottom",
					size = 12,
				},
			},
		})

		require("nvim-dap-virtual-text").setup({ commented = true })

		-- Auto open/close UI with sessions
		dap.listeners.before.attach.dapui_config = function()
			dapui.open()
		end
		dap.listeners.before.launch.dapui_config = function()
			dapui.open()
		end
		dap.listeners.before.event_terminated.dapui_config = function()
			dapui.close()
		end
		dap.listeners.before.event_exited.dapui_config = function()
			dapui.close()
		end

		-- Pretty breakpoint icons
		vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DapBreakpoint", linehl = "", numhl = "" })
		vim.fn.sign_define(
			"DapBreakpointCondition",
			{ text = "◆", texthl = "DapBreakpoint", linehl = "", numhl = "" }
		)
		vim.fn.sign_define("DapLogPoint", { text = "◆", texthl = "DapLogPoint", linehl = "", numhl = "" })
		vim.fn.sign_define("DapStopped", {
			text = "▶",
			texthl = "DapStopped",
			linehl = "DapStoppedLine",
			numhl = "",
		})

		-- --- Language adapters ---------------------------------------------

		-- Go uses delve. nvim-dap-go (next section) configures it more nicely;
		-- this manual config is the minimal fallback.
		dap.adapters.delve = {
			type = "server",
			port = "${port}",
			executable = {
				command = "dlv",
				args = { "dap", "-l", "127.0.0.1:${port}" },
			},
		}
		dap.configurations.go = {
			{ type = "delve", name = "Debug", request = "launch", program = "${file}" },
			{ type = "delve", name = "Debug test (file)", request = "launch", mode = "test", program = "${file}" },
			{
				type = "delve",
				name = "Debug test (package)",
				request = "launch",
				mode = "test",
				program = "./${relativeFileDirname}",
			},
		}

		-- Python uses debugpy. mason-nvim-dap registers the adapter for us;
		-- we override the python path if a venv exists.
		dap.configurations.python = {
			{
				type = "python",
				request = "launch",
				name = "Launch file",
				program = "${file}",
				pythonPath = function()
					local cwd = vim.fn.getcwd()
					for _, candidate in ipairs({ cwd .. "/.venv/bin/python", cwd .. "/venv/bin/python" }) do
						if vim.fn.executable(candidate) == 1 then
							return candidate
						end
					end
					return vim.fn.exepath("python3") or "python"
				end,
			},
			{
				type = "python",
				request = "launch",
				name = "Pytest: current file",
				module = "pytest",
				args = { "${file}", "-s" },
				console = "integratedTerminal",
			},
		}

		-- .NET / C# uses netcoredbg, registered as the `coreclr` adapter.
		-- IMPORTANT (Apple Silicon): the official netcoredbg has no macOS arm64
		-- build — Mason installs the x86_64 one, which runs under Rosetta but
		-- CANNOT debug an arm64 .NET process (it dies at configurationDone). So
		-- on macOS arm64 use the community arm64 build shipped by
		-- netcoredbg-macOS-arm64.nvim; everywhere else use the Mason binary.
		local uname = vim.loop.os_uname()
		local using_arm64_build = false
		if uname.sysname == "Darwin" and uname.machine == "arm64" then
			-- setup() points dap.adapters.coreclr/netcoredbg at the bundled
			-- arm64 binary. It also sets a default dap.configurations.cs, which
			-- we override with our own below.
			using_arm64_build = pcall(function()
				require("netcoredbg-macOS-arm64").setup()
			end)
		end
		if not using_arm64_build then
			local netcoredbg = vim.fn.exepath("netcoredbg")
			if netcoredbg == "" then
				netcoredbg = vim.fn.stdpath("data") .. "/mason/bin/netcoredbg"
			end
			dap.adapters.coreclr = {
				type = "executable",
				command = netcoredbg,
				args = { "--interpreter=vscode" },
				console = "integratedTerminal",
			}
		end
		-- .NET launch + attach are handled programmatically (see the helpers at
		-- the top of this file): <F5> in a C# buffer — or <leader>dn — builds the
		-- chosen launchable project and launches its dll via debug_dotnet();
		-- <leader>da attaches to a running dotnet process. Discovery is
		-- per-project (launchSettings.json), not cwd-relative, so multi-project
		-- Clean-Architecture solutions start from the solution root.
	end,
}
