local component = require("component")
local internet = require("internet")
local filesystem = require("filesystem")

-- Config: edit these
local repo_owner = "luisantonioa"
local repo_name = "GTNH-OC-SCRIPTS"
local branch = "main"
local manifest_file = "manifest.txt"

-- Download URL helper with cache bust (timestamp)
local function raw_url(file_path)
  return string.format(
    "https://raw.githubusercontent.com/%s/%s/%s/%s?ts=%d",
    repo_owner, repo_name, branch, file_path, os.time()
  )
end

-- Download file content from URL
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

-- Main update function
local function update_files()
  print("Downloading manifest: "..manifest_file)
  local manifest_url = raw_url(manifest_file)
  local manifest_content, err = download_url(manifest_url)
  if not manifest_content then
    print("Error downloading manifest: "..err)
    return
  end

  local files = {}
  for line in manifest_content:gmatch("[^\r\n]+") do
    if line:match("%S") then
      table.insert(files, line)
    end
  end

  if #files == 0 then
    print("Manifest empty or no files listed.")
    return
  end

  for _, file_path in ipairs(files) do
    io.write("Downloading "..file_path.."... ")
    local file_url = raw_url(file_path)
    local content, err = download_url(file_url)
    if not content then
      print("Failed: "..err)
    else
      -- Ensure directory exists
      local dir = filesystem.dirname(file_path)
      if dir ~= "" and not filesystem.exists(dir) then
        filesystem.makeDirectory(dir)
      end

      local file = io.open(file_path, "w")
      if not file then
        print("Failed to open file for writing.")
      else
        file:write(content)
        file:close()
        print("Done.")
      end
    end
  end

  print("Update complete.")
end

update_files()
