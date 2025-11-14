bash ./build.sh

# for other models check https://ollama.com/library
# alternatively: ./activate_conda_env.sh ollama pull llama3-chatqa:8b
./activate_conda_env.sh python get_model.py llama3-chatqa:8b
./start.sh llama3-chatqa:8b &
./prompt.sh "Tell me a joke about a computer scientist who couldn't write a shell script."
./exit.sh
