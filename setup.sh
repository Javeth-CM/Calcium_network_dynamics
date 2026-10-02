#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# setup.sh — create a Python virtual environment and install dependencies for
# the calcium-imaging statistical analysis.
#
# Usage (from the project folder):
#     bash setup.sh
#     source .venv/bin/activate
#     python analysis.py
#
# Requires: Python 3.10+ available on your PATH as `python3`.
# -----------------------------------------------------------------------------
set -euo pipefail

PY=${PYTHON:-python3}

echo "[1/4] Checking Python..."
$PY --version

echo "[2/4] Creating virtual environment (.venv)..."
$PY -m venv .venv

echo "[3/4] Activating virtual environment..."
# shellcheck disable=SC1091
source .venv/bin/activate

echo "[4/4] Installing dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

echo
echo "Done. Activate the environment with:"
echo "    source .venv/bin/activate"
echo "and run the analysis with:"
echo "    python analysis.py"
