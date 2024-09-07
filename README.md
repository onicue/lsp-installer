## README.md

# LSP Installer Plugin for Neovim

This plugin simplifies the setup and management of Language Server Protocol (LSP) servers for Neovim, focusing on providing a faster alternative to existing solutions like `mason.nvim` and `mason-lspconfig.nvim`. 

### Problem

The main issue with `mason.nvim` and `mason-lspconfig.nvim` is their slow startup time, particularly when dealing with multiple LSP servers. This plugin addresses that problem by providing a more lightweight and optimized solution for configuring LSP servers.

### Installation

Install the plugin using your preferred package manager:

**Using [packer.nvim](https://github.com/wbthomason/packer.nvim):**

```lua
use 'neovim/nvim-lspconfig'
use 'onicue/lsp-installer'
```

### Setup

Configure the plugin with the LSP servers you need. Here's an example setup:

```lua
require("lsp-installer").setup({
  ensure_installed = {"cmake", "cpp"},  -- List of LSP servers to install
  dir = vim.fn.stdpath("data") .. "/lsp-installer",  -- Installation directory
  servers_dir = "servers",  -- Directory for server configurations
  lsp = {
    ["clangd"] = {
      --your lsp setup
    },
    ["cmake"] = false,  -- Disable the LSP server for cmake
  }
})
```

### License

This plugin is licensed under the MIT License.
