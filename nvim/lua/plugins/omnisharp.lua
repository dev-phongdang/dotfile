-- Companion plugin for OmniSharp: handles `omnisharp-metadata://` and
-- source-generated URIs so gd into NuGet types lands in decompiled source
-- and references include metadata results. Keymaps are wired in lsp.lua
-- via require('omnisharp_extended').lsp_*().
return {
	"Hoffs/omnisharp-extended-lsp.nvim",
	ft = "cs",
}
