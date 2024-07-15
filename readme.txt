You will need to use a conda environment
Install conda first, e.g. Download the latest miniconda installer from https://docs.conda.io/en/latest/miniconda.html and Run the installer
example / slexample.sh has Is an example of all the steps that are needed
it will create a local conda environment and install all the necessary packages
It will also install and build llama.cpp, which will be needed for conversion and quantisation

Then it will run the conversion and quantisation for an example model (A Llama variant from nvidia)
This can then be executed - slexample.sh calls sbatch to run the specified model on a slurm cluster
example.sh will run it without slurm

use the prompt.sh script to generate text using the prompt; it will wait for a result before displaying
use exit.sh to tell the server to shutdown
promptb64.sh will take a base64 encoded prompt - this will be decoded later
(as passing special characters via command line can be tricky)

