#!/bin/bash

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
CONDA_PATH=$CONDA_PREFIX

mkdir -p "${OLLAMA_PREFIX}/bin"
if [[ -t 0 ]]; then
    echo "Please select your GPU type for Ollama installation:"
    echo "  1) AMD"
    echo "  2) NVIDIA"
    echo
    echo "Enter your choice [1-2]: "
    read -r choice
else
    echo "Non-interactive mode detected. Defaulting to NVIDIA."
    choice=2
fi

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
OLLAMA_TGZ="ollama-linux-amd64.tgz"

if [ ! -f "$OLLAMA_TGZ" ]; then
    echo "Downloading Ollama..."
    curl -fLo "$OLLAMA_TGZ" -C - https://ollama.com/download/$OLLAMA_TGZ
else
    echo "Ollama archive already present, skipping download."
fi

if [ ! -x "$OLLAMA_PREFIX/bin/ollama" ]; then
    echo "Extracting Ollama..."
    tar zxf "$OLLAMA_TGZ" -C "$OLLAMA_PREFIX" && rm -f "$OLLAMA_TGZ"
else
    echo "Ollama already installed at $OLLAMA_PREFIX/bin/ollama"
fi

if [ "$GPU" = "AMD" ]; then
    echo "Installing AMD ROCm add-on."
    ROCM_TGZ="ollama-linux-amd64-rocm.tgz"
    if [ ! -f "$ROCM_TGZ" ]; then
        curl -fLo "$ROCM_TGZ" -C - https://ollama.com/download/$ROCM_TGZ
    fi
    tar zxf "$ROCM_TGZ" -C "$OLLAMA_PREFIX" && rm -f "$ROCM_TGZ"
fi

export PATH="$OLLAMA_PREFIX/bin:$PATH"
export OLLAMA_MODELS="$OLLAMA_PREFIX/models"
mkdir -p "$OLLAMA_MODELS"

echo "Ollama version:"
"$OLLAMA_PREFIX/bin/ollama" --version || {
    echo "Error: Ollama failed to run"
    exit 1
}

echo "Installing Miniconda to ${CONDA_PREFIX}."
INSTALLER="Miniconda3-latest-Linux-x86_64.sh"

if [ ! -f "$INSTALLER" ]; then
    echo "Downloading Miniconda installer..."
    wget -c "https://repo.anaconda.com/miniconda/$INSTALLER"
else
    echo "Miniconda installer already present, skipping download."
fi

if [ ! -d "$CONDA_PREFIX" ]; then
    echo "Installing Miniconda..."
    bash "$INSTALLER" -b -p "$(realpath "$CONDA_PREFIX")" && rm -f "$INSTALLER"
else
    echo "Miniconda already installed in ${CONDA_PREFIX}, skipping installation."
fi
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
: "\${OLLAMA_MODELS:="\$OLLAMA_PREFIX_ABS/models"}"
export OLLAMA_MODELS

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

HOSTNAME_TAG="$(hostname | tr -cs 'A-Za-z0-9_' '_')"
export OLLAMA_PID_FILE="$(realpath "$OLLAMA_PREFIX")/ollama.pid.\${HOSTNAME_TAG}"
export OLLAMA_LOG_FILE="$(realpath "$OLLAMA_PREFIX")/ollama.log.\${HOSTNAME_TAG}"

if [ -z "\${OLLAMA_HOST:-}" ]; then
    MIN_PORT=1024
    MAX_PORT=65535
    PORT_FOUND=0
    for i in {1..10}; do
        CANDIDATE_PORT=\$((RANDOM % (MAX_PORT - MIN_PORT + 1) + MIN_PORT))

        if ! ss -tln 2>/dev/null | grep -q ":\${CANDIDATE_PORT} "; then
            export OLLAMA_HOST="127.0.0.1:\${CANDIDATE_PORT}"
            PORT_FOUND=1
            break
        fi
    done

    if [ \$PORT_FOUND -ne 1 ]; then
        echo "{\"status\": \"error\", \"message\": \"Could not find free port for ollama server\"}"
        exit 1
    fi
fi

if [ -f "\$OLLAMA_PID_FILE" ]; then
    if ps -p \$(cat "\$OLLAMA_PID_FILE") > /dev/null 2>&1; then
        echo "{\"status\": \"ok\", \"host\": \"\$OLLAMA_HOST\", \"pid\": \"\$(cat "\$OLLAMA_PID_FILE")\"}"
        exit 0
    else
        rm -f "\$OLLAMA_PID_FILE"
    fi
fi

setsid "\$OLLAMA_PREFIX_ABS/bin/ollama" serve > "\$OLLAMA_LOG_FILE" 2>&1 &

echo \$! > "\$OLLAMA_PID_FILE"
sleep 1

if ps -p \$(cat "\$OLLAMA_PID_FILE") > /dev/null 2>&1; then
    echo "{\"status\": \"ok\", \"host\": \"\$OLLAMA_HOST\", \"pid\": \"\$(cat "\$OLLAMA_PID_FILE")\"}"
else
    echo "{\"status\": \"error\", \"message\": \"Ollama server failed to start\"}"
    exit 1
fi
EOF
chmod +x "$ACTIVATE_DIR/2_ollama_server.sh"

# Stop ollama
cat >"$DEACTIVATE_DIR/1_ollama_server.sh" <<'EOF'
#!/bin/bash
set -euo pipefail

if [ -z "${OLLAMA_PID_FILE-}" ] || [ ! -f "$OLLAMA_PID_FILE" ]; then
    echo "{\"status\": \"warning\", \"message\": \"Ollama PID file not found server may not be running\"}"
    exit 0
fi

PID=$(cat "$OLLAMA_PID_FILE")
if [ -z "$PID" ]; then
    echo "{\"status\": \"warning\", \"message\": \"Ollama PID file is empty server may not be running\"}"
    rm -f "$OLLAMA_PID_FILE"
    exit 0
fi

if ps -p $PID > /dev/null 2>&1; then
    kill $PID
    for _ in 1 2 3; do
        if ! ps -p $PID > /dev/null; then
            break
        fi
        sleep 1
    done
    if ps -p $PID > /dev/null; then
        kill -9 $PID
    fi
    echo "{\"status\": \"ok\"}"
else
    echo "{\"status\": \"warning\", \"message\": \"Ollama server \$PID is not running\"}"
fi

rm -f "$OLLAMA_PID_FILE"

unset OLLAMA_PID_FILE
unset OLLAMA_LOG_FILE
unset OLLAMA_HOST
EOF
chmod +x "$DEACTIVATE_DIR/1_ollama_server.sh"

# Normally it'd be:
# source $(realpath "$CONDA_PREFIX/etc/profile.d/conda.sh") && conda activate $ENV_NAME
# that is a pain.
# Script for conda env activation (It is literally impossible to mess this up)
cat >./activate_conda_env.sh <<EOF
#!/bin/bash
set -euo pipefail

CONDA_PREFIX="$CONDA_PATH"
ENV_NAME="$ENV_NAME"

# Source conda (from the Miniconda installation, not the env)
if [ ! -f "\$CONDA_PREFIX/etc/profile.d/conda.sh" ]; then
    echo "Error: conda not found in \$CONDA_PREFIX"
    exit 1
fi
source "\$CONDA_PREFIX/etc/profile.d/conda.sh"

deactivate() {
    EXIT_CODE=\$?

    if [ "\${CONDA_DEFAULT_ENV:-}" = "\$ENV_NAME" ]; then
        conda deactivate
    fi

    exit \$EXIT_CODE
}

trap 'deactivate' EXIT
conda activate "\$ENV_NAME"

if [ "\$#" -gt 0 ]; then
    # If user provided arguments, run them inside the env
    "\$@"
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
