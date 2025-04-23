local M = {}

local dap = require("dap")

local function save_dataframe_py_expr(df_var, path)
  return string.format([[
      try:
          from pathlib import Path
          try:
              import polars as pl
              polars = True
          except ImportError:
            polars = False
          try:
              import pandas as pd
              pandas = True
          except ImportError:
              pandas = False
          if '%s' not in locals() and '%s' not in globals():
              print("ERROR: Variable '%s' not found")
              exit()
          df_var = %s
          if pandas and isinstance(df_var, pd.DataFrame):
              df_var.to_csv('%s', index=True)
          if polars and isinstance(df_var, pl.DataFrame):
              df_var.write_csv('%s')
          if polars and isinstance(df_var, pl.LazyFrame):
              df_var.collect().write_csv('%s')
          if Path('%s').exists():
              print("SUCCESS: DataFrame saved to %s")
      except Exception as e:
          print("ERROR: " + str(e))
  ]], df_var, df_var, df_var, df_var, path, path, path, path, path)
end

local function show_floating_window(opts, path)
  local width = math.floor(vim.o.columns * opts.window.width)
  local height = math.floor(vim.o.lines * opts.window.height)
  local buf = vim.api.nvim_create_buf(false, true)

  local _ = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
    style = "minimal",
    border = "rounded"
  })

  vim.fn.termopen("visidata " .. path, {
    on_exit = function()
      vim.fn.system("rm -f " .. path)
    end
  })
  vim.cmd("startinsert")
end

function M.visualise_dataframe(opts)
  opts = opts or {}
  vim.fn.system("mkdir -p " .. opts.cache_dir)
  local session = dap.session()
  if not session then
    vim.notify("No active debug session", vim.log.levels.ERROR)
    return
  end

  local df_var = vim.fn.expand("<cword>")
  if df_var == "" then
    df_var = vim.fn.input("Enter dataframe variable name: ")
    if df_var == "" then
      vim.notify("No variable specified", vim.log.levels.WARN)
      return
    end
  end

  local df_path = vim.fn.expand(opts.cache_dir .. "/" .. opts.file_name)

  local expr = save_dataframe_py_expr(df_var, df_path)

  session:evaluate(expr, function(err, _)
    if err then
      vim.notify("Evaluation error: " .. vim.inspect(err), vim.log.levels.ERROR)
      return
    end
    if vim.fn.filereadable(df_path) == 1 then
      show_floating_window(opts, df_path)
    else
      vim.notify("Failed to export DataFrame.", vim.log.levelsgERROR)
    end
  end)
end

return M
