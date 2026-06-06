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
	},
	config = function()
		local dap, dapui = require("dap"), require("dapui")

		-- mason-nvim-dap auto-installs DAP adapters via Mason
		require("mason-nvim-dap").setup({
			ensure_installed = { "delve", "python" },
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
	end,
}
