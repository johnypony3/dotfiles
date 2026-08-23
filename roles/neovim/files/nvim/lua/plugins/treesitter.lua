return {
  "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate",
  config = function()
    require("nvim-treesitter.configs").setup({
      ensure_installed = {
        "python", "go", "hcl", "yaml", "toml",
        "lua", "markdown", "markdown_inline",
        "bash", "json", "vim", "vimdoc",
      },
      auto_install = true,
      highlight = { enable = true },
      indent = { enable = true },
    })
  end,
}
