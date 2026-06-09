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
			}
		end
		-- Build first so the DLL is fresh, then resolve the runnable app DLL by
		-- its sibling <name>.runtimeconfig.json. Dependency DLLs (Microsoft.*,
		-- Swashbuckle.*, …) have no runtimeconfig, so they're never picked.
		local function pick_dll()
			local out = vim.fn.system({ "dotnet", "build", "-c", "Debug" })
			if vim.v.shell_error ~= 0 then
				vim.notify("dotnet build failed:\n" .. out, vim.log.levels.ERROR, { title = "dap" })
				return dap.ABORT
			end
			local cwd = vim.fn.getcwd()
			local configs = vim.fn.glob(cwd .. "/bin/Debug/net*/*.runtimeconfig.json", true, true)
			local dlls = vim.tbl_map(function(c)
				return (c:gsub("%.runtimeconfig%.json$", ".dll"))
			end, configs)
			if #dlls == 1 then
				return dlls[1] -- exactly one app → launch it, no prompt
			end
			return vim.fn.input("Path to dll: ", dlls[1] or (cwd .. "/bin/Debug/"), "file")
		end
		dap.configurations.cs = {
			{
				type = "coreclr",
				name = "Launch - netcoredbg",
				request = "launch",
				program = pick_dll,
				cwd = "${workspaceFolder}",
				stopAtEntry = false,
				-- netcoredbg sends the app's stdout/stderr as DAP output events,
				-- which nvim-dap prints in the REPL pane (<leader>dr); it doesn't
				-- honor integratedTerminal, so we don't set it.
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
