-- ── .NET debug: auto-discover the launchable project + read launchSettings.json ──
-- Works in any .NET repo with no per-project config: finds the project that owns a
-- Properties/launchSettings.json, resolves its built dll, sets the content-root cwd,
-- and pulls ASPNETCORE_ENVIRONMENT/URLS straight out of launchSettings.json.
local function dotnet_launchable_projects()
	local files = vim.fn.glob(vim.fn.getcwd() .. "/**/Properties/launchSettings.json", true, true)
	local projects = {}
	for _, f in ipairs(files) do
		if not f:match("/bin/") and not f:match("/obj/") then
			table.insert(projects, vim.fn.fnamemodify(f, ":h:h")) -- strip /Properties/launchSettings.json
		end
	end
	return projects
end

local function dotnet_dll_for(project_dir)
	-- a project's OWN output dir holds exactly one *.runtimeconfig.json (its app dll)
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

local function debug_dotnet()
	local dap = require("dap")
	local projects = dotnet_launchable_projects()
	if #projects == 0 then
		return vim.notify("No launchable .NET project (Properties/launchSettings.json) found", vim.log.levels.WARN)
	end
	local function go(dir)
		local dll = dotnet_dll_for(dir)
		if not dll then
			return vim.notify("Not built: " .. dir .. " — run `dotnet build`", vim.log.levels.WARN)
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
	if #projects == 1 then
		go(projects[1])
	else
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
end

return {
	"mfussenegger/nvim-dap",
	dependencies = {
		{ "rcarriga/nvim-dap-ui", dependencies = { "nvim-neotest/nvim-nio" } },
		"theHamsta/nvim-dap-virtual-text",
		"williamboman/mason.nvim",
		"jay-babu/mason-nvim-dap.nvim",
	},
	keys = {
		{
			"<F5>",
			function()
				require("dap").continue()
			end,
			desc = "Debug: continue / start",
		},
		{
			"<F10>",
			function()
				require("dap").step_over()
			end,
			desc = "Debug: step over",
		},
		{
			"<F11>",
			function()
				require("dap").step_into()
			end,
			desc = "Debug: step into",
		},
		{
			"<S-F11>",
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
			desc = "Debug .NET (auto-discover)",
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
					elements = { { id = "repl", size = 0.5 }, { id = "console", size = 0.5 } },
					position = "bottom",
					size = 10,
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

		-- .NET / C# uses netcoredbg. mason-nvim-dap registers it as `coreclr`
		-- automatically; redefine here so we don't depend on handler order.
		dap.adapters.coreclr = {
			type = "executable",
			command = vim.fn.exepath("netcoredbg"),
			args = { "--interpreter=vscode" },
		}
		local function pick_dll()
			local cwd = vim.fn.getcwd()
			local matches = vim.fn.glob(cwd .. "/bin/Debug/net*/*.dll", true, true)
			local default = matches[1] or (cwd .. "/bin/Debug/")
			return vim.fn.input("Path to dll: ", default, "file")
		end
		dap.configurations.cs = {
			{
				type = "coreclr",
				name = "Launch - netcoredbg",
				request = "launch",
				program = pick_dll,
				cwd = "${workspaceFolder}",
				stopAtEntry = false,
			},
			{
				type = "coreclr",
				name = "Attach - netcoredbg",
				request = "attach",
				processId = require("dap.utils").pick_process,
			},
		}
	end,
}
