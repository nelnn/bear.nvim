# 🐼`bear.nvim`🐻‍❄️

A Neovim plugin for debugging `pandas`, `polars` and `PySpark` DataFrames
and pandas Series, including Databricks Runtime and Spark Connect.

https://github.com/user-attachments/assets/55e22539-9938-4b48-9ec5-b1b6a43b976b


## ⚡️ Requirements

- Neovim 0.11+
- [nvim-dap](https://github.com/mfussenegger/nvim-dap) with an active, paused
  Python debug session (for example, using debugpy)
- [visidata](https://www.visidata.org/install/) installed locally and on `PATH`
- At least one of [polars](https://github.com/pola-rs/polars),
  [pandas](https://github.com/pandas-dev/pandas), or
  [PySpark](https://spark.apache.org/docs/latest/api/python/) in the debugged
  Python environment. Spark exports do not require pandas or polars.

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

To install the development branch instead, add `branch = "dev"`:

```lua
{
  "nelnn/bear.nvim",
  branch = "dev",
  dependencies = { "mfussenegger/nvim-dap" },
  opts = {},
}
```

Run `:Lazy update bear.nvim` after changing the branch (and commit your updated
`lazy-lock.json`, if you track it). Branch installation is handled by lazy.nvim;
no separate build or Python package installation is needed for this plugin.

<details>
<summary>Default Configuration</summary>

```lua
{
  "nelnn/bear.nvim",
  dependencies = {
    "mfussenegger/nvim-dap",
  },
  opts = {
      cache_dir = "~/.cache/nvim/bear",
      file_name = "tmp_" .. os.date("%m%d_%H%M%S") .. ".csv", -- unique suffix added per view
      remove_file = true, -- remove file upon quitting visidata
      export_transport = "auto", -- Spark: DAP transfer; pandas/polars: local file
      max_transfer_bytes = 10 * 1024 * 1024, -- maximum CSV size for DAP transfer
      spark = {
        max_rows = 1000, -- positive integer; preview only, never collect the full dataset
      },
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
- `<leader>df`/`<leader>bdf` to view the DataFrame/pandas Series under the cursor
  or in the visual selection.
- `<leader>df`/`<leader>bdf` in the repl session and input the DataFrame/Series expression.
- `:DFView df` or `:DFViewBuf frames["result"]` to specify an expression explicitly.
- `<C-o>` to exit from terminal to normal mode and `i` to enter. This is useful
  when you want to change buffers.
- `q` to close floating window or buffer in normal and terminal mode.

You can see my debugging setup [here](https://github.com/nelnn/dotfiles/blob/main/.config/nvim/lua/plugins/debugging.lua).

## ⌘ Commands
| Command | Action |
| ------------- | -------------- |
| DFView [expression] | View DataFrame/Series in a floating window|
| DFViewBuf [expression] | View DataFrame/Series in a new buffer|
| DFClean | Clear cache directory|

## PySpark / Databricks

Spark exports use the public DataFrame APIs supported by classic PySpark and
Spark Connect, without `toPandas()`, RDDs, private JVM access, or `dbutils`.
`df.limit(spark.max_rows).collect()` performs a single bounded action; the
resulting CSV is sent over DAP and saved in Neovim's local cache. This avoids
requiring a shared filesystem with a Databricks driver. The plugin does not
establish a Databricks connection: attach nvim-dap to your Python driver or
Databricks Connect client first.

The default preview contains **at most 1,000 rows**, in Spark's natural order
(not a random sample or a guaranteed ordering). No `count()` is run. Large
upstream joins/sorts can still be expensive even with a limit; select only the
columns you need before previewing. Streaming DataFrames are not supported.
Pandas and polars retain their full-data export behaviour, including the pandas
index and support for pandas Series and polars LazyFrames.

Transport options:
- `"auto"` (default): DAP for Spark, direct file export for pandas/polars.
- `"dap"`: transfer CSV through the debug adapter for any supported library.
  Use this for remote pandas/polars sessions too. CSVs larger than
  `max_transfer_bytes` are rejected; adapters may impose smaller limits.
- `"file"`: export directly to the cache path in the Python process. Fastest for
  large exports, but that exact path must be writable and shared with Neovim.

CSV transfer uses debugpy's `rawString` format to avoid normal repr truncation.
If another adapter truncates responses, reduce `spark.max_rows` / the selected
columns, or use `"file"` with a shared filesystem. Byte limits apply after CSV
serialization; a row limit cannot bound the size of individual values.

## Tests

```sh
python3 -m unittest discover -s tests -v
nvim --headless -u NONE -l tests/test_bear.lua
```

The Python tests run without dataframe dependencies; installing pandas/polars
enables their integration tests. With PySpark and a compatible Java runtime
installed, run `BEAR_TEST_SPARK=1 python3 -m unittest discover -s tests -v` for
the local Spark integration test. Databricks/Spark Connect API variants are
covered by test doubles; a live Databricks session is not required by the suite.
