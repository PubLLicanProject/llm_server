#!/bin/bash

# This script:
# Installs Ollama
# Creates a standard Python venv
# Modifies the venv's bin/activate script to:
#  - Start Ollama when activated
#  - Stop Ollama when deactivated

set -euo pipefail

: "${ENV_PREFIX:=$(realpath ollama_env)}"
: "${PYTHON:=python3}"

: "${OLLAMA_VERSION:=0.12.11}"
: "${OLLAMA_PREFIX:=$ENV_PREFIX/ollama_$OLLAMA_VERSION}"
: "${OLLAMA_MODELS:=$ENV_PREFIX/models}"

echo "A venv environment will be created at $ENV_PREFIX."
echo "When activated the ENV will start an ollama server version $OLLAMA_VERSION, with binaries located at $OLLAMA_PREFIX."
echo "$OLLAMA_MODELS will be used as the models directory."

if [[ -t 0 ]]; then
    read -p "Continue? [Y/n] " c_choice

    echo "Please select your GPU type for Ollama installation:"
    echo "  1) AMD"
    echo "  2) NVIDIA"
    echo
    echo -n "Enter your choice [1-2]: "
    read -r g_choice
else
    echo "Non-interactive mode detected. Defaulting to continue."
    c_choice="Y"
    echo "Defaulting to NVIDIA."
    g_choice=2
fi

case "$c_choice" in
[Nn]*)
    echo "Exiting."
    exit 1
    ;;
*)
    echo "Continuing."
    ;;
esac

case "$g_choice" in
1) GPU="AMD" ;;
*) GPU="NVIDIA" ;;
esac

chmod +x ./*.sh
if [ ! -f "$ENV_PREFIX/pyvenv.cfg" ]; then
    echo "Creating python venv in $ENV_PREFIX"
    $PYTHON -m venv "$ENV_PREFIX"
else
    echo "Venv already exists in $ENV_PREFIX"
fi

if [ -f "requirements.txt" ]; then
    echo "Installing requirements."
    "$ENV_PREFIX/bin/pip" install -r requirements.txt
fi

mkdir -p "$OLLAMA_PREFIX"
mkdir -p "$OLLAMA_MODELS"

if [ -x "$OLLAMA_PREFIX/bin/ollama" ]; then
    echo "Ollama already installed at $OLLAMA_PREFIX/bin/ollama, skipping installation."
else
    echo "Downloading Ollama bundle version $OLLAMA_VERSION."
    curl -L "https://github.com/ollama/ollama/releases/download/v$OLLAMA_VERSION/ollama-linux-amd64.tgz" | tar zx -C "$OLLAMA_PREFIX"
fi

if [ "$GPU" = "AMD" ]; then
    if [ -d "$OLLAMA_PREFIX/lib/rocm/" ]; then
        echo "ROCM bundle already installed at $OLLAMA_PREFIX/lib/rocm/, skipping installation."
    else
        echo "Downloading AMD ROCm Ollama version $OLLAMA_VERSION."
        curl -L "https://github.com/ollama/ollama/releases/download/v$OLLAMA_VERSION/ollama-linux-amd64-rocm.tgz" | tar zx -C "$OLLAMA_PREFIX"
    fi
fi

ACTIVATE_SCRIPT="$ENV_PREFIX/bin/activate"
OLLAMA_ABS_PATH="$(realpath "$OLLAMA_PREFIX")"

echo "Injecting Ollama hooks into $ACTIVATE_SCRIPT."

if ! grep -q "OLLAMA_STARTUP_LOGIC" "$ACTIVATE_SCRIPT"; then
    cat >>"$ACTIVATE_SCRIPT" <<EOF
# OLLAMA_STARTUP_LOGIC
# 1. Configure Environment
: "\${OLLAMA_PREFIX:=$OLLAMA_ABS_PATH}"
: "\${OLLAMA_MODELS:=$OLLAMA_MODELS}"

export OLLAMA_PREFIX
export OLLAMA_MODELS
export PATH="\$OLLAMA_PREFIX/bin:\$PATH"

# 2. Start Server Logic
HOSTNAME_TAG="\$(hostname | tr -cs 'A-Za-z0-9_' '_')"
export OLLAMA_PID_FILE="\$OLLAMA_PREFIX/ollama.pid.\${HOSTNAME_TAG}"
export OLLAMA_LOG_FILE="\$OLLAMA_PREFIX/ollama.log.\${HOSTNAME_TAG}"

if [ -z "\${OLLAMA_HOST:-}" ]; then
    MIN_PORT=1024
    MAX_PORT=65535
    PORT_FOUND=0

    # Try to find a free port
    for i in {1..10}; do
        CANDIDATE_PORT=\$((RANDOM % (MAX_PORT - MIN_PORT + 1) + MIN_PORT))
        if ! ss -tln 2>/dev/null | grep -q ":\${CANDIDATE_PORT} "; then
            export OLLAMA_HOST="127.0.0.1:\${CANDIDATE_PORT}"
            PORT_FOUND=1
            break
        fi
    done

    if [ \$PORT_FOUND -eq 1 ]; then
        if [ -f "\$OLLAMA_PID_FILE" ]; then
             if ! ps -p \$(cat "\$OLLAMA_PID_FILE") > /dev/null 2>&1; then
                rm -f "\$OLLAMA_PID_FILE"
             fi
        fi

        nohup "\$OLLAMA_PREFIX/bin/ollama" serve > "\$OLLAMA_LOG_FILE" 2>&1 &
        echo \$! > "\$OLLAMA_PID_FILE"

        ATTEMPTS=10
        while [ \$ATTEMPTS -gt 0 ]; do
              if ps -p \$(cat "\$OLLAMA_PID_FILE") > /dev/null 2>&1; then
                 SERVER_UP=1
                 break
              fi
              sleep 1
              ATTEMPTS=\$((ATTEMPTS - 1))
        done

        if [ "\${SERVER_UP:-0}" -eq 1 ]; then
           trap stop_ollama_server EXIT
           echo "{\"status\": \"ok\", \"host\": \"\$OLLAMA_HOST\", \"pid\": \"\$(cat "\$OLLAMA_PID_FILE")\"}"
        else
           echo "{\"status\": \"error\", \"message\": \"Ollama server failed to start within timeout.\"}"
        fi
    else
        echo "{\"status\": \"error\", \"message\": \"Could not find free port for ollama server\"}"
    fi
else
    echo "{\"status\": \"ok\", \"host\": \"\$OLLAMA_HOST\"}"
fi
EOF
fi

# Prepend the stop function
if ! grep -q "^stop_ollama_server()" "$ACTIVATE_SCRIPT"; then
    cat - "$ACTIVATE_SCRIPT" <<EOF >temp && mv temp "$ACTIVATE_SCRIPT"
stop_ollama_server() {
    if [ -z "\${OLLAMA_PID_FILE-}" ] || [ ! -f "\$OLLAMA_PID_FILE" ]; then
        return 0
    fi

    local PID=\$(cat "\$OLLAMA_PID_FILE")
    if [ -n "\$PID" ] && ps -p \$PID > /dev/null 2>&1; then
        kill \$PID
        for _ in 1 2 3; do
            if ! ps -p \$PID > /dev/null; then break; fi
            sleep 0.5
        done
        if ps -p \$PID > /dev/null; then kill -9 \$PID; fi
        echo "{\"status\": \"killed\"}"
    else
        echo "{\"status\": \"warning\", \"message\": \"Ollama server \$PID is not running\"}"
    fi

    rm -f "\$OLLAMA_PID_FILE"

    unset OLLAMA_PID_FILE
    unset OLLAMA_LOG_FILE
    unset OLLAMA_HOST
    unset OLLAMA_MODELS
}
EOF
fi

# Inject call to stop ollama server in deactivate function
if grep -q "stop_ollama_server" "$ACTIVATE_SCRIPT"; then
    if ! grep -q "deactivate () {.*stop_ollama_server" "$ACTIVATE_SCRIPT"; then
        sed -i '/^deactivate () {/a \ \ \ \ stop_ollama_server\n    trap - EXIT' "$ACTIVATE_SCRIPT"
    fi
fi

echo "Setup complete."
echo "To use: source $ENV_PREFIX/bin/activate"
