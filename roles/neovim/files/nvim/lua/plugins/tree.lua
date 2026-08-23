return {
  "nvim-tree/nvim-tree.lua",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  keys = {
    { "<leader>e", "<cmd>NvimTreeToggle<CR>", desc = "Toggle file tree" },
  },
  config = function()
    vim.g.loaded_netrw = 1
    vim.g.loaded_netrwPlugin = 1

    require("nvim-tree").setup({
      view = { width = 35 },
      renderer = {
        group_empty = true,
        git_placement = "after",
        icons = { show = { git = true } },
      },
      git = { enable = true, ignore = false },
      filters = { dotfiles = false },
    })
  end,
}
