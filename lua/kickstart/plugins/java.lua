-- nvim-jdtls: Enhanced Java LSP support for Maven/Gradle projects
-- JDTLS config lives in ftplugin/java.lua (started per-buffer, not here)
-- https://github.com/mfussenegger/nvim-jdtls

return {
  'mfussenegger/nvim-jdtls',
  ft = { 'java' },
}
