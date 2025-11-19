bash ./build.sh

# for other models check https://ollama.com/library
./activate_conda_env.sh ollama pull llama3-chatqa:8b
sbatch ./slurm_start.sh llama3-chatqa:8b
./prompt.sh "Tell me a joke about a computer scientist who couldn't write a shell script."
./exit.sh
