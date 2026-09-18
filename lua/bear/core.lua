local M = {}

local dap = require("dap")

local Mode = {
  FLOAT = "float",
  BUFFER = "buffer"
}

local function save_dataframe_py_expr(df_var, path, custom_python_logic)
  return string.format([[
try:
    from pathlib import Path
    try:
        import polars as pl
        polars_imported = True
    except ImportError:
        polars_imported = False
    try:
        import pandas as pd
        pandas_imported = True
    except ImportError:
        pandas_imported = False

    if not (polars_imported or pandas_imported):
        raise Exception('Neither polars nor pandas imported (missing or error on import).')

    var_name: str = "%s"
    file_path: str = "%s"

    df_var = eval(var_name)

    if pandas_imported and isinstance(df_var, (pd.DataFrame, pd.Series)):
        df_var.to_csv(file_path, index=True)
    elif polars_imported and isinstance(df_var, pl.DataFrame):
        df_var.write_csv(file_path)
    elif polars_imported and isinstance(df_var, pl.LazyFrame):
        df_var.collect().write_csv(file_path)

    %s

    if Path(file_path).exists():
        print(f"SUCCESS: DataFrame saved to {file_path}")
except Exception as e:
    print("ERROR: " + str(e))
]],
    df_var,
    path,
    custom_python_logic
  )
end
function M.show_py_expr(custom_python_logic)
  print(save_dataframe_py_expr('<DF>', '<PATH>', custom_python_logic))
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
  vim.api.nvim_buf_set_keymap(buf, 't', opts.keymap.exit_terminal_mode, '<C-\\><C-n>', { noremap = true })

  vim.keymap.set("n", "q", function()
    if opts.remove_file then
      vim.fn.system("rm -f " .. path)
    end
    vim.cmd("q")
  end, { noremap = true, silent = true, buffer = buf })

  vim.fn.jobstart("visidata " .. path, {
    term = true,
    on_exit = function()
      if opts.remove_file then
        vim.fn.system("rm -f " .. path)
      end
      vim.api.nvim_buf_delete(buf, { unload = true })
    end
  })
  vim.cmd("startinsert")
end

local function show_in_new_buffer(opts, path)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, "VisiData: " .. path)
  vim.api.nvim_set_option_value('buflisted', true, { buf = 0 })
  local current_buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_set_current_buf(buf)
  vim.api.nvim_buf_set_keymap(buf, 't', opts.keymap.exit_terminal_mode, '<C-\\><C-n>', { noremap = true })

  vim.keymap.set("n", "q", function()
    vim.fn.system("rm -f " .. path)
    vim.cmd("bp | bd! #")
  end, { noremap = true, silent = true, buffer = buf })


  vim.fn.jobstart("visidata " .. path, {
    term = true,
    on_exit = function()
      vim.fn.system("rm -f " .. path)
      vim.api.nvim_set_current_buf(current_buf)
      if vim.api.nvim_get_mode().mode == "t" then
        vim.api.nvim_buf_delete(buf, { unload = true })
      end
    end
  })
  vim.cmd("startinsert")
end

--- Evaluates a DataFrame expression in the active debug session and shows it in VisiData.
---@param opts table Plugin config (cache_dir, file_name, window, keymap, ...).
---@param mode "float"|"buffer" Where to display the VisiData output.
function M.visualise_dataframe(opts, mode)
  opts = opts or {}
  vim.fn.system("mkdir -p " .. opts.cache_dir)
  local session = dap.session()
  if not session then
    vim.notify("No active debug session", vim.log.levels.ERROR)
    return
  end

  local df_var = require('bear.utils').get_visual_selection()
  if df_var == "" then
    df_var = vim.fn.expand("<cword>")
    if df_var == "" then
      df_var = vim.fn.input("Enter dataframe variable name: ")
      if df_var == "" then
        vim.notify("No variable specified", vim.log.levels.WARN)
        return
      end
    end
  end

  local df_path = vim.fn.expand(opts.cache_dir .. "/" .. opts.file_name)

  local expr = save_dataframe_py_expr(df_var, df_path, opts.custom_python_logic)

  session:evaluate(expr, function(err, _)
    if err then
      vim.notify("Evaluation error: " .. vim.inspect(err), vim.log.levels.ERROR)
      return
    end
    if vim.fn.filereadable(df_path) == 1 then
      if mode == Mode.BUFFER then
        show_in_new_buffer(opts, df_path)
      end
      if mode == Mode.FLOAT then
        show_floating_window(opts, df_path)
      end
    else
      vim.notify("Failed to export DataFrame.", vim.log.levels.ERROR)
    end
  end)
end

return M
