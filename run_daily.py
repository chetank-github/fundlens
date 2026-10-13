"""FundLens daily pipeline: AMFI extract -> dbt build. Run by Windows Task Scheduler."""
import os
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path

import nbformat
from dotenv import load_dotenv
from nbconvert.preprocessors import ExecutePreprocessor
from sqlalchemy import make_url

PROJECT_DIR = Path(__file__).resolve().parent
NOTEBOOK = PROJECT_DIR / "notebooks" / "01_extract_amfi_daily.ipynb"
DBT_DIR = PROJECT_DIR / "fundlens_dbt"
LOG_DIR = PROJECT_DIR / "logs"
LOG_DIR.mkdir(exist_ok=True)
LOG_FILE = LOG_DIR / f"daily_{datetime.now():%Y%m%d}.log"


def log(msg):
    line = f"{datetime.now():%Y-%m-%d %H:%M:%S}  {msg}"
    print(line)
    with open(LOG_FILE, "a", encoding="utf-8") as f:
        f.write(line + "\n")


def run_notebook():
    log(f"Running {NOTEBOOK.name}")
    nb = nbformat.read(NOTEBOOK, as_version=4)
    ExecutePreprocessor(timeout=1800, kernel_name="python3").preprocess(
        nb, {"metadata": {"path": str(NOTEBOOK.parent)}}  # run from notebooks/ like Jupyter does
    )
    nbformat.write(nb, LOG_DIR / "01_last_run.ipynb")
    log("Extract finished")


def run_dbt():
    load_dotenv(PROJECT_DIR / ".env")
    url = make_url(os.environ["DATABASE_URL"])
    env = {**os.environ,
           "DBT_HOST": url.host or "localhost", "DBT_PORT": str(url.port or 5432),
           "DBT_USER": url.username, "DBT_PASSWORD": url.password or "",
           "DBT_DBNAME": url.database, "DBT_USE_COLORS": "false"}
    exe_dir = Path(sys.executable).parent          # venv\Scripts on Windows
    dbt = next((p for p in (exe_dir / "dbt.exe", exe_dir / "Scripts" / "dbt.exe", exe_dir / "dbt") if p.exists()),
               shutil.which("dbt"))
    for args in (["source", "freshness"], ["build"]):
        log(f"Running dbt {' '.join(args)}")
        result = subprocess.run([str(dbt), *args, "--project-dir", str(DBT_DIR), "--profiles-dir", str(DBT_DIR)],
                                env=env, capture_output=True, text=True)
        with open(LOG_FILE, "a", encoding="utf-8") as f:
            f.write(result.stdout + result.stderr)
        if result.returncode != 0:
            raise RuntimeError(f"dbt {' '.join(args)} failed (see {LOG_FILE.name})")
    log("dbt finished")


if __name__ == "__main__":
    try:
        run_notebook()
        run_dbt()
        log("DAILY RUN OK")
    except Exception as e:
        log(f"DAILY RUN FAILED: {e}")
        sys.exit(1)
