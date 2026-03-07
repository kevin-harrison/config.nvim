local M = {}

local prev_html_path = nil

local function cleanup_prev()
  if prev_html_path then
    os.remove(prev_html_path)
    prev_html_path = nil
  end
end

local html_template = [[
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>%s</title>
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/github-markdown-css@5/github-markdown-dark.min.css">
<link rel="stylesheet" href="https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11/build/styles/github-dark.min.css">
<style>
  body {
    background: #0d1117;
    color: #e6edf3;
    display: flex;
    justify-content: center;
    padding: 2rem 1rem;
  }
  .markdown-body {
    max-width: 980px;
    width: 100%%;
  }
  .mermaid-frame {
    position: relative;
    border: 1px solid #30363d;
    border-radius: 6px;
    overflow: hidden;
    margin: 1rem 0;
    background: #161b22;
    height: 500px;
  }
  .mermaid-frame .mermaid-inner {
    height: 100%%;
    padding: 1rem;
  }
  .mermaid-frame .mermaid-inner svg {
    width: 100%%;
    height: 100%%;
  }
  .mermaid-reset {
    position: absolute;
    top: 8px;
    right: 8px;
    background: #30363d;
    color: #c9d1d9;
    border: none;
    padding: 4px 10px;
    border-radius: 4px;
    cursor: pointer;
    font-size: 12px;
    z-index: 2;
    opacity: 0;
    transition: opacity 0.2s;
  }
  .mermaid-frame:hover .mermaid-reset { opacity: 1; }
  .mermaid-reset:hover { background: #484f58; }
</style>
</head>
<body>
<article class="markdown-body" id="content"></article>
<script type="text/plain" id="raw-content">%s</script>
<script src="https://cdn.jsdelivr.net/npm/markdown-it@14/dist/markdown-it.min.js"></script>
<script src="https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11/build/highlight.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/@panzoom/panzoom@4.5.1/dist/panzoom.min.js"></script>
<script>
  mermaid.initialize({ startOnLoad: false, theme: 'dark' });

  var md = window.markdownit({
    html: true,
    linkify: true,
    highlight: function(str, lang) {
      if (lang && hljs.getLanguage(lang)) {
        return hljs.highlight(str, { language: lang }).value;
      }
      return '';
    }
  });

  var raw = document.getElementById('raw-content').textContent;
  document.getElementById('content').innerHTML = md.render(raw);

  var mermaidBlocks = document.querySelectorAll('code.language-mermaid');
  if (mermaidBlocks.length > 0) {
    mermaidBlocks.forEach(function(el, i) {
      var pre = el.parentElement;

      // Build: .mermaid-frame > button.mermaid-reset + .mermaid-inner > .mermaid
      var frame = document.createElement('div');
      frame.className = 'mermaid-frame';

      var btn = document.createElement('button');
      btn.className = 'mermaid-reset';
      btn.textContent = 'Reset Zoom';

      var inner = document.createElement('div');
      inner.className = 'mermaid-inner';

      var div = document.createElement('div');
      div.className = 'mermaid';
      div.id = 'mermaid-' + i;
      div.textContent = el.textContent.trim();

      inner.appendChild(div);
      frame.appendChild(btn);
      frame.appendChild(inner);
      pre.replaceWith(frame);
    });

    mermaid.run({ querySelector: '.mermaid' }).then(function() {
      document.querySelectorAll('.mermaid-inner').forEach(function(inner) {
        var pz = Panzoom(inner, { maxScale: 10, minScale: 0.1 });
        inner.parentElement.addEventListener('wheel', function(e) {
          if (e.ctrlKey || e.metaKey) {
            e.preventDefault();
            pz.zoomWithWheel(e);
          }
        }, { passive: false });
        inner.parentElement.querySelector('.mermaid-reset').addEventListener('click', function() {
          pz.reset();
        });
      });
    });
  }
</script>
</body>
</html>
]]

function M.preview()
  local ft = vim.bo.filetype
  if ft ~= 'markdown' then
    vim.notify('Not a markdown file', vim.log.levels.WARN)
    return
  end

  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local content = table.concat(lines, '\n')
  local filename = vim.fn.expand('%:t')
  if filename == '' then filename = 'Markdown Preview' end

  cleanup_prev()

  local tmp_base = os.tmpname()
  os.remove(tmp_base)
  local tmp_html = tmp_base .. '.html'
  local f = io.open(tmp_html, 'w')
  if not f then
    vim.notify('Failed to create temp file', vim.log.levels.ERROR)
    return
  end

  -- <script type="text/plain"> doesn't parse HTML entities, so we only need
  -- to escape the sequence that would prematurely close the tag
  local escaped = content:gsub('</script', '<\\/script')
  f:write(string.format(html_template, filename, escaped))
  f:close()

  prev_html_path = tmp_html
  vim.ui.open(tmp_html)
end

function M.setup()
  vim.api.nvim_create_user_command('MarkdownPreview', function()
    M.preview()
  end, { desc = 'Preview markdown file in browser' })

  vim.keymap.set('n', '<leader>md', function()
    M.preview()
  end, { desc = '[M]arkdown Preview in Browser' })

  vim.api.nvim_create_autocmd('VimLeave', {
    callback = cleanup_prev,
  })
end

return M
