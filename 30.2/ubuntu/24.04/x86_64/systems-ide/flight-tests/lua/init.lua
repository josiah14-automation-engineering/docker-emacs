local utils = require("utils")

local options = {
  number = true,
  relativenumber = true,
  tabstop = 2,
  shiftwidth = 2,
}

for name, value in pairs(options) do
  utils.set_option(name, value)
end

print(utils.greet("systems-ide"))
