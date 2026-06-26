-- C# language server (modern Roslyn LSP — Microsoft.CodeAnalysis.LanguageServer),
-- replacing OmniSharp. roslyn.nvim detects the .sln/.csproj target, materialises
-- decompiled/metadata + source-generated files over standard LSP, and ENABLES the
-- "roslyn" client itself — so the LSP *settings* live in lua/plugins/lsp.lua via
-- vim.lsp.config("roslyn", ...), not here.
--
-- Server binary comes from the mason package `roslyn` (Crashdummyy registry, wired
-- in lua/plugins/mason.lua). After syncing: `:MasonUpdate` then `:MasonInstall roslyn`.
return {
	"seblyng/roslyn.nvim",
	ft = "cs",
	---@module 'roslyn.config'
	---@type RoslynNvimConfig
	opts = {},
}
