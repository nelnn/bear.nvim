local M = {}

M.config = {
  cache_dir = "~/.cache/nvim/bear",
  file_name = "tmp_" .. os.date("%m%d_%H%M%S") .. ".csv",
  remove_file = true,
  window = {
    width = 0.9,
    height = 0.8,
    border = "rounded",
  },
  keymap = {
    visualise = "<leader>df",
    visualise_buf = "<leader>bdf",
    exit_terminal_mode = "<C-o>",
  }
}

function M.setup(opts)
  opts = vim.tbl_deep_extend("force", {}, M.config, opts or {})

  if opts.custom_python_logic ~= nil then
    -- wrap custom_python_logic, to make it more visible when user executes `DFCode`
    local tweaked_custom_python_logic = string.format([[

# --- custom_python_logic ------------

%s
# ------------------------------------
]], opts.custom_python_logic)
    -- Indent every line but the first by 4 spaces to match the surrounding
    -- try/except block's nesting level once spliced into the Python snippet.
    local logic_per_line = vim.fn.split(tweaked_custom_python_logic, '\\n')
    for i = 2, #logic_per_line do
      logic_per_line[i] = string.rep(' ', 4) .. logic_per_line[i]
    end
    opts.custom_python_logic = table.concat(logic_per_line, '\n')
  else
    opts.custom_python_logic = ''
  end

  vim.api.nvim_create_user_command("DFView", function()
    require("bear.core").visualise_dataframe(opts, "float")
  end, { desc = "Visualise DataFrame in floating window under cursor" })

  vim.api.nvim_create_user_command("DFViewBuf", function()
    require("bear.core").visualise_dataframe(opts, "buffer")
  end, { desc = "Visualise DataFrame in new buffer under cursor" })

  vim.api.nvim_create_user_command("DFClean", function()
    require("bear.utils").clean_cache(opts)
  end, { desc = "Clean cache directory" })

  vim.api.nvim_create_user_command("DFCode", function()
    require("bear.core").show_py_expr(opts.custom_python_logic)
  end, { desc = "Show Python code for debugging `custom_python_logic`." })

  vim.keymap.set({ "n", "v" }, opts.keymap.visualise,
    function() require("bear.core").visualise_dataframe(opts, "float") end,
    { desc = "Visualise DataFrame in floating window" })

  vim.keymap.set({ "n", "v" }, opts.keymap.visualise_buf,
    function() require("bear.core").visualise_dataframe(opts, "buffer") end,
    { desc = "Visualise DataFrame in new buffer" })
end

M.visualise = function(opts)
  opts = vim.tbl_deep_extend("force", {}, M.config, opts or {})
  require("bear.core").visualise_dataframe(opts)
end

return M
