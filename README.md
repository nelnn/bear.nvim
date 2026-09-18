# 🐼`bear.nvim`🐻‍❄️

A neovim plugin for debugging `pandas` and `polars` `DataFrames`/`Series`.

https://github.com/user-attachments/assets/55e22539-9938-4b48-9ec5-b1b6a43b976b


## ⚡️ Requirements

- [nvim-dap](https://github.com/mfussenegger/nvim-dap)
- [visidata](https://www.visidata.org/install/) installed globally
- [polars](https://github.com/pola-rs/polars) and/or
  [pandas](https://github.com/pandas-dev/pandas) installed in your virtual
  environment

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

You can embed your own Python logic via

```lua
opts = {
    custom_python_logic = [[
elif pandas_imported and isinstance(df_var.df, (pd.DataFrame, pd.Series)):
    if df_var.df.shape == (1, 2):
        print('Correct shape.')
    else:
        print('Wrong shape.')
]]
}
```

<details>
<summary>Python Example</summary>
Assume you have a custom Pandas manager implemented, to keep meta data about the origin of your data:

```python
from pathlib import Path
import pandas as pd

class MyDFManager:

    def __init__(self, path_to_csv: Path):
        self.df: pd.DataFrame = pd.read_csv(path)
        self.path: Path = path_to_csv


if __name__ == '__main__':
    df_man = MyDFManager(Path('path/to/csv'))
```

Displaying the `pd.DataFrame` while on `df_man` won't work, because it isn't a `pd.DataFrame` and you would need to add workaround lines like `df_man.df` to you code. With the provided `custom_python_logic`, you can.
</details>

- Starting with `elif` is mandatory to avoid errors.
- The `pandas`/`polars` object **is referenced as** `df_var`.
- It is recommended to guarad your logic with {`pandas`, `polars`}`_imported.`
- No extra indentation needed (applied by the plugin), only `[[…]]` strings are supported.
- It is highly recommended to stick to `elif`s in general (s. output of `:DFCode`).


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
      file_name = "tmp_" .. os.date("%m%d_%H%M%S") .. ".csv",
      remove_file = true, -- remove file upon quitting visidata
      window = {
        width = 0.9,
        height = 0.8,
        border = "rounded"
      },
      keymap = {
        visualise = "<leader>df",
        visualise_buf = "<leader>bdf",
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
- `<leader>df`/`<leader>dfb` to view the `DataFrame`/`pd.Series` under the cursor or the visual selection.
- `<leader>df`/`<leader>dfb` in the repl session and input the `DataFrame`/`Series` variable.
- `<C-o>` to exit from terminal to normal mode and `i` to enter. This is useful
  when you want to change buffers.
- `q` to close floating window or buffer in normal and terminal mode.

You can see my debugging setup [here](https://github.com/nelnn/dotfiles/blob/main/.config/nvim/lua/plugins/debugging.lua).

## ⌘ Commands
| Command | Action |
| ------------- | -------------- |
| DFView | View `DataFrame`/`Series` in a floating window|
| DFViewBuf | View `DataFrame`/`Series` in a new buffer|
| DFClean | Clear cache directory|
| DFCode | Print Python code which saves your `DataFrame`/`Series` (to debug your `custom_python_logic`) |


> [!NOTE]
> I am not knowledgeable in lua. PRs for code refactor and new features are more than welcome.
