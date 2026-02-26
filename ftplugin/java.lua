-- JDTLS configuration for Maven/Gradle Java projects
-- Skips activation in Bazel monorepo (java-language-server handles that)

local jdtls = require 'jdtls'

-- Don't activate in Bazel monorepo
if vim.fs.root(0, 'BUILD.bazel') then
  return
end

-- Don't activate if no Maven/Gradle project found
if not vim.fs.root(0, { 'pom.xml', 'build.gradle', 'build.gradle.kts' }) then
  return
end

local mason_path = vim.fn.stdpath 'data' .. '/mason/packages'
local jdtls_path = mason_path .. '/jdtls'

-- Find the Lombok jar bundled with Mason's jdtls install
local lombok_path = vim.fn.glob(jdtls_path .. '/lombok.jar')
if lombok_path == '' then
  lombok_path = vim.fn.glob(mason_path .. '/lombok-nightly/lombok.jar')
end

-- Workspace directory per-project (keeps indexes separate)
local project_name = vim.fn.fnamemodify(vim.fn.getcwd(), ':p:h:t')
local workspace_dir = vim.fn.stdpath 'data' .. '/jdtls-workspaces/' .. project_name

-- Java 25 to run jdtls itself (requires 21+), regardless of shell's JAVA_HOME
local java_bin = vim.fn.expand '~/.sdkman/candidates/java/25.0.1-amzn/bin/java'

local config = {
  cmd = {
    'jdtls',
    '--java-executable', java_bin,
    '-data', workspace_dir,
  },

  root_dir = vim.fs.root(0, { 'pom.xml', 'build.gradle', 'build.gradle.kts', '.git' }),

  capabilities = require('blink.cmp').get_lsp_capabilities(),

  settings = {
    java = {
      configuration = {
        runtimes = {
          {
            name = 'JavaSE-25',
            path = vim.fn.expand '~/.sdkman/candidates/java/25.0.1-amzn',
            default = true,
          },
          {
            name = 'JavaSE-21',
            path = vim.fn.expand '~/.sdkman/candidates/java/21.0.4-amzn',
          },
          {
            name = 'JavaSE-17',
            path = vim.fn.expand '~/.sdkman/candidates/java/17.0.14-amzn',
          },
        },
      },
      eclipse = { downloadSources = true },
      maven = { downloadSources = true },
      signatureHelp = { enabled = true },
      contentProvider = { preferred = 'fernflower' },
    },
  },

  init_options = {
    bundles = {},
  },
}

-- Add Lombok javaagent if available
if lombok_path ~= '' then
  config.cmd = {
    'jdtls',
    '--java-executable', java_bin,
    '--jvm-arg=-javaagent:' .. lombok_path,
    '-data', workspace_dir,
  }
end


jdtls.start_or_attach(config)
