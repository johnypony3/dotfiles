return {
  {
    "nvim-telescope/telescope.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
    },
    keys = {
      { "<leader>ff", "<cmd>Telescope find_files<CR>", desc = "Find files" },
      { "<leader>fg", "<cmd>Telescope live_grep<CR>", desc = "Live grep" },
      { "<leader>fb", "<cmd>Telescope buffers<CR>", desc = "Buffers" },
      { "<leader>fr", "<cmd>Telescope oldfiles<CR>", desc = "Recent files" },
    },
    config = function()
      local telescope = require("telescope")
      telescope.setup({
        defaults = {
          file_ignore_patterns = { "node_modules", ".git/" },
          layout_config = { prompt_position = "top" },
          sorting_strategy = "ascending",
        },
      })
      telescope.load_extension("fzf")
      telescope.load_extension("projects")
    end,
  },

  {
    "ahmedkhalf/project.nvim",
    keys = {
      { "<leader>fp", "<cmd>Telescope projects<CR>", desc = "Switch project" },
    },
    config = function()
      require("project_nvim").setup({
        detection_methods = { "pattern", "lsp" },
        patterns = { ".git", "go.mod", "pyproject.toml", "*.tf" },
        show_hidden = false,
      })
    end,
  },
}
