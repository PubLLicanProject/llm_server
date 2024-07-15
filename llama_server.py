from llama_cpp import Llama
import os, sys, time
import base64
import torch


engine = None
datapath = "./data"

system_prompt=("You are a helpful assistant curating data.  If a question does not"
" make any sense, or is not factually coherent, explain why instead of answering something not correct. If you"
" don't know the answer to a question, please don't share false information. Give a complete answer, do not try to continue the conversation.")


def setup_folders():
    if not os.path.exists(datapath):
        os.makedirs(datapath)
        os.makedirs(datapath+"/input")
        os.makedirs(datapath+"/output")
        os.makedirs(datapath+"/pending")
        os.makedirs(datapath+"/completed")
        os.makedirs(datapath+"/results")
        os.makedirs(datapath+"/tempoutput")
        os.makedirs(datapath+"/tempinput")
def wait_for_prompt():
    folder_path = datapath+"/input"
    while True:
        if len(os.listdir(folder_path)) > 0:
            break
        time.sleep(2)
        print(".", end="")

    files = [os.path.join(folder_path, f) for f in os.listdir(folder_path) if
             os.path.isfile(os.path.join(folder_path, f))]

    # Ensure there are files in the folder
    # Find the oldest file by comparing creation times
    file = min(files, key=os.path.getctime)
    file = os.path.basename(file)

    with open(f"data/input/{file}", "r") as f:
        return [file,f.read()]



def run_server():
    setup_folders()
    start = time.time()
    while True:
        try:
            file,prompt = wait_for_prompt()

            print("Prompt:", prompt, "File:", file)
            #move input file to pending
            infile = f"data/input/{file}"

            tempoutfile = f"data/tempoutput/{file}"
            outfile = f"data/output/{file}"

            #check for instructions in first word
            words = prompt.split()
            if words[0].strip().lower() == "exit:":
                os.remove(infile)
                break
            if words[0].strip().lower() == "b64:":
                prompt = base64.b64decode(words[1]).decode("utf-8")
                print("Decoded Prompt:", prompt)

            os.rename(infile, f"data/pending/{file}")

            response = engine.create_chat_completion(messages=[{"role": "system", "content": system_prompt},
                {"role": "user", "content": prompt}])

            choices = response["choices"]
            fc = choices[0]
            message = fc["message"]
            content = message["content"]

            # save the message to a file, it's temporary so that the move operation is atomic
            with open(tempoutfile, "w") as f:
                f.write(content)

            #move temp file to output
            os.rename(tempoutfile, outfile)
            #move file from pending to completed
            os.rename(f"data/pending/{file}", f"data/completed/{file}")


            print("AI:", message)
        except Exception as e:
            print(e)
            pass

    end = time.time()
    print(end - start)

# use `asyncio.run` to call your async function to start the program


if __name__ == "__main__":


    use_gpu = torch.cuda.is_available()
    if use_gpu:
        print("Using GPU")
        gpu_layers = -1
    else:
        print("Using CPU")
        gpu_layers = 0

    #The engine filename can be passed as an argument to the script
    #
    filename = "models/nvidia/Llama3-ChatQA-1.5-8B_Q8_0"
    if len(sys.argv) >1:
        filename = sys.argv[1]
    if not filename.lower().endswith(".gguf"):
        filename = filename + ".gguf"


    engine = Llama(
        model_path=filename,
        n_gpu_layers = gpu_layers,
        # chat_format="llama-3",
        # seed=1337, # Uncomment to set a specific seed
        n_ctx=17048,  # Uncomment to increase the context window
    )

    run_server()
