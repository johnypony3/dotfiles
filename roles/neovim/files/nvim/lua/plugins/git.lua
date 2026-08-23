return {
  {
    "lewis6991/gitsigns.nvim",
    config = function()
      require("gitsigns").setup({
        signs = {
          add          = { text = "│" },
          change       = { text = "│" },
          delete       = { text = "_" },
          topdelete    = { text = "‾" },
          changedelete = { text = "~" },
        },
        on_attach = function(bufnr)
          local gs = package.loaded.gitsigns
          local map = function(mode, lhs, rhs, desc)
            vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
          end
          map("n", "]h", gs.next_hunk, "Next hunk")
          map("n", "[h", gs.prev_hunk, "Prev hunk")
          map("n", "<leader>gp", gs.preview_hunk, "Preview hunk")
          map("n", "<leader>gs", gs.stage_hunk, "Stage hunk")
          map("n", "<leader>gr", gs.reset_hunk, "Reset hunk")
          map("n", "<leader>gS", gs.stage_buffer, "Stage buffer")
          map("n", "<leader>gb", gs.blame_line, "Blame line")
        end,
      })
    end,
  },

  {
    "sindrets/diffview.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      { "<leader>gg", "<cmd>DiffviewOpen<CR>", desc = "Open diffview" },
      { "<leader>gq", "<cmd>DiffviewClose<CR>", desc = "Close diffview" },
      { "<leader>gh", "<cmd>DiffviewFileHistory %<CR>", desc = "File history" },
    },
    config = function()
      require("diffview").setup({
        view = { default = { layout = "diff2_horizontal" } },
      })
    end,
  },
}
