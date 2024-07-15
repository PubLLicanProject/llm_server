#!/bin/bash --login
conda activate ./llama_server_env
python llama_server.py ./models/$@

