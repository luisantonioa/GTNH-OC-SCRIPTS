local internet = require("internet")
local filesystem = require("filesystem")

-- Try to load config from update_config.lua, fallback to defaults
local function load_config()
  local ok, cfg = pcall(dofile, "update_config.lua")
  if ok and type(cfg) == "table" then
    return cfg
  else
    print("Warning: Failed to load update_config.lua, using default config.")
    return {
      repo_owner = "username",
      repo_name = "repo",
      branch = "master",
      manifest_file = "update_list.txt",
    }
  end
end

local config = load_config()

-- Build a raw GitHub URL with cache busting (timestamp)
local function raw_url(file_path)
  return string.format(
    "https://raw.githubusercontent.com/%s/%s/%s/%s?ts=%d",
    config.repo_owner, config.repo_name, config.branch, file_path, os.time()
  )
end

-- Download full content from URL or return nil + error
local function download_url(url)
  local handle, err = internet.request(url)
  if not handle then return nil, err end
  local data = ""
  repeat
    local chunk = handle.read(8192)
    if chunk then data = data .. chunk end
  until not chunk
  handle.close()
  return data
end

-- Download manifest, parse lines (non-empty)
local function get_files_list()
  print("Downloading manifest: "..config.manifest_file)
  local content, err = download_url(raw_url(config.manifest_file))
  if not content then
    error("Failed to download manifest: "..tostring(err))
  end
  local list = {}
  for line in content:gmatch("[^\r\n]+") do
    if line:match("%S") then
      table.insert(list, line)
    end
  end
  return list
end

-- Save file content locally, creating directories if needed
local function save_file(path, content)
  local dir = filesystem.dirname(path)
  if dir ~= "" and not filesystem.exists(dir) then
    filesystem.makeDirectory(dir)
  end
  local f, err = io.open(path, "w")
  if not f then
    return false, err
  end
  f:write(content)
  f:close()
  return true
end

-- Main updater function
local function update()
  local files = get_files_list()
  if #files == 0 then
    print("No files to update.")
    return
  end

  for _, path in ipairs(files) do
    io.write("Downloading "..path.."... ")
    local content, err = download_url(raw_url(path))
    if not content then
      print("Failed: "..tostring(err))
    else
      local ok, save_err = save_file(path, content)
      if ok then
        print("Done.")
      else
        print("Failed to save: "..tostring(save_err))
      end
    end
  end

  print("Update complete.")
end

-- Run the updater
update()
