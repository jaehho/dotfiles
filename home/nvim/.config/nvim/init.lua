-- bootstrap lazy.nvim, LazyVim and your plugins
require('config.lazy')
-- Word-wrap virt_text/virt_lines when 'wrap' is on (before plugins draw).
require('config.virt_wrap').patch()
