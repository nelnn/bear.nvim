local M = {}

M.config = {
  cache_dir = "~/.cache/nvim/bear",
  file_name = "tmp_" .. os.date("%m%d_%H%M%S") .. ".csv",
  remove_file = true,
  export_transport = "auto", -- Spark uses DAP; pandas/polars use local files
  max_transfer_bytes = 10 * 1024 * 1024,
  spark = {
    max_rows = 1000,
  },
  window = {
    width = 0.9,
    height = 0.8,
    border = "rounded",
  },
  keymap = {
    visualise = "<leader>df",
    visualise_buf = "<leader>bdf",
    exit_terminal_mode = "<Esc><Esc>",
  }
}

function M.setup(opts)
  opts = vim.tbl_deep_extend("force", {}, M.config, opts or {})
  M.config = opts

  vim.api.nvim_create_user_command("DFView", function(args)
    require("bear.core").visualise_dataframe(opts, "float", args.args)
  end, { nargs = "?", desc = "Visualise DataFrame in floating window under cursor" })

  vim.api.nvim_create_user_command("DFViewBuf", function(args)
    require("bear.core").visualise_dataframe(opts, "buffer", args.args)
  end, { nargs = "?", desc = "Visualise DataFrame in new buffer under cursor" })

  vim.api.nvim_create_user_command("DFClean", function()
    require("bear.utils").clean_cache(opts)
  end, { desc = "Clean cache directory" })

  vim.keymap.set({ "n", "v" }, opts.keymap.visualise,
    function() require("bear.core").visualise_dataframe(opts, "float") end,
    { desc = "Visualise DataFrame in floating window" })

  vim.keymap.set({ "n", "v" }, opts.keymap.visualise_buf,
    function() require("bear.core").visualise_dataframe(opts, "buffer") end,
    { desc = "Visualise DataFrame in new buffer" })
end

M.visualise = function(opts, mode, expression)
  opts = vim.tbl_deep_extend("force", {}, M.config, opts or {})
  require("bear.core").visualise_dataframe(opts, mode or "float", expression)
end

return M
