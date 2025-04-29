local M = {}

M.config = {
  cache_dir = "~/.cache/nvim/bear",
  file_name = "df_debug_" .. os.time() .. ".csv",
  window = {
    width = 0.9,
    height = 0.8,
    border = "rounded"
  },
  keymap = {
    visualise = "<Leader>df"
  }
}

function M.setup(opts)
  opts = vim.tbl_deep_extend("force", {}, M.config, opts or {})

  vim.api.nvim_create_user_command("DFView", function()
    require("bear.core").visualise_dataframe(opts)
  end, { desc = "Visualise DataFrame under cursor" })

  if M.config.keymap.visualise then
    vim.keymap.set("n", M.config.keymap.visualise,
      function() require("bear.core").visualise_dataframe(opts) end,
      { desc = "Visualise DataFrame (float)" })
  end
end

M.visualise = function(opts)
  opts = vim.tbl_deep_extend("force", {}, M.config, opts or {})
  require("bear.core").visualise_dataframe(opts)
end

return M
