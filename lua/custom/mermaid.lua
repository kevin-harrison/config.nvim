local M = {}

local prev_html_path = nil

local function cleanup_prev()
  if prev_html_path then
    os.remove(prev_html_path)
    prev_html_path = nil
  end
end

function M.get_mermaid_source()
  local ft = vim.bo.filetype
  if ft == 'mermaid' then
    return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n')
  end

  local buf = vim.api.nvim_get_current_buf()
  local cursor_row = vim.api.nvim_win_get_cursor(0)[1] - 1

  local ok, parser = pcall(vim.treesitter.get_parser, buf, 'markdown')
  if not ok then
    vim.notify('Markdown treesitter parser not available', vim.log.levels.ERROR)
    return nil
  end

  parser:parse()

  local query = vim.treesitter.query.parse('markdown', [[
    (fenced_code_block
      (info_string (language) @lang)
      (code_fence_content) @content)
  ]])

  for _, match, _ in query:iter_matches(parser:trees()[1]:root(), buf) do
    local lang_node, content_node
    for id, nodes in pairs(match) do
      local name = query.captures[id]
      local node = type(nodes) == 'table' and nodes[1] or nodes
      if name == 'lang' then lang_node = node end
      if name == 'content' then content_node = node end
    end

    if lang_node and content_node then
      local lang_text = vim.treesitter.get_node_text(lang_node, buf)
      if lang_text == 'mermaid' then
        local start_row, _, end_row, _ = content_node:range()
        if cursor_row >= start_row and cursor_row <= end_row then
          return vim.treesitter.get_node_text(content_node, buf)
        end
      end
    end
  end

  vim.notify('No mermaid block found under cursor', vim.log.levels.WARN)
  return nil
end

local html_template = [[
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>Mermaid Preview</title>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    background: #1a1b26;
    display: flex;
    align-items: center;
    justify-content: center;
    height: 100vh;
    overflow: hidden;
  }
  #container {
    width: 90vw;
    height: 90vh;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  #container svg {
    max-width: 100%%;
    max-height: 100%%;
  }
  #reset {
    position: fixed;
    top: 12px;
    right: 12px;
    background: #414868;
    color: #c0caf5;
    border: none;
    padding: 6px 14px;
    border-radius: 6px;
    cursor: pointer;
    font-size: 13px;
    z-index: 10;
  }
  #reset:hover { background: #565f89; }
</style>
</head>
<body>
<button id="reset" onclick="pz.reset()">Reset Zoom</button>
<div id="container">
%s
</div>
<script src="https://cdn.jsdelivr.net/npm/@panzoom/panzoom@4.5.1/dist/panzoom.min.js"></script>
<script>
  var el = document.getElementById('container');
  var pz = Panzoom(el, { maxScale: 10, minScale: 0.1 });
  el.parentElement.addEventListener('wheel', function(e) {
    pz.zoomWithWheel(e);
  });
</script>
</body>
</html>
]]

function M.preview()
  local source = M.get_mermaid_source()
  if not source then return end

  local tmp_base1 = os.tmpname()
  local tmp_base2 = os.tmpname()
  local tmp_mmd = tmp_base1 .. '.mmd'
  local tmp_svg = tmp_base2 .. '.svg'
  os.remove(tmp_base1)
  os.remove(tmp_base2)

  local f = io.open(tmp_mmd, 'w')
  if not f then
    vim.notify('Failed to create temp file', vim.log.levels.ERROR)
    return
  end
  f:write(source)
  f:close()

  vim.system(
    { 'mmdc', '-i', tmp_mmd, '-o', tmp_svg, '-t', 'dark', '-b', 'transparent' },
    {},
    vim.schedule_wrap(function(result)
      os.remove(tmp_mmd)

      if result.code ~= 0 then
        vim.notify('mmdc failed: ' .. (result.stderr or ''), vim.log.levels.ERROR)
        return
      end

      local svg_file = io.open(tmp_svg, 'r')
      if not svg_file then
        vim.notify('Failed to read SVG output', vim.log.levels.ERROR)
        return
      end
      local svg_content = svg_file:read('*a')
      svg_file:close()
      os.remove(tmp_svg)

      cleanup_prev()

      local tmp_base3 = os.tmpname()
      os.remove(tmp_base3)
      local tmp_html = tmp_base3 .. '.html'
      local html_file = io.open(tmp_html, 'w')
      if not html_file then
        vim.notify('Failed to create HTML file', vim.log.levels.ERROR)
        return
      end
      html_file:write(string.format(html_template, svg_content))
      html_file:close()

      prev_html_path = tmp_html
      vim.ui.open(tmp_html)
    end)
  )
end

function M.setup()
  vim.api.nvim_create_user_command('MermaidPreview', function()
    M.preview()
  end, { desc = 'Preview mermaid diagram under cursor in browser' })

  vim.keymap.set('n', '<leader>mp', function()
    M.preview()
  end, { desc = '[M]ermaid [P]review' })

  vim.api.nvim_create_autocmd('VimLeave', {
    callback = cleanup_prev,
  })
end

return M
