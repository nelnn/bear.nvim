local M = {}

local source_path = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h:h")
  .. "/python/bear_export.py"
local encoded_source

function M.expression(df_expression, path, opts)
  if not encoded_source then
    encoded_source = vim.base64.encode(table.concat(vim.fn.readfile(source_path), "\n"))
  end
  local options = vim.base64.encode(vim.json.encode({
    path = path,
    transport = opts.export_transport,
    spark_max_rows = opts.spark.max_rows,
    max_transfer_bytes = opts.max_transfer_bytes,
  }))

  -- Evaluate the user's expression in the paused frame, but keep all helper
  -- variables/imports isolated from that frame's globals and locals.
  return string.format(
    "(lambda _bear_df, _bear_ns: ("
      .. "__import__('builtins').exec(__import__('base64').b64decode('%s'), _bear_ns), "
      .. "_bear_ns['export_dataframe'](_bear_df, "
      .. "__import__('json').loads(__import__('base64').b64decode('%s')))"
      .. ")[1])((%s), {})",
    encoded_source, options, df_expression
  )
end

function M.decode(response)
  local result = response and response.result
  local payload = type(result) == "string" and result:match("BEAR_NVIM:([A-Za-z0-9+/=]+):END")
  if not payload then
    error("Missing or truncated export response. Reduce spark.max_rows or use a shared filesystem.")
  end
  local decoded = vim.json.decode(vim.base64.decode(payload))
  if not decoded.ok then
    error(decoded.error or "DataFrame export failed", 0)
  end
  if decoded.transport ~= "dap" and decoded.transport ~= "file" then
    error("Invalid export transport in debug adapter response")
  end
  if decoded.transport == "dap" and type(decoded.csv) ~= "string" then
    error("Missing CSV in debug adapter response")
  end
  return decoded
end

return M
