vim.opt.runtimepath:prepend(vim.fn.getcwd())

local root = vim.fn.tempname() .. " bear cache ';$"
local opts = vim.tbl_deep_extend("force", {}, require("bear").config, { cache_dir = root })
local utils = require("bear.utils")
local exporter = require("bear.export")
local notices = {}
-- Keep mock signatures compatible: LuaLS also sees these global assignments.
vim.notify = function(message, _level, _options)
  notices[#notices + 1] = message
end

local function response(value)
  return { result = "'BEAR_NVIM:" .. vim.base64.encode(vim.json.encode(value)) .. ":END'" }
end

local path = utils.export_path(opts)
assert(path ~= utils.export_path(opts), "Exports must have unique filenames")
utils.write_file(path, "id,text\r\n1,雪\r\n")
assert(vim.fn.filereadable(path) == 1)
local decoded = exporter.decode(response({ ok = true, transport = "dap", csv = "id\n1\n" }))
assert(decoded.csv == "id\n1\n")
assert(not pcall(exporter.decode, { result = "BEAR_NVIM:truncated..." }))
assert(not pcall(exporter.decode, response({ ok = false, error = "Unsupported frame" })))
assert(not pcall(exporter.decode, response({ ok = true, transport = "dap" })))

-- No DAP or visidata process is needed to exercise the real export callback.
local evaluate_args
local export_response = response({ ok = true, transport = "dap", csv = "id,text\r\n1,雪\r\n" })
local evaluation_error
local active = true
package.preload["dap"] = function()
  return {
    session = function()
      if not active then
        return nil
      end
      return {
        evaluate = function(_, args, callback)
          evaluate_args = args
          callback(evaluation_error, export_response)
        end,
      }
    end,
  }
end
local actual_executable = vim.fn.executable
vim.fn.executable = function(_expr) return 1 end
local opened
package.loaded["bear.view"] = {
  open = function(options, csv_path, mode)
    opened = { options = options, path = csv_path, mode = mode }
  end,
}
require("bear").setup(opts)
vim.cmd("DFView frames['quoted']")
assert(vim.wait(1000, function() return opened ~= nil end))
assert(evaluate_args.expression:find("frames['quoted']", 1, true))
assert(evaluate_args.format.rawString, "Large DAP strings must not use truncated repr")
assert(opened.mode == "float")
assert(vim.fn.filereadable(opened.path) == 1)
assert(table.concat(vim.fn.readfile(opened.path, "b"), "\n") == "id,text\r\n1,雪\r\n")
local first_path = opened.path
opened = nil
require("bear").visualise(nil, "buffer", "df")
assert(vim.wait(1000, function() return opened ~= nil end))
assert(opened.mode == "buffer" and opened.path ~= first_path)
assert(opened.options.cache_dir == root, "Public visualise must use setup options")

-- Preserve upstream's visual mappings and selection-first expression lookup.
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "frames['quoted']" })
for _, binding in ipairs({
  { opts.keymap.visualise, "float" }, { opts.keymap.visualise_buf, "buffer" },
}) do
  opened = nil
  vim.cmd("normal! gg0v$")
  local mapping = vim.fn.maparg(binding[1], "v", false, true)
  assert(type(mapping.callback) == "function", "Visual keymap must remain available")
  mapping.callback()
  assert(vim.wait(1000, function() return opened ~= nil end))
  assert(opened.mode == binding[2])
  assert(evaluate_args.expression:find("frames['quoted']", 1, true))
  assert(utils.get_visual_selection() == "", "Stale visual marks must not override the cursor")
end

opened = nil
evaluation_error = { message = "missing variable" }
local before = #notices
require("bear.core").visualise_dataframe(opts, "float", "missing")
assert(vim.wait(1000, function() return #notices > before end))
assert(not opened)
assert(notices[#notices]:find("missing variable", 1, true))
evaluation_error = nil
export_response = response({ ok = false, error = "Spark job failed" })
before = #notices
require("bear.core").visualise_dataframe(opts, "float", "df")
assert(vim.wait(1000, function() return #notices > before end))
assert(not opened and notices[#notices]:find("Spark job failed", 1, true))
active = false
require("bear.core").visualise_dataframe(opts, "float", "df")
assert(notices[#notices] == "No active debug session")
vim.fn.executable = actual_executable

-- Exercise both real views, sharing lifecycle logic but stubbing the process.
package.loaded["bear.view"] = nil
local view = require("bear.view")
local actual_jobstart = vim.fn.jobstart
local job_args, job_opts
vim.fn.jobstart = function(args, options)
  job_args, job_opts = args, options
  return 42
end
for _, mode in ipairs({ "float", "buffer" }) do
  for _, remove in ipairs({ true, false }) do
    local options = vim.tbl_deep_extend("force", {}, opts, {
      remove_file = remove, window = { border = "single" },
    })
    local csv_path = utils.export_path(options)
    utils.write_file(csv_path, "id\n1\n")
    local previous = vim.api.nvim_get_current_buf()
    view.open(options, csv_path, mode)
    local buf = vim.api.nvim_get_current_buf()
    assert(job_args[1] == "visidata" and job_args[2] == csv_path and #job_args == 2)
    assert(vim.bo[buf].buflisted == (mode == "buffer"))
    if mode == "float" then
      assert(vim.api.nvim_win_get_config(0).border[1] == "┌", "Configured border must be used")
    end
    job_opts.on_exit()
    assert(vim.wait(1000, function() return not vim.api.nvim_buf_is_valid(buf) end))
    assert(vim.fn.filereadable(csv_path) == (remove and 0 or 1))
    assert(vim.api.nvim_get_current_buf() == previous)
    job_opts.on_exit() -- Late/repeated exits should be harmless.
    vim.wait(20, function() return false end)
  end
end
-- A buffer view survives switching buffers; its exit must not steal focus.
local hidden_path = utils.export_path(opts)
utils.write_file(hidden_path, "id\n")
local original = vim.api.nvim_get_current_buf()
view.open(opts, hidden_path, "buffer")
local hidden_buf = vim.api.nvim_get_current_buf()
vim.api.nvim_set_current_buf(original)
assert(vim.api.nvim_buf_is_valid(hidden_buf) and vim.fn.filereadable(hidden_path) == 1)
job_opts.on_exit()
assert(vim.wait(1000, function() return not vim.api.nvim_buf_is_valid(hidden_buf) end))
assert(vim.api.nvim_get_current_buf() == original)
assert(vim.fn.filereadable(hidden_path) == 0)

-- Manual buffer wipe must also honour cleanup settings.
local manual_path = utils.export_path(opts)
utils.write_file(manual_path, "id\n")
view.open(opts, manual_path, "buffer")
vim.api.nvim_buf_delete(0, { force = true })
assert(vim.fn.filereadable(manual_path) == 0)
job_opts.on_exit()
vim.wait(20, function() return false end)
vim.fn.jobstart = actual_jobstart

local actual_input = vim.fn.input
vim.fn.input = function(_prompt) return "y" end
utils.clean_cache(opts)
assert(#vim.fn.readdir(root) == 0, "Cache paths with shell characters must be handled literally")
vim.fn.input = actual_input
vim.fn.delete(root, "rf")
print("bear.nvim Lua tests passed")
