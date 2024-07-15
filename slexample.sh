#To use LLama models, you may need to get approval and log into a huggingface account.
# log into huggingface  account with the following command: huggingface-cli login
# (after installing huggingface-hub)

#Install miniconda into your local user
#Download the latest miniconda installer from https://docs.conda.io/en/latest/miniconda.html
#Run the installer

conda create -y -p ./llama_server_env python=3.10
conda activate ./llama_server_env
conda install -y anaconda::git


pip install -r requirements.txt
git clone https://github.com/ggerganov/llama.cpp
cd llama.cpp
make
cd ..

python get_model.py nvidia/Llama3-ChatQA-1.5-8B
sbatch ./slurm_start.sh nvidia/Llama3-ChatQA-1.5-8B
#./start.sh nvidia/Llama3-ChatQA-1.5-8B &
./prompt.sh "Tell me a joke about shell scripts."
./exit.sh

