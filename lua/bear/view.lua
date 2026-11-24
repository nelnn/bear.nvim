local M = {}

function M.open(opts, path, mode)
  local previous_buf = vim.api.nvim_get_current_buf()
  local buf = vim.api.nvim_create_buf(mode == "buffer", true)
  vim.bo[buf].bufhidden = mode == "buffer" and "hide" or "wipe"
  local win
  local closed = false

  local function cleanup()
    if opts.remove_file then
      vim.fn.delete(path)
    end
  end

  local function close()
    if closed then
      return
    end
    closed = true
    cleanup()
    if win and vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == buf then
      vim.api.nvim_win_close(win, true)
    elseif vim.api.nvim_get_current_buf() == buf and vim.api.nvim_buf_is_valid(previous_buf) then
      vim.api.nvim_set_current_buf(previous_buf)
    end
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end

  vim.api.nvim_create_autocmd("BufWipeout", { buffer = buf, once = true, callback = cleanup })
  if mode == "buffer" then
    vim.api.nvim_buf_set_name(buf, "VisiData: " .. path)
    vim.api.nvim_set_current_buf(buf)
  else
    local width = math.max(1, math.floor(vim.o.columns * opts.window.width))
    local height = math.max(1, math.floor(vim.o.lines * opts.window.height))
    win = vim.api.nvim_open_win(buf, true, {
      relative = "editor",
      width = width,
      height = height,
      col = math.max(0, math.floor((vim.o.columns - width) / 2)),
      row = math.max(0, math.floor((vim.o.lines - height) / 2)),
      style = "minimal",
      border = opts.window.border,
    })
  end

  vim.keymap.set("t", opts.keymap.exit_terminal_mode, "<C-\\><C-n>", { buffer = buf, noremap = true })
  vim.keymap.set("n", "q", close, { buffer = buf, silent = true })

  local job = vim.fn.jobstart({ "visidata", path }, {
    term = true,
    on_exit = function()
      vim.schedule(close)
    end,
  })
  if job <= 0 then
    close()
    error("Failed to start visidata")
  end
  vim.cmd("startinsert")
end

return M
