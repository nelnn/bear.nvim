"""Executed in an isolated namespace in the paused Python debug session."""

import base64
import io
import json


def _dataframe_kind(df):
    # Inspect the MRO instead of importing every supported (potentially expensive)
    # library. This also recognises subclasses and classic/Connect Spark frames.
    for cls in type(df).__mro__:
        root = cls.__module__.split(".", 1)[0]
        names = ("DataFrame", "Series") if root == "pandas" else ("DataFrame", "LazyFrame")
        if root in ("pandas", "polars", "pyspark") and cls.__name__ in names:
            return root, cls.__name__
    raise TypeError("Expected a pandas, polars or PySpark DataFrame, pandas Series or polars LazyFrame")


def _export_dataframe(df, options):
    kind, name = _dataframe_kind(df)
    transport = options["transport"]
    if transport == "auto":
        # Databricks drivers commonly do not share Neovim's filesystem.
        transport = "dap" if kind == "pyspark" else "file"
    if transport not in ("file", "dap"):
        raise ValueError("export_transport must be 'auto', 'file' or 'dap'")

    if kind == "pyspark":
        if df.isStreaming:
            raise ValueError("Streaming DataFrames are not supported; preview a batch DataFrame")
        limit = options["spark_max_rows"]
        if type(limit) is not int or limit < 1:
            raise ValueError("spark.max_rows must be a positive integer")
        # One bounded action, no count(), toPandas(), RDD or private JVM APIs.
        # Public APIs work on Databricks shared clusters and Spark Connect too.
        df = df.limit(limit)
    elif kind == "polars" and name == "LazyFrame":
        df = df.collect()

    def write_csv(target):
        if kind == "pyspark":
            import csv

            writer = csv.writer(target)
            writer.writerow(df.columns)
            writer.writerows(df.collect())
        elif kind == "pandas":
            df.to_csv(target, index=True)
        else:
            df.write_csv(target)

    if transport == "file":
        with open(options["path"], "w", encoding="utf-8", newline="") as target:
            write_csv(target)
        return {"ok": True, "transport": "file"}

    max_bytes = options["max_transfer_bytes"]
    if type(max_bytes) is not int or max_bytes < 1:
        raise ValueError("max_transfer_bytes must be a positive integer")
    target = io.StringIO(newline="")
    write_csv(target)
    csv_text = target.getvalue()
    if len(csv_text.encode("utf-8")) > max_bytes:
        raise ValueError(
            "CSV exceeds max_transfer_bytes; reduce spark.max_rows, select fewer "
            "columns, or use export_transport='file' with a shared filesystem"
        )
    return {"ok": True, "transport": "dap", "csv": csv_text}


def export_dataframe(df, options):
    try:
        result = _export_dataframe(df, options)
    except Exception as exc:
        result = {"ok": False, "error": str(exc)}
    # A marker plus base64 survives the Python repr returned by debug adapters,
    # including quotes, newlines and Unicode. The end marker detects truncation.
    payload = json.dumps(result, ensure_ascii=False).encode("utf-8")
    return "BEAR_NVIM:" + base64.b64encode(payload).decode("ascii") + ":END"
