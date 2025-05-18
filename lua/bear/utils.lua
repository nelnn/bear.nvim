local M = {}

function M.clean_cache(opts)
  local answer = vim.fn.input("Clear cache? (y/n): ")
  if answer == "y" or answer == "Y" then
    vim.fn.system("rm -f " .. opts.cache_dir .. "/*")
    vim.notify("Cache cleared", vim.log.levels.INFO)
  end
end

return M
