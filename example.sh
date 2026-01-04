bash ./build.sh

# for other models check https://ollama.com/library
source ollama_env/bin/activate
ollama pull llama3-chatqa:8b
deactivate
./start.sh llama3-chatqa:8b &
./enqueue_prompt.sh "Tell me a joke about a computer scientist who couldn't write a shell script."
./exit.sh
