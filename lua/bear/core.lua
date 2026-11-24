local M = {}

--- Evaluates a DataFrame/Series expression in the active debug session and shows it in VisiData.
---@param opts table Plugin config (cache_dir, file_name, window, keymap, ...).
---@param mode "float"|"buffer" Where to display the VisiData output.
---@param expression? string Explicit expression, otherwise use the selection or cursor.
function M.visualise_dataframe(opts, mode, expression)
  local session = require("dap").session()
  if not session then
    vim.notify("No active debug session", vim.log.levels.ERROR)
    return
  end
  if vim.fn.executable("visidata") ~= 1 then
    vim.notify("visidata is not installed or not on PATH", vim.log.levels.ERROR)
    return
  end

  local utils = require("bear.utils")
  if not expression or expression == "" then
    expression = utils.get_visual_selection()
    if expression == "" then
      expression = vim.bo.filetype ~= "dap-repl" and vim.fn.expand("<cword>") or ""
    end
    if expression == "" then
      expression = vim.fn.input("Enter dataframe expression: ")
    end
  end
  if expression:match("^%s*$") then
    vim.notify("No variable specified", vim.log.levels.WARN)
    return
  end

  local exporter = require("bear.export")
  local ok, path = pcall(utils.export_path, opts)
  if not ok then
    vim.notify("Cannot create export path: " .. tostring(path), vim.log.levels.ERROR)
    return
  end
  local expr = exporter.expression(expression, path, opts)

  session:evaluate({
    expression = expr,
    context = "repl",
    -- debugpy's rawString extension avoids its normal string repr truncation.
    format = { rawString = true },
  }, vim.schedule_wrap(function(err, response)
    local success, failure = pcall(function()
      if err then
        error("Evaluation error: " .. vim.inspect(err), 0)
      end
      local result = exporter.decode(response)
      if result.transport == "dap" then
        utils.write_file(path, result.csv)
      end
      if vim.fn.filereadable(path) ~= 1 then
        error("Export file is not accessible locally. Use export_transport='dap' for remote sessions.", 0)
      end
      require("bear.view").open(opts, path, mode or "float")
    end)
    if not success then
      vim.fn.delete(path)
      vim.notify("Failed to export DataFrame: " .. tostring(failure), vim.log.levels.ERROR)
    end
  end))
end

return M
