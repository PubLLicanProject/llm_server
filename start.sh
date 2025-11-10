#!/bin/bash --login
#conda activate ./llama_server_env
./activate_conda_env.sh
python llama_server.py $@
