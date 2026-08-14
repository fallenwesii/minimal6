return {
  {
    "folke/tokyonight.nvim",
    opts = {
      transparent = true,
      styles = {
        sidebars = "transparent",
        floats = "transparent",
      },
    },
  },

  {
    "LazyVim/LazyVim",
    opts = function()
      vim.api.nvim_create_autocmd("ColorScheme", {
        callback = function()
          local transparent = {
            "Normal",
            "NormalNC",
            "SignColumn",
            "EndOfBuffer",
            "CursorLineNr",
            "FoldColumn",
            "Folded",
            "NonText",
            "SpecialKey",
            "VertSplit",
            "WinSeparator",
            "StatusLine",
            "StatusLineNC",
            "TabLine",
            "TabLineFill",
            "TabLineSel",
            "NormalFloat",
            "FloatBorder",
            "FloatTitle",
          }

          for _, group in ipairs(transparent) do
            vim.api.nvim_set_hl(0, group, { bg = "NONE" })
          end
        end,
      })
    end,
  },
}
