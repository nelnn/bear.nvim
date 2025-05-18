# 🐼`bear.nvim`🐻‍❄️

A neovim plugin for debugging `pandas` and `polars` DataFrames.

> This plugin is under active development. Expect breaking changes.

https://github.com/user-attachments/assets/55e22539-9938-4b48-9ec5-b1b6a43b976b


## ⚡️ Requirements

- [nvim-dap](https://github.com/mfussenegger/nvim-dap)
- [visidata](https://www.visidata.org/install/) installed globally.
- [polars](https://github.com/pola-rs/polars) and/or
  [pandas](https://github.com/pandas-dev/pandas) installed in your virtual
  environment.

## 📦 Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "nelnn/bear.nvim",
  dependencies = {
    "mfussenegger/nvim-dap",
  },
}
```


<details>
<summary>Default Confguration</summary>

```lua
{
  "nelnn/bear.nvim",
  dependencies = {
    "mfussenegger/nvim-dap",
  },
  opts = {
      cache_dir = "~/.cache/nvim/bear",
      file_name = "df_debug_" .. os.time() .. ".csv",
      window = {
        width = 0.9,
        height = 0.8,
        border = "rounded"
      },
      keymap = {
        visualise = "<Leader>df",
        visualise_buf = "<leader>dfb",
        exit_terminal_mode = "<C-o>",
      }
  },

  config = function(_, opts)
    local df_visidata = require("bear")
    df_visidata.setup(opts)
  end,

  ft = { "python" },
}

```
</details>

## 🚀 Usage (with default keymaps)
- `<leader>df`/`<leader>dfb` to view the dataframe under the cursor.
- `<leader>df`/`<leader>dfb` in the repl session and input the dataframe variable.
- `<C-o>` to exit from terminal to normal mode and `i` to enter.
- `q` to close floating window or buffer in normal and terminal mode.

You can see my debugging setup [here](https://github.com/nelnn/dotfiles/blob/main/.config/nvim/lua/plugins/debugging.lua).

## ⌘ Commands
| Command | Action |
| ------------- | -------------- |
| DFView | View dataframe in a floating window|
| DFViewBuf | View dataframe in a new buffer|
| DFClear | Clear cache directory|


> [!NOTE]
> I am not knowledgeable in lua. PRs for code refactor and new features are more than welcome.
