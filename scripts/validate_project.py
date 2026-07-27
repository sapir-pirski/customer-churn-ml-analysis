#!/usr/bin/env python3
"""Validate the executed project before it is opened or submitted."""

from __future__ import annotations

import re
import sys
import tomllib
from pathlib import Path

import nbformat


PROJECT_DIR = Path(__file__).resolve().parents[1]
NOTEBOOK_PATH = PROJECT_DIR / "final_project.ipynb"
DATASET_PATH = PROJECT_DIR / "data" / "churn.csv"
PYPROJECT_PATH = PROJECT_DIR / "pyproject.toml"
LOCKFILE_PATH = PROJECT_DIR / "uv.lock"
REQUIREMENTS_PATH = PROJECT_DIR / "requirements.txt"

REQUIRED_SECTIONS = (
    "The problem",
    "Imports and reproducibility",
    "Load, validate, and describe the data",
    "Data description: six core visualizations",
    "Data engineering",
    "Evaluation design and majority baseline",
    "K-nearest neighbors",
    "Decision tree",
    "Random forest",
    "Final untouched-test evaluation",
    "Algorithm introspection",
    "Error analysis",
    "Conclusions",
)

REQUIRED_CODE_MARKERS = (
    "# Graph 1: target distribution",
    "# Graph 2: contract",
    "# Graph 3: tenure",
    "# Graph 4: monthly charges",
    "# Graph 5: internet service",
    "# Graph 6: payment method",
    "KNeighborsClassifier",
    "DecisionTreeClassifier",
    "RandomForestClassifier",
    "plot_tree",
    "permutation_importance",
)

OUTPUT_PROBLEM_PATTERN = re.compile(
    r"(warning:|findfont|traceback|deprecated|deprecationwarning)",
    flags=re.IGNORECASE,
)


def fail(message: str) -> None:
    print(f"VALIDATION FAILED: {message}", file=sys.stderr)
    raise SystemExit(1)


def output_text(output: dict) -> str:
    if output.get("output_type") == "stream":
        return str(output.get("text", ""))
    if output.get("output_type") == "error":
        return " ".join(
            str(output.get(key, "")) for key in ("ename", "evalue", "traceback")
        )
    return str(output.get("data", {}).get("text/plain", ""))


def main() -> None:
    if sys.version_info[:2] != (3, 12):
        fail(
            "Python 3.12 is required; "
            f"found {sys.version_info.major}.{sys.version_info.minor}."
        )

    if not DATASET_PATH.is_file() or DATASET_PATH.stat().st_size == 0:
        fail(f"Dataset is missing or empty: {DATASET_PATH}")
    if not NOTEBOOK_PATH.is_file():
        fail(f"Notebook is missing: {NOTEBOOK_PATH}")

    for dependency_file in (PYPROJECT_PATH, LOCKFILE_PATH, REQUIREMENTS_PATH):
        if not dependency_file.is_file() or dependency_file.stat().st_size == 0:
            fail(f"Dependency metadata is missing or empty: {dependency_file}")

    with PYPROJECT_PATH.open("rb") as stream:
        project_metadata = tomllib.load(stream)
    if project_metadata.get("project", {}).get("requires-python") != ">=3.12,<3.13":
        fail("pyproject.toml must require Python >=3.12,<3.13.")
    if "[[package]]" not in LOCKFILE_PATH.read_text(encoding="utf-8"):
        fail("uv.lock does not contain resolved packages.")
    if "--hash=sha256:" not in REQUIREMENTS_PATH.read_text(encoding="utf-8"):
        fail("requirements.txt is not a hash-locked uv export.")

    try:
        notebook = nbformat.read(NOTEBOOK_PATH, as_version=4)
        nbformat.validate(notebook)
    except Exception as exc:
        fail(f"Notebook structure is invalid: {exc}")

    code_cells = [cell for cell in notebook.cells if cell.cell_type == "code"]
    unexecuted = [
        index
        for index, cell in enumerate(notebook.cells)
        if cell.cell_type == "code" and cell.execution_count is None
    ]
    if unexecuted:
        fail(f"Unexecuted code cells found at notebook indexes: {unexecuted}")

    output_problems: list[str] = []
    for cell_index, cell in enumerate(notebook.cells):
        for output in cell.get("outputs", []):
            if output.get("output_type") == "error":
                output_problems.append(f"cell {cell_index}: error output")
                continue
            match = OUTPUT_PROBLEM_PATTERN.search(output_text(output))
            if match:
                output_problems.append(
                    f"cell {cell_index}: output contains {match.group(0)!r}"
                )
    if output_problems:
        fail("; ".join(output_problems))

    headings = "\n".join(
        cell.source
        for cell in notebook.cells
        if cell.cell_type == "markdown"
        and cell.source.lstrip().startswith("#")
    )
    missing_sections = [
        section for section in REQUIRED_SECTIONS if section not in headings
    ]
    if missing_sections:
        fail(f"Required notebook sections are missing: {missing_sections}")

    code_source = "\n".join(cell.source for cell in code_cells)
    missing_markers = [
        marker for marker in REQUIRED_CODE_MARKERS if marker not in code_source
    ]
    if missing_markers:
        fail(f"Required plots or algorithm artifacts are missing: {missing_markers}")

    print(
        "Validation passed: "
        "locked dependency metadata, Python 3.12, dataset present, "
        f"{len(code_cells)} executed code cells, warning-free outputs, "
        "and all required sections/artifacts found."
    )


if __name__ == "__main__":
    main()
