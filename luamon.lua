--[[
MIT License

Copyright (c) 2025 Leonard Mafeni

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]]

--[[
  Requirement: [luafilesystem](https://lunarmodules.github.io/luafilesystem)
]]

local lfs = require("lfs")
local current_time = os.time()
local delay = 2
local last_ran_time = 0

--- For files without extensions or full file_names, an `_` can be used in front of the filename. e.g. `_lua` or `_luamon.lua`
--- Fields `exclude_file_types` and `include_file_types` can not be present at the same time
---@class Config
---@field exclude_file_types? string[] File types to be ignored (e.g., {"lua"})
---@field include_file_types? string[] File types to monitor (e.g., {"txt"})
---@field exclude_dirs? string[] Directories to ignore (relative to root)
---@field recursive? boolean Whether to check subdirectories. Default: true
---@field delay? integer Delay (in seconds) before triggering callback again. Default: 2

---@param root_dir string
---@param file_path string
---@param callback fun(changed_file: string): nil
local function check_modification(root_dir, file_path, callback)
  local attrs = lfs.attributes(file_path)
  if attrs and attrs.modification > current_time then
    current_time = attrs.modification

    local rel_path = file_path:match("^%./") and (lfs.currentdir() .. "/" .. file_path:sub(3)) or file_path
    print(rel_path .. " has been modified")

    if os.time() - last_ran_time >= delay then
      last_ran_time = os.time()
      lfs.chdir(root_dir)
      callback(file_path)
    end
  end
end

---@param path string
---@param patterns string[]
---@return boolean
local function matches_any_pattern(path, patterns)
  for _, pattern in ipairs(patterns) do
    local exact = path:match("^.*%." .. pattern .. "$") or path:match("/" .. pattern:sub(2) .. "$")
    if exact then
      return true
    end
  end
  return false
end

---@param root string
---@param dir string
---@param callback fun(changed_file: string): nil
---@param config? Config
local function check_dir(root, dir, callback, config)
  local recursive = true
  if config and config.recursive then
    assert(type(config.recursive) == "boolean")
    recursive = config.recursive
  end

  for entry in lfs.dir(dir) do
    if entry ~= "." and entry ~= ".." then
      local full_path = dir .. "/" .. entry
      local attrs = lfs.attributes(full_path)

      if attrs then
        if attrs.mode == "directory" then
          local relative_dir = full_path:sub(#root + 2)
          if config and config.exclude_dirs and config.exclude_dirs[relative_dir] then
            goto continue
          end

          if recursive then
            check_dir(root, full_path, callback, config)
          end
        else
          -- Discovered during development, don't know what they actually are or why they would show up randomly
          local skip_bck = full_path:match("%.bck$")
          if skip_bck then
            goto continue
          end

          local should_check = true
          if config then
            assert(
              not (config.include_file_types and config.exclude_file_types),
              "Cannot use both `include_file_types` and `exclude_file_types` in config."
            )

            if config.exclude_file_types then
              should_check = not matches_any_pattern(full_path, config.exclude_file_types)
            elseif config.include_file_types then
              should_check = matches_any_pattern(full_path, config.include_file_types)
            end
          end

          if should_check then
            check_modification(root, full_path, callback)
          end
        end
      end
    end
    ::continue::
  end
end

--[[
  Monitors for file changes in a directory and calls a callback function on any file modification
  NB: This currently does not monitor file name changes as they do not count as file modifications

  Usage:
  ```lua
  local luamon = require("luamon")
  luamon("/absolute/path", function()
    print("Something changed!")
  end)

  -- If the directory is nil, it will use the current directory of the running process
  local luamon = require("luamon")
  luamon(nil, function(changed_file)
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
  luamon(nil, function(changed_file)
    if changed_file then
      print(changed_file .. " has changed")
    end
  end, config)

]]
---@param dir? string Absolute path to directory (defaults to current working directory)
---@param callback fun(changed_file: string?): nil Function to call on file change
---@param config? Config
local function luamon(dir, callback, config)
  if dir then
    assert(dir:match("^/"), "Directory must be an absolute path: '" .. dir .. "'")
  else
    local err
    dir, err = lfs.currentdir()
    assert(dir, err)
  end

  local ok, err = lfs.chdir(dir)
  assert(ok, err)

  last_ran_time = os.time()
  if config and config.delay then
    assert(type(config.delay) == "number")
    delay = config.delay
  end

  callback(nil)

  while true do
    check_dir(dir, dir, callback, config)
  end
end

return luamon
