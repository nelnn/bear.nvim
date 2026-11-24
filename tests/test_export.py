"""Run with: python3 -m unittest discover -s tests -v"""

import base64
import builtins
import csv
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("bear_export", ROOT / "python/bear_export.py")
exporter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(exporter)


def decode(result):
    assert result.startswith("BEAR_NVIM:") and result.endswith(":END")
    return json.loads(base64.b64decode(result[len("BEAR_NVIM:"):-len(":END")]))


class SparkMethods:
    isStreaming = False
    columns = ["id", "text"]

    def __init__(self, rows, events=None, bounded=False):
        self.rows = rows
        self.events = events if events is not None else []
        self.bounded = bounded

    def limit(self, limit):
        self.events.append(("limit", limit))
        return type(self)(self.rows[:limit], self.events, bounded=True)

    def collect(self):
        if not self.bounded:
            raise AssertionError("Unbounded Spark collect!")
        self.events.append(("collect", len(self.rows)))
        return self.rows


SparkFrame = type("DataFrame", (SparkMethods,), {"__module__": "pyspark.sql.dataframe"})
ConnectFrame = type("DataFrame", (SparkMethods,), {"__module__": "pyspark.sql.connect.dataframe"})
ClassicFrame = type("DataFrame", (SparkMethods,), {"__module__": "pyspark.sql.classic.dataframe"})


class ExportTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.options = {
            "path": str(Path(self.temp.name) / "quoted ' 雪.csv"),
            "transport": "auto",
            "spark_max_rows": 2,
            "max_transfer_bytes": 1024 * 1024,
        }

    def export(self, frame, **options):
        return decode(exporter.export_dataframe(frame, dict(self.options, **options)))

    def test_spark_variants_and_subclasses_use_one_bounded_action(self):
        class DatabricksFrame(ConnectFrame):
            pass

        for cls in (SparkFrame, ConnectFrame, ClassicFrame, DatabricksFrame):
            with self.subTest(cls=cls):
                frame = cls([(1, 'quotes, " and\nnewlines'), (2, "雪"), (3, "ignored")])
                result = self.export(frame)
                self.assertTrue(result["ok"])
                self.assertEqual(result["transport"], "dap")
                self.assertEqual(frame.events, [("limit", 2), ("collect", 2)])
                self.assertEqual(list(csv.reader(io.StringIO(result["csv"]))), [
                    ["id", "text"], ["1", 'quotes, " and\nnewlines'], ["2", "雪"]
                ])
                self.assertFalse(Path(self.options["path"]).exists())

    def test_spark_does_not_import_dataframe_libraries(self):
        original_import = builtins.__import__

        def guarded_import(name, *args, **kwargs):
            if name.split(".")[0] in ("pandas", "polars", "pyspark"):
                raise AssertionError("Unnecessary import: " + name)
            return original_import(name, *args, **kwargs)

        with patch("builtins.__import__", side_effect=guarded_import):
            self.assertTrue(self.export(SparkFrame([]))["ok"])

    def test_empty_frame_still_writes_header(self):
        self.assertEqual(self.export(SparkFrame([]))["csv"], "id,text\r\n")

    def test_shared_file_transport(self):
        result = self.export(SparkFrame([(1, None)]), transport="file")
        self.assertEqual(result, {"ok": True, "transport": "file"})
        with open(self.options["path"], newline="", encoding="utf-8") as target:
            self.assertEqual(list(csv.reader(target)), [["id", "text"], ["1", ""]])

    def test_streaming_rejected_before_action(self):
        frame = SparkFrame([])
        frame.isStreaming = True
        result = self.export(frame)
        self.assertFalse(result["ok"])
        self.assertIn("Streaming", result["error"])
        self.assertEqual(frame.events, [])

    def test_bad_limits_rejected_before_action(self):
        for limit in (0, -1, False, 2.5, "1000"):
            frame = SparkFrame([])
            result = self.export(frame, spark_max_rows=limit)
            self.assertFalse(result["ok"])
            self.assertIn("positive integer", result["error"])
            self.assertEqual(frame.events, [])

    def test_transfer_limit_counts_utf8_bytes(self):
        frame = SparkFrame([(1, "雪")])
        result = self.export(frame, max_transfer_bytes=len("id,text\r\n1,雪\r\n"))
        self.assertFalse(result["ok"])
        self.assertIn("max_transfer_bytes", result["error"])

    def test_unsupported_variable_returns_error_not_stale_success(self):
        Path(self.options["path"]).write_text("old data")
        result = self.export(object())
        self.assertFalse(result["ok"])
        self.assertIn("Expected", result["error"])

    def test_spark_failure_is_reported(self):
        class BrokenFrame(SparkFrame):
            def collect(self):
                raise RuntimeError("Spark job failed")

        self.assertEqual(self.export(BrokenFrame([])), {"ok": False, "error": "Spark job failed"})

    def test_invalid_transport(self):
        self.assertFalse(self.export(SparkFrame([]), transport="wrong")["ok"])

    @unittest.skipUnless(shutil.which("nvim"), "Neovim not installed")
    def test_lua_generated_expression_with_remote_frame_locals(self):
        expression_file = str(Path(self.temp.name) / "expression.txt")
        script = str(Path(self.temp.name) / "expression.lua")
        Path(script).write_text('''
vim.opt.runtimepath:prepend(vim.env.BEAR_TEST_ROOT)
local options = vim.json.decode(vim.env.BEAR_TEST_OPTIONS)
local expression = require("bear.export").expression("frames['quoted']", options.path, {
  export_transport = options.transport,
  spark = { max_rows = options.spark_max_rows },
  max_transfer_bytes = options.max_transfer_bytes,
})
vim.fn.writefile({ expression }, vim.env.BEAR_TEST_EXPRESSION)
''')
        env = dict(os.environ, BEAR_TEST_ROOT=str(ROOT), BEAR_TEST_OPTIONS=json.dumps(self.options),
                   BEAR_TEST_EXPRESSION=expression_file)
        subprocess.run(["nvim", "--headless", "-u", "NONE", "-l", script], env=env,
                       check=True, capture_output=True, timeout=10)
        frame_locals = {"frames": {"quoted": SparkFrame([(1, "remote")])}}
        frame_globals = {"__builtins__": builtins}
        result = decode(eval(Path(expression_file).read_text(), frame_globals, frame_locals))
        self.assertTrue(result["ok"])
        self.assertIn("remote", result["csv"])
        self.assertEqual(set(frame_locals), {"frames"})
        self.assertEqual(set(frame_globals), {"__builtins__"})

    @unittest.skipUnless(importlib.util.find_spec("pandas"), "pandas not installed")
    def test_real_pandas_preserves_index_and_supports_both_transports(self):
        import pandas as pd

        frame = pd.DataFrame({"text": ["雪", 'a,"b']}, index=[7, 9])
        self.assertEqual(self.export(frame)["transport"], "file")
        with open(self.options["path"], encoding="utf-8", newline="") as target:
            self.assertEqual(target.read(), frame.to_csv(index=True))
        self.assertEqual(self.export(frame, transport="dap")["csv"], frame.to_csv(index=True))

    @unittest.skipUnless(importlib.util.find_spec("pandas"), "pandas not installed")
    def test_real_pandas_series_preserves_upstream_support(self):
        import pandas as pd

        series = pd.Series(["雪", 'a,"b'], index=[7, 9], name="text")
        self.assertEqual(self.export(series)["transport"], "file")
        with open(self.options["path"], encoding="utf-8", newline="") as target:
            self.assertEqual(target.read(), series.to_csv(index=True))
        self.assertEqual(self.export(series, transport="dap")["csv"], series.to_csv(index=True))

    @unittest.skipUnless(importlib.util.find_spec("polars"), "polars not installed")
    def test_real_polars_eager_and_lazy(self):
        import polars as pl

        frame = pl.DataFrame({"text": ["雪", 'a,"b']})
        for value in (frame, frame.lazy()):
            self.assertEqual(self.export(value)["transport"], "file")
            self.assertEqual(Path(self.options["path"]).read_text(), frame.write_csv())
            self.assertEqual(self.export(value, transport="dap")["csv"], frame.write_csv())

    @unittest.skipUnless(os.environ.get("BEAR_TEST_SPARK") == "1", "set BEAR_TEST_SPARK=1 for local Spark")
    def test_real_spark(self):
        from pyspark.sql import SparkSession

        spark = SparkSession.builder.master("local[1]").appName("bear-test").getOrCreate()
        try:
            frame = spark.createDataFrame([(1, "雪"), (2, None), (3, "not exported")], ["id", "text"])
            result = self.export(frame)
            self.assertTrue(result["ok"], result)
            self.assertEqual(len(list(csv.reader(io.StringIO(result["csv"])))), 3)
        finally:
            spark.stop()


if __name__ == "__main__":
    unittest.main()
