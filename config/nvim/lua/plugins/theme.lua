return {
  -- Keep tokyonight installed but don't make it the active scheme
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

  -- Set matugen as the colorscheme (generated dynamically from your wallpaper)
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "matugen",
    },
  },

  -- After every colorscheme load, enforce full transparency so no theme
  -- can sneak in a background color (even when matugen sets some)
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
            "NormalFloat",
            "FloatBorder",
            "FloatTitle",
            -- Tab line (keep bg-less so terminal bg shows through)
            "TabLine",
            "TabLineFill",
          }

          for _, group in ipairs(transparent) do
            -- Preserve existing fg/sp but wipe bg
            local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = group, link = false })
            if ok then
              hl.bg = nil
              hl.ctermbg = nil
              vim.api.nvim_set_hl(0, group, hl)
            else
              vim.api.nvim_set_hl(0, group, { bg = "NONE" })
            end
          end
        end,
      })
    end,
  },
}
