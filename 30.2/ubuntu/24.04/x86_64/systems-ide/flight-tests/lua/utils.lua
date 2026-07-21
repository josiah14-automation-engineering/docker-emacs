local M = {}

function M.set_option(name, value)
  print(string.format("vim.opt.%s = %s", name, tostring(value)))
end

function M.greet(name)
  return "Hello from Lua, " .. name .. "!"
end

return M
