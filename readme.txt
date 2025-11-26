You will need and ollama server and the python package

Ollama can be installed from https://ollama.com/

Alternatively, build.sh will automatically create a python venv with the
requirements installed, and an ollama server activated when sourcing the env.
The following environment variables can be exported for build.sh to use:
 - ENV_PREFIX     (default: ollama_env)
 - PYTHON         (default: python3)
 - OLLAMA_VERSION (default: 0.12.11)
 - OLLAMA_PREFIX  (default: ollama_env/ollama_0.12.11)
 - OLLAMA_MODELS  (default: ollama_env/models)
(The default env path is hard-coded into start.sh, update the script if changing the path)

example.sh / slexample.sh has an example of all the steps that are needed

source ./slexample.sh should run completely on a slurm cluster and setup everything - but beware that slurm_start.sh includes parameters that are specific to the cluster it is running on.

The venv environment and all other required folders will be created in the current directory.
(This will be fairly big, you should use a volume with enough storage - such as a "volatile" folder)

When you run the script, it will create a local venv environment and install all the necessary packages, it will also install ollama.

Then it will run an example model (A Llama variant from nvidia) - slexample.sh calls sbatch to run the specified model on a slurm cluster.
example.sh will run it without slurm.

More about getting models can be found at https://ollama.com/search and https://docs.ollama.com/import
Ollama models can be pulled by sourcing the activate script of the venv, then running ollama pull <model_name>

Once installed and running you can use the following scripts to interact with the server

source ollama_env/bin/activate will activate the environment and ollama server installed by build.sh
start.sh <model_name> will start the server with the model
sbatch slurm_start.sh <model_name> will enqueue the server slurm job with the model
prompt.sh will generate text using the prompt or promptb64.sh will take a base64 encoded prompt
(To handle special characters inside the prompt)
exit.sh will tell the server to shutdown

The following environment variables can be exported to overwrite the defaults in the venv:
 - OLLAMA_PREFIX
 - OLLAMA_MODELS

The following environment variables can be exported to modify the llama_server.py behaviour:
 - MODELNAME (overriden by first argument of llama_server.py, default: llama3-chatqa:8b")
 - MODEL_SEED (default: 9342)
 - OLLAMA_CONTEXT_LENGTH (default: 17048)
 - DATAPATH (default: ./data)
 - SYSTEM_PROMPT (default in lines 12-16 of llama_server.py)
 - OLLAMA_HOST (corrected default is exported during env activation, default: 127.0.0.1:11434)
