#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$PROJECT_DIR/.venv"
NOTEBOOK="$PROJECT_DIR/final_project.ipynb"
REQUIREMENTS="$PROJECT_DIR/requirements.txt"
PYPROJECT="$PROJECT_DIR/pyproject.toml"
LOCKFILE="$PROJECT_DIR/uv.lock"
VALIDATOR="$PROJECT_DIR/scripts/validate_project.py"
TOOLS_DIR="$PROJECT_DIR/.tools"
NO_OPEN=0
SKIP_INSTALL=0
FORCE_SYNC=0

usage() {
  cat <<'EOF'
Usage: ./run-full-project.sh [options]

Options:
  --no-open       Execute and save the notebook without starting JupyterLab.
  --skip-install  Never synchronize; fail if the environment is out of date.
  --force-sync    Synchronize from uv.lock even when the environment matches.
  -h, --help      Show this help message.
EOF
}

for argument in "$@"; do
  case "$argument" in
    --no-open) NO_OPEN=1 ;;
    --skip-install) SKIP_INSTALL=1 ;;
    --force-sync) FORCE_SYNC=1 ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "Unknown option: $argument" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ "$SKIP_INSTALL" -eq 1 && "$FORCE_SYNC" -eq 1 ]]; then
  echo "--skip-install and --force-sync cannot be used together." >&2
  exit 2
fi

for required_file in "$NOTEBOOK" "$REQUIREMENTS" "$PYPROJECT" "$LOCKFILE" "$VALIDATOR"; do
  if [[ ! -f "$required_file" ]]; then
    echo "Required file not found: $required_file" >&2
    exit 1
  fi
done

case "$(uname -s)" in
  Darwin)
    PLATFORM="macOS"
    VENV_PYTHON="$VENV_DIR/bin/python"
    VENV_NBCONVERT="$VENV_DIR/bin/jupyter-nbconvert"
    ;;
  Linux)
    PLATFORM="Linux"
    VENV_PYTHON="$VENV_DIR/bin/python"
    VENV_NBCONVERT="$VENV_DIR/bin/jupyter-nbconvert"
    ;;
  MINGW*|MSYS*|CYGWIN*)
    echo "Detected Windows. Continuing with the native PowerShell launcher..."
    exec powershell.exe -NoProfile -ExecutionPolicy Bypass \
      -File "$PROJECT_DIR/run-full-project.ps1"
    ;;
  *)
    echo "Unsupported operating system: $(uname -s)" >&2
    exit 1
    ;;
esac

echo "Detected $PLATFORM."

is_python_312() {
  "$@" -c 'import sys; raise SystemExit(sys.version_info[:2] != (3, 12))' \
    >/dev/null 2>&1
}

find_python_312() {
  local candidate
  for candidate in python3.12 /opt/homebrew/bin/python3.12 /usr/local/bin/python3.12; do
    if command -v "$candidate" >/dev/null 2>&1 && is_python_312 "$candidate"; then
      command -v "$candidate"
      return 0
    fi
  done
  return 1
}

ensure_uv() {
  mkdir -p "$TOOLS_DIR"

  if [[ -x "$TOOLS_DIR/uv" ]]; then
    UV_COMMAND="$TOOLS_DIR/uv"
  elif command -v uv >/dev/null 2>&1; then
    UV_COMMAND="$(command -v uv)"
  else
    if ! command -v curl >/dev/null 2>&1; then
      echo "curl is required to install the uv dependency manager." >&2
      exit 1
    fi
    echo "Installing the uv dependency manager..."
    local installer="$TOOLS_DIR/uv-installer.sh"
    curl -LsSf https://astral.sh/uv/install.sh -o "$installer"
    UV_INSTALL_DIR="$TOOLS_DIR" sh "$installer"
    UV_COMMAND="$TOOLS_DIR/uv"
  fi
}

install_python_with_uv() {
  echo "Installing Python 3.12..."
  "$UV_COMMAND" python install 3.12
  "$UV_COMMAND" python find 3.12
}

ensure_uv
PYTHON_COMMAND="$(find_python_312 || true)"

if [[ -z "$PYTHON_COMMAND" ]]; then
  echo "Python 3.12 was not found."
  if [[ "$PLATFORM" == "macOS" ]] && command -v brew >/dev/null 2>&1; then
    echo "Installing Python 3.12 with Homebrew..."
    brew install python@3.12
    PYTHON_COMMAND="$(find_python_312 || true)"
  fi

  if [[ -z "$PYTHON_COMMAND" ]]; then
    PYTHON_COMMAND="$(install_python_with_uv)"
    PYTHON_COMMAND="$(printf '%s\n' "$PYTHON_COMMAND" | tail -n 1)"
  fi
fi

if ! is_python_312 "$PYTHON_COMMAND"; then
  echo "Unable to install or locate Python 3.12." >&2
  exit 1
fi

echo "Using $("$PYTHON_COMMAND" --version)."

if [[ -x "$VENV_PYTHON" ]] && ! is_python_312 "$VENV_PYTHON"; then
  echo "Recreating .venv because it does not use Python 3.12..."
  rm -rf "$VENV_DIR"
fi

export PIP_DISABLE_PIP_VERSION_CHECK=1
export PIP_CACHE_DIR="$TOOLS_DIR/pip-cache"
export UV_CACHE_DIR="$TOOLS_DIR/uv-cache"

LOCK_FINGERPRINT="$(
  "$PYTHON_COMMAND" -c \
    'import hashlib, pathlib, sys; h=hashlib.sha256(); [h.update(pathlib.Path(p).read_bytes()) for p in sys.argv[1:]]; print(h.hexdigest())' \
    "$PYPROJECT" "$LOCKFILE"
)"
FINGERPRINT_FILE="$VENV_DIR/.dependency-lock.sha256"
ENVIRONMENT_MATCHES=0

if [[ -x "$VENV_PYTHON" && -x "$VENV_NBCONVERT" && -f "$FINGERPRINT_FILE" ]]; then
  SAVED_FINGERPRINT="$(<"$FINGERPRINT_FILE")"
  if is_python_312 "$VENV_PYTHON" && [[ "$SAVED_FINGERPRINT" == "$LOCK_FINGERPRINT" ]]; then
    ENVIRONMENT_MATCHES=1
  fi
fi

if [[ "$SKIP_INSTALL" -eq 1 ]]; then
  if [[ "$ENVIRONMENT_MATCHES" -ne 1 ]]; then
    echo "The environment is missing or out of date. Run without --skip-install." >&2
    exit 1
  fi
  echo "Using the matching locked environment (--skip-install)."
elif [[ "$FORCE_SYNC" -eq 1 || "$ENVIRONMENT_MATCHES" -ne 1 ]]; then
  echo "Synchronizing the environment from uv.lock..."
  "$UV_COMMAND" sync --frozen --python "$PYTHON_COMMAND"
  printf '%s\n' "$LOCK_FINGERPRINT" > "$FINGERPRINT_FILE"
else
  echo "Dependency lock unchanged; using the existing environment."
fi

echo "Executing every cell in final_project.ipynb..."
mkdir -p "$TOOLS_DIR/matplotlib" "$TOOLS_DIR/ipython"
MPLCONFIGDIR="$TOOLS_DIR/matplotlib" \
IPYTHONDIR="$TOOLS_DIR/ipython" \
  "$VENV_NBCONVERT" \
  --to notebook \
  --execute "$NOTEBOOK" \
  --output "$NOTEBOOK" \
  --ExecutePreprocessor.timeout=1200

echo "Notebook execution completed successfully."
echo "Validating the executed project..."
"$VENV_PYTHON" "$VALIDATOR"

if [[ "$NO_OPEN" -eq 1 ]]; then
  echo "JupyterLab launch skipped (--no-open)."
  exit 0
fi

echo "Starting JupyterLab..."
MPLCONFIGDIR="$TOOLS_DIR/matplotlib" \
IPYTHONDIR="$TOOLS_DIR/ipython" \
  exec "$VENV_PYTHON" -m jupyterlab \
  --notebook-dir="$PROJECT_DIR" \
  "$NOTEBOOK"
