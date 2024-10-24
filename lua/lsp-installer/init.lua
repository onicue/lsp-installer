local M = {}
local lsp = require("lspconfig")

M.opts = {
  ensure_installed = {},
  dir = vim.fn.stdpath("data") .. "/lsp-installer",
  servers_dir = "servers",
  lsp = {},
}

M.installed = {}

local function get_pkg_dir()
  return M.opts.dir .. "/packages"
end

local function get_bin_dir()
  return M.opts.dir .. "/bin"
end

local function get_server(server)
  if type(server) == "table" then
    return server
  elseif type(server) == "string" then
    return require(M.opts.servers_dir .. "." .. server)
  else
    error(("[lsp-installer] %s must be a table or a string"):format(server))
  end
end

M.is_server_installed = function(name)
  local server_name = get_server(name).name
  return vim.fn.isdirectory(get_pkg_dir() .. "/" .. server_name) == 1
end

local function get_files_in_dir(dir)
  local files = vim.fn.readdir(dir)
  local t = {}
  for i, filename in ipairs(files) do
    t[i] = filename:gsub("%.%w+$", "")
  end
  return t
end

M.get_installed_packages = function()
  local t = {}
  for _, filename in ipairs(vim.fn.readdir(get_bin_dir())) do
    t[filename] = true
  end
  return t
end

local function check_lsp_file(path)
  local stat = vim.loop.fs_stat(path)
  return stat and stat.type == 'file' and vim.fn.executable(path) == 1 and path or nil
end

local function check_executable(path, name)
  local bin_path = path .. "/bin/" .. name
  local alt_path = path .. "/" .. name

  local result = check_lsp_file(bin_path)
  if result then
    return result
  end

  result = check_lsp_file(alt_path)
  if result then
    return result
  end

  return nil -- if not found
end

local function create_symlink(target, link)
  if vim.fn.empty(link) == 0 then
    vim.fn.delete(link)
  end
  local success = vim.fn.system(string.format('ln -s %s %s', target, link))
  if success ~= "" then
    error("[lsp-installer] Failed to create symlink: " .. success)
  end
end

local function do_symlink(server)
  local name = server.name
  local server_link_addr = get_bin_dir() .. "/" .. name
  local server_bin_addr = server.bin or check_executable(get_pkg_dir() .. "/" .. name, name)

  if server_bin_addr and server_link_addr then
    create_symlink(server_bin_addr, server_link_addr)
  else
    if not server_bin_addr then
      error("[lsp-installer] Cannot find " .. server_bin_addr .. ".")
    end
    if not server_link_addr then
      error("[lsp-installer] Cannot find " .. server_link_addr .. ".")
    end
  end
end

M.install = function(server, callback)
  local server = get_server(server)

  local name = server.name
  local path = get_pkg_dir() .. "/" .. name

  vim.fn.mkdir(path, "p")
  vim.notify("[lsp-install] Starting installation for " .. name)

  local function onExit(_, code)
    vim.schedule(function()
      if code ~= 0 then
        vim.fn.delete(path, "rf")
        vim.notify("[lsp-installer] Failed to install language server for " .. name, vim.log.levels.ERROR)
      else
        vim.notify("[lsp-install] Successfully installed language server for " .. name, vim.log.levels.INFO)
        if server.install_hook then
          server.install_hook()
        end
        if callback then
          callback(server)
        end

        do_symlink(server)
      end
    end)
  end

  local handle
  handle = vim.loop.spawn(vim.o.shell, {
    args = { "-c", "set -e\n" .. server.install_script },
    cwd = path,
  }, function(code, signal)
    onExit(code, signal)
    handle:close()
  end)

  if not handle then
    error("[lsp-installer] Failed to start installation process.")
    return
  end
end

M.delete = function(server)
  local server = get_server(server)

  if server.delete then
    server.delete()
  else
    local name = server.name
    vim.fn.delete(get_bin_dir() .. "/" .. name)
    vim.fn.delete(get_pkg_dir() .. "/" .. name, "rf")
  end
end

M.init = function()
  local function check_and_create_dir(name)
    if not vim.fn.isdirectory(name) then
      vim.fn.mkdir(name, "p")
    end
  end

  check_and_create_dir(M.opts.dir)
  check_and_create_dir(get_bin_dir())
  check_and_create_dir(get_pkg_dir())

  vim.env.PATH = get_bin_dir() .. ":" .. vim.env.PATH
end

M.run_lsp = function(server)
  local name = server.alias or server.name

  if not M.opts.lsp[name] then
    if not M.opts.lsp["default"] then
      lsp[name].setup{}
    else
      lsp[name].setup(M.opts.lsp["default"])
    end
  else
    if M.opts.lsp[name] then
      lsp[name].setup(M.opts.lsp[name])
    end
  end
end

M.setup = function(opts)
  if opts then
    for key, value in pairs(opts) do
      M.opts[key] = value
    end
  end

  M.init()
  M.installed = M.get_installed_packages()
  local ensure_installed = M.opts.ensure_installed

  if ensure_installed == "all" then
    ensure_installed = get_files_in_dir(vim.fn.stdpath("config") .. "/lua/" .. M.opts.servers_dir:gsub("%.", "/"))
  end

  local servers = {}
  for _, name in pairs(ensure_installed) do
    servers[name] = require(M.opts.servers_dir .. "." .. name)
  end

  for _, server in pairs(servers) do
    if M.installed[server.name] ~= true then
      M.install(server, function(installed_server)
        M.run_lsp(installed_server)
      end)
    else
      M.run_lsp(server)
    end
  end
end

return M
