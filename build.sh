#To use LLama models, you may need to get approval and log into a huggingface account.
# log into huggingface  account with the following command: huggingface-cli login
# (after installing huggingface-hub)

#Install miniconda into your local user
#Download the latest miniconda installer from https://docs.conda.io/en/latest/miniconda.html
#Run the installer

# example.sh
# exit.sh
# get_model.py
# llama_server.py
# prompt.sh
# promptb64.sh
# readme.txt
# requirements.txt
# slexample.sh
# slurm_start.sh
# start.sh


#wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
#bash Miniconda3-latest-Linux-x86_64.sh

chmod 755 *.sh
conda install python=3.10

conda install -y anaconda::git
conda install -y -c conda-forge gxx


pip install -r requirements.txt
git clone https://github.com/ggerganov/llama.cpp
cd llama.cpp
make
cd ..



