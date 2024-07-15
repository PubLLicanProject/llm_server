You will need to use a conda environment

Install conda first, e.g. Download the latest miniconda installer from https://docs.conda.io/en/latest/miniconda.html and Run the installer

example / slexample.sh has an example of all the steps that are needed

source ./slexample.sh should run completely on a slurm cluster and setup everything - but beware that slurm_start.sh
includes parameters that are specific to the cluster it is running on

The conda environment and all other required folders will be created in the current directory
(This will be fairly big, you should use a volume with enough storage - such as a "volatile" folder)

When you run the script, it will create a local conda environment and install all the necessary packages
It will also install and build llama.cpp, which will be needed for conversion and quantisation

Then it will run the conversion and quantisation for an example model (A Llama variant from nvidia)
This can then be executed - slexample.sh calls sbatch to run the specified model on a slurm cluster
example.sh will run it without slurm

One installed and running you can use the following scripts to interact with the server

get_model.py <model_name> will download a model and create quantised versions of it
sbatch slurm_start.sh <model_name> will start the server with the model
prompt.sh will generate text using the prompt or promptb64.sh will take a base64 encoded prompt
(To handle special characters inside the prompt)
exit.sh will tell the server to shutdown


