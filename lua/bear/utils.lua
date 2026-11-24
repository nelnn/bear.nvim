local M = {}

--- Returns the text spanned by the last visual selection (the '< / '> marks).
--- Supports charwise, linewise and blockwise selections; multi-line selections
--- are joined with a single space so the result is usable as one expression.
---@return string selection The selected text, or "" if no selection is active.
function M.get_visual_selection()
  -- The '< / '> marks stick around from the *last* visual selection even after
  -- leaving Visual mode, so only trust them while a selection is actually live.
  local mode = vim.fn.mode()
  if mode ~= "v" and mode ~= "V" and mode ~= "\22" then
    return ""
  end

  -- To use the `'<` and `'>` marks, we have to leave Visual mode.
  vim.cmd('normal! ' .. vim.api.nvim_replace_termcodes('<ESC>', true, false, true))
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local start_line, start_col = start_pos[2], start_pos[3]
  local end_line, end_col = end_pos[2], end_pos[3]

  local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
  if #lines == 0 then
    return ""
  end

  -- Trim the first/last line to the selected columns; string.sub clamps
  -- out-of-range end columns (e.g. linewise selections use maxcol) safely.
  if #lines == 1 then
    lines[1] = string.sub(lines[1], start_col, end_col)
  else
    lines[1] = string.sub(lines[1], start_col)
    lines[#lines] = string.sub(lines[#lines], 1, end_col)
  end

  -- join with " " to have a one line python expression
  print(table.concat(lines, " "))
  return table.concat(lines, " ")
end

function M.export_path(opts)
  local dir = vim.fn.expand(opts.cache_dir)
  vim.fn.mkdir(dir, "p")
  if vim.fn.isdirectory(dir) ~= 1 then
    error("Not a directory: " .. dir)
  end
  if opts.file_name == "" or opts.file_name:find("[/\\]") then
    error("file_name must be a filename, not a path")
  end
  local stem, extension = opts.file_name:match("^(.*)(%.[^.]+)$")
  stem, extension = stem or opts.file_name, extension or ".csv"
  -- A separate file per request avoids stale data and concurrent view races.
  return string.format("%s/%s_%d_%d%s", dir, stem, vim.fn.getpid(), vim.uv.hrtime(), extension)
end

function M.write_file(path, content)
  local file, err = io.open(path, "wb")
  if not file then
    error(err, 0)
  end
  local ok, write_err = file:write(content)
  local closed, close_err = file:close()
  if not ok or not closed then
    error(write_err or close_err, 0)
  end
end

function M.clean_cache(opts)
  local answer = vim.fn.input("Clear cache? (y/n): ")
  if answer ~= "y" and answer ~= "Y" then
    return
  end
  local dir = vim.fn.expand(opts.cache_dir)
  if vim.fn.isdirectory(dir) == 1 then
    for _, name in ipairs(vim.fn.readdir(dir)) do
      local path = dir .. "/" .. name
      local kind = vim.fn.getftype(path)
      if kind == "file" or kind == "link" then
        if vim.fn.delete(path) ~= 0 then
          vim.notify("Could not remove " .. path, vim.log.levels.ERROR)
          return
        end
      end
    end
  end
  vim.notify("Cache cleared", vim.log.levels.INFO)
end

return M
