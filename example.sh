
conda create -y -p ./llama_server_env python=3.10
conda activate ./llama_server_env
conda install -y anaconda::git


pip install -r requirements.txt
git clone https://github.com/ggerganov/llama.cpp
cd llama.cpp
make
cd ..

python get_model.py nvidia/Llama3-ChatQA-1.5-8B
./start.sh nvidia/Llama3-ChatQA-1.5-8B &
./prompt.sh "Tell me a joke about shell scripts."
./exit.sh
