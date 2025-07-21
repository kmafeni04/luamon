# fidimon (FIle DIrectory MONitor)

Monitors file changes in a directory and calls a callback function on any file modification\
**NB**: This currently does not monitor file name changes as they do not count as file modifications

## Requirement
- [luafilesystem](https://lunarmodules.github.io/luafilesystem)

## How to install
Copy `fidimon.lua` into your project and require it

## Usage:
```lua
local fidimon = require("fidimon")
fidimon("/absolute/path", function()
  print("Something changed!")
end)

-- If the directory is nil, it will use the current directory of the running process
local fidimon = require("fidimon")
fidimon(nil, function(changed_file)
  if changed_file then
    print(changed_file .. " has changed")
  end
end)

-- A third parameter `config` can be passed to customise how the monitoring behaves
local config = {
  exclude_file_types = { "log", "_temp.lua" },
  exclude_dirs = { "build", "vendor" },
  recursive = true,
  delay = 4
}
fidimon(nil, function(changed_file)
  if changed_file then
    print(changed_file .. " has changed")
  end
end, config)
```

## Acknowledgement

- Thank you stefanos82 on the [nelua discord](https://discord.gg/7aaGeG7) for the name
- Originally called luamon but found out that project existed [here](https://github.com/edubart/luamon)
