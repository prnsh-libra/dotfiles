 local M = {}

function M.setup()
  require('base16-colorscheme').setup({
    base00 = '#000000',
    base01 = '#131313',
    base02 = '#1e1e1e',
    base03 = '#919191',
    base04 = '#c6c6c6',
    base05 = '#e2e2e2',
    base06 = '#e2e2e2',
    base07 = '#e2e2e2',
    base08 = '#ffb4ab',
    base09 = '#e2e2e2',
    base0A = '#c6c6c6',
    base0B = '#ffffff',
    base0C = '#474747',
    base0D = '#474747',
    base0E = '#ababab',
    base0F = '#93000a',
  })

  local hi = function(group, opts)
    vim.api.nvim_set_hl(0, group, opts)
  end

  hi('TelescopeNormal',         { fg = '#e2e2e2',          bg = '#000000' })
  hi('TelescopeBorder',         { fg = '#919191',             bg = '#000000' })
  hi('TelescopePromptNormal',   { fg = '#e2e2e2',          bg = '#000000' })
  hi('TelescopePromptBorder',   { fg = '#919191',             bg = '#000000' })
  hi('TelescopePromptPrefix',   { fg = '#ffffff',             bg = '#000000' })
  hi('TelescopePromptCounter',  { fg = '#c6c6c6',  bg = '#000000' })
  hi('TelescopePromptTitle',    { fg = '#000000',             bg = '#ffffff' })
  hi('TelescopePreviewTitle',   { fg = '#000000',             bg = '#c6c6c6' })
  hi('TelescopeResultsTitle',   { fg = '#000000',             bg = '#e2e2e2' })
  hi('TelescopeSelection',      { fg = '#e2e2e2',          bg = '#1e1e1e' })
  hi('TelescopeSelectionCaret', { fg = '#ffffff',             bg = '#1e1e1e' })
  hi('TelescopeMatching',       { fg = '#ffffff',             bold = true })
end

 -- Register a signal handler for SIGUSR1 (matugen updates)
 local signal = vim.uv.new_signal()
 signal:start(
   'sigusr1',
   vim.schedule_wrap(function()
     package.loaded['matugen'] = nil
     require('matugen').setup()
   end)
 )

 return M
