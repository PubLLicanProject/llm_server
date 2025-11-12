#To use LLama models, you may need to get approval and log into a huggingface account.
# log into huggingface  account with the following command: huggingface-cli login
# (after installing huggingface-hub)

bash ./build.sh

# for other models check https://ollama.com/library
./activate_conda_env.sh python get_model.py llama3-chatqa:8b
sbatch ./slurm_start.sh llama3-chatqa:8b
./prompt.sh "Tell me a joke about a computer scientist who couldn't write a shell script."
./exit.sh
