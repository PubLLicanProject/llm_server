You will need to use a conda environment and ollama

Install conda first, e.g. Download the latest miniconda installer from https://docs.conda.io/en/latest/miniconda.html and Run the installer
Then install ollama from https://ollama.com/
Alternatively, build.sh will automatically install ollama and conda in local prefixes

example / slexample.sh has an example of all the steps that are needed

source ./slexample.sh should run completely on a slurm cluster and setup everything - but beware that slurm_start.sh
includes parameters that are specific to the cluster it is running on

The conda environment and all other required folders will be created in the current directory
(This will be fairly big, you should use a volume with enough storage - such as a "volatile" folder)

When you run the script, it will create a local conda environment and install all the necessary packages
It will also install ollama.

Then it will run an example model (A Llama variant from nvidia) - slexample.sh calls sbatch to run the specified model on a slurm cluster
example.sh will run it without slurm

More about getting models can be found at https://ollama.com/search and https://docs.ollama.com/import
Ollama models can be pulled with ./activate_conda_env.sh ollama pull <model_name>

Once installed and running you can use the following scripts to interact with the server

activate_conda_env.sh will activate the conda environment and ollama server installed by build.sh
sbatch slurm_start.sh <model_name> will start the server with the model
prompt.sh will generate text using the prompt or promptb64.sh will take a base64 encoded prompt
(To handle special characters inside the prompt)
exit.sh will tell the server to shutdown


