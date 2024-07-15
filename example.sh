chmod 755 *.sh
conda create -y -p ./llama_server_env python=3.10
conda activate ./llama_server_env

#these may be pre-installed, or available as modules
conda install -y anaconda::git
conda install -y -c conda-forge gxx

pip install -r requirements.txt
git clone https://github.com/ggerganov/llama.cpp
cd llama.cpp
make
cd ..

python get_model.py nvidia/Llama3-ChatQA-1.5-8B
#Using 8-bit quantized model for testing
./start.sh nvidia/Llama3-ChatQA-1.5-8B_Q8_0 &
./prompt.sh "Tell me a joke about a computer scientist who couldn't write a shell script."
./exit.sh
