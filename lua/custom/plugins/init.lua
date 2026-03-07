-- You can add your own plugins here or in other files in this directory!
--  I promise not to create any merge conflicts in this directory :)
--
-- See the kickstart.nvim README for more information
return {
  { dir = '~/code/agent-deck/nvim/agent-deck-review.nvim' },
  {
    'MeanderingProgrammer/render-markdown.nvim',
    dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-mini/mini.nvim' },
    ft = { 'markdown' },
    config = function(_, opts)
      local ok, devicons = pcall(require, 'nvim-web-devicons')
      if ok and devicons.set_icon_by_filetype then
        devicons.set_icon_by_filetype { mermaid = 'mermaid' }
        devicons.set_icon { mermaid = { icon = '󰐙', color = '#ff8c00', name = 'Mermaid' } }
      end
      require('render-markdown').setup(opts)
    end,
    opts = {
      anti_conceal = { enabled = false },
      latex = { enabled = false },
    },
  },
  {
    dir = vim.fn.stdpath('config') .. '/lua/custom',
    name = 'custom-previews',
    ft = { 'markdown', 'mermaid' },
    config = function()
      require('custom.mermaid').setup()
      require('custom.markdown_preview').setup()
    end,
  },
}
