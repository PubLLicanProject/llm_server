#!/bin/bash

# TODO: stop breaking with partial downloads/reruns

# This script
# Downloads the latest miniconda installer from https://docs.conda.io/en/latest/miniconda.html
# And the latest ollama version from https://ollama.com/
# It then sets up Ollama env vars and server startup with the conda environemnt.
#
# If prefered, build can be done manually instead of runnign this script:
#  - Set up a conda environment
#    * Install requirements.txt to the env
#  - Install ollama
#    * Start ollama server

set -euo pipefail

: "${OLLAMA_PREFIX:=ollama}"
: "${CONDA_PREFIX:=conda}"
: "${ENV_NAME:=env}"

mkdir -p "${OLLAMA_PREFIX}/bin"

echo "Installing Miniconda to ${CONDA_PREFIX}."
INSTALLER="Miniconda3-latest-Linux-x86_64.sh"
wget https://repo.anaconda.com/miniconda/$INSTALLER
bash "$INSTALLER" -b -p "$(realpath "$CONDA_PREFIX")"
export PATH="$(realpath "$CONDA_PREFIX/bin"):$PATH"

# TOS
conda tos interactive --override-channels --channel https://repo.anaconda.com/pkgs/main
conda tos interactive --override-channels --channel https://repo.anaconda.com/pkgs/r

# Initialize
source "$(realpath "$CONDA_PREFIX/etc/profile.d/conda.sh")"

conda create -y -n "$ENV_NAME" python=3.10
conda activate "$ENV_NAME"
pip install -r requirements.txt
chmod 755 ./*.sh

echo "Please select your GPU type:"
echo "  1) AMD"
echo "  2) NVIDIA"
echo
echo "Enter your choice [1-2]: "
read -r choice

case "$choice" in
1)
    GPU="AMD"
    ;;
2)
    GPU="NVIDIA"
    ;;
*)
    echo "Invalid choice. Exiting."
    exit 1
    ;;
esac

echo "Installing Ollama."
curl -fL https://ollama.com/download/ollama-linux-amd64.tgz | tar zx -C "$OLLAMA_PREFIX"
if [ "$GPU" = "AMD" ]; then
    echo "Installing AMD ROCm add-on."
    curl -fL https://ollama.com/download/ollama-linux-amd64-rocm.tgz | tar zx -C "$OLLAMA_PREFIX"
fi

export PATH="$OLLAMA_PREFIX/bin:$PATH"
export OLLAMA_MODELS="$OLLAMA_PREFIX/models"
mkdir -p "$OLLAMA_MODELS"

echo "Ollama version:"
"$OLLAMA_PREFIX/bin/ollama" --version || {
    echo "Error: Ollama failed to run"
    exit 1
}

# Ollama conda hooks
# activate order:
# 1 set paths
# 2 start server
# deactivate order (conda runs them backwards alphabetically):
# 1 stop server
# 2 restore paths
ACTIVATE_DIR="$(conda info --base)/envs/$ENV_NAME/etc/conda/activate.d"
DEACTIVATE_DIR="$(conda info --base)/envs/$ENV_NAME/etc/conda/deactivate.d"
mkdir -p "$ACTIVATE_DIR" "$DEACTIVATE_DIR"

# Set Paths
cat >"$ACTIVATE_DIR/1_ollama_path.sh" <<EOF
#!/bin/bash
set -euo pipefail

export OLLAMA_OLD_PATH="\$PATH"
export OLLAMA_PREFIX_ABS="$(realpath "$OLLAMA_PREFIX")"
export PATH="\$OLLAMA_PREFIX_ABS/bin:\$PATH"
export OLLAMA_MODELS="\$OLLAMA_PREFIX_ABS/models"
EOF
chmod +x "$ACTIVATE_DIR/1_ollama_path.sh"

# Unset Paths
cat >"$DEACTIVATE_DIR/2_ollama_path.sh" <<'EOF'
#!/bin/bash
set -euo pipefail

if [ -n "${OLLAMA_OLD_PATH-}" ]; then
    export PATH="$OLLAMA_OLD_PATH"
    unset OLLAMA_OLD_PATH
fi

unset OLLAMA_MODELS
unset OLLAMA_PREFIX_ABS
EOF
chmod +x "$DEACTIVATE_DIR/2_ollama_path.sh"

# Start ollama
cat >"$ACTIVATE_DIR/2_ollama_server.sh" <<EOF
#!/bin/bash
set -euo pipefail

export OLLAMA_PID_FILE="$(realpath "$OLLAMA_PREFIX")/ollama.pid"
export OLLAMA_LOG_FILE="$(realpath "$OLLAMA_PREFIX")/ollama.log"

if [ -f "\$OLLAMA_PID_FILE" ]; then
    if ps -p \$(cat "\$OLLAMA_PID_FILE") > /dev/null; then
        echo "Ollama server already running (PID: \$(cat "\$OLLAMA_PID_FILE"))."
        exit 0
    else
        echo "Stale PID file found. Removing..."
        rm -f "\$OLLAMA_PID_FILE"
    fi
fi

echo "Starting Ollama server..."
setsid "\$OLLAMA_PREFIX_ABS/bin/ollama" serve > "\$OLLAMA_LOG_FILE" 2>&1 &

echo \$! > "\$OLLAMA_PID_FILE"

echo "Ollama server started (PID: \$(cat "\$OLLAMA_PID_FILE")). Log: \$OLLAMA_LOG_FILE"
EOF
chmod +x "$ACTIVATE_DIR/2_ollama_server.sh"

# Stop ollama
cat >"$DEACTIVATE_DIR/1_ollama_server.sh" <<'EOF'
#!/bin/bash
set -euo pipefail

if [ -z "${OLLAMA_PID_FILE-}" ] || [ ! -f "$OLLAMA_PID_FILE" ]; then
    echo "Ollama PID file not found. Server may not be running."
    exit 0
fi

PID=$(cat "$OLLAMA_PID_FILE")
if [ -z "$PID" ]; then
    echo "PID file is empty."
    rm -f "$OLLAMA_PID_FILE"
    exit 0
fi

if ps -p $PID > /dev/null; then
    echo "Stopping Ollama server (PID: $PID)..."
    kill $PID
    for _ in 1 2 3; do
        if ! ps -p $PID > /dev/null; then
            break
        fi
        sleep 1
    done
    if ps -p $PID > /dev/null; then
        echo "Ollama did not stop, forcing kill (PID: $PID)..."
        kill -9 $PID
    fi
    echo "Ollama server stopped."
else
    echo "Ollama server (PID: $PID) not running."
fi

rm -f "$OLLAMA_PID_FILE"

unset OLLAMA_PID_FILE
unset OLLAMA_LOG_FILE
EOF
chmod +x "$DEACTIVATE_DIR/1_ollama_server.sh"

# Normally it'd be:
# source $(realpath "$CONDA_PREFIX/etc/profile.d/conda.sh") && conda activate $ENV_NAME
# that is a pain.
# Script for conda env activation (It is literally impossible to mess this up)
cat >./activate_conda_env.sh <<'EOF'
#!/bin/bash
set -euo pipefail

# Resolve paths relative to this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONDA_PREFIX="$SCRIPT_DIR/conda"
ENV_NAME="env"

# Source conda (from the Miniconda installation, not the env)
if [ ! -f "$CONDA_PREFIX/etc/profile.d/conda.sh" ]; then
    echo "Error: conda not found in $CONDA_PREFIX"
    exit 1
fi
source "$CONDA_PREFIX/etc/profile.d/conda.sh"

deactivate() {
    EXIT_CODE=$?

    if [ "${CONDA_DEFAULT_ENV:-}" = "$ENV_NAME" ]; then
        echo "Running cleanup, deactivating environment..."
        conda deactivate
    fi

    exit $EXIT_CODE
}

trap 'deactivate' EXIT
conda activate "$ENV_NAME"

if [ "$#" -gt 0 ]; then
    # If user provided arguments, run them inside the env
    "$@"
else
    # Otherwise, start an interactive shell
    bash
fi
EOF
chmod 755 ./activate_conda_env.sh

echo
echo "To activate the environment, run:"
echo "  ./activate_conda_env.sh"
echo
echo "To run a command directly, run:"
echo "  ./activate_conda_env.sh COMMAND"
