return {
  {
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    keys = {
      {
        "<leader>cf",
        function() require("conform").format({ async = true, lsp_fallback = true }) end,
        desc = "Format buffer",
      },
    },
    config = function()
      require("conform").setup({
        formatters_by_ft = {
          python    = { "black", "isort" },
          go        = { "gofmt" },
          terraform = { "terraform_fmt" },
          markdown  = { "prettier" },
          yaml      = { "prettier" },
          json      = { "prettier" },
          lua       = { "stylua" },
        },
        format_on_save = {
          timeout_ms = 500,
          lsp_fallback = true,
        },
      })
    end,
  },

  {
    "mfussenegger/nvim-lint",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      local lint = require("lint")
      lint.linters_by_ft = {
        python  = { "ruff" },
        go      = { "golangcilint" },
        yaml    = { "yamllint" },
        ansible = { "ansible_lint" },
      }
      vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost", "InsertLeave" }, {
        callback = function() lint.try_lint() end,
      })
    end,
  },
}
