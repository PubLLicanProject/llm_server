#!/bin/bash
source ollama_env/bin/activate

if [ $# -lt 2 ]; then
    echo "Usage: $0 <model_name> <prompt>"
    exit 1
fi

modelname="$1"
shift
prompt=$(printf "%s" "$*" | base64 --decode)
ollama run "$modelname" "$prompt"
