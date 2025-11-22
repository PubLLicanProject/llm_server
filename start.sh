#!/bin/bash --login
source ollama_env/bin/activate
python llama_server.py "$@"
