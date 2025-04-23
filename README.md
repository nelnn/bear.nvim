# 📊 `visidataframe.nvim`

A neovim plugin for debugging `pandas` and `polars` DataFrames.

https://github.com/user-attachments/assets/55e22539-9938-4b48-9ec5-b1b6a43b976b


## ⚡️ Requirements

- [nvim-dap](https://github.com/mfussenegger/nvim-dap)
- [visidata](https://www.visidata.org/install/) installed globally.
- [polars](https://github.com/pola-rs/polars) and/or
  [pandas](https://github.com/pandas-dev/pandas) installed in your virtual
  environment.

## Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "nelnn/visidataframe.nvim",
  dependencies = {
    "mfussenegger/nvim-dap",
  },

  -- Default Configuration
  opts = {
      cache_dir = "~/.cache/nvim/visidataframe",
      file_name = "df_debug" .. os.time() .. ".csv",
      window = {
        width = 0.9,
        height = 0.8,
        border = "rounded"
      },
      keymap = {
        visualise = "<Leader>df"
      }
  },

  config = function(_, opts)
    local df_visidata = require("visidataframe")
    df_visidata.setup(opts)
  end,

  ft = { "python" },
}

```

## 🚀 Usage
- Use `<leader>df` to view the dataframe under the cursor as shown in the demo.
- Use `<leader>df` in the repl session and input the dataframe variable.
- Call `DFView` and input the dataframe variable.

You can see my debugging setup [here](https://github.com/nelnn/dotfiles/blob/main/.config/nvim/lua/plugins/debugging.lua).


> [!NOTE]
> I am not knowledgeable in lua. PRs for code refactor and new features are more than welcome.
