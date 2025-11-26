import requests
import os, sys, time
import base64
import json

modelname = os.getenv("MODELNAME", "llama3-chatqa:8b")
model_options = {}
model_options["seed"] = int(os.getenv("MODEL_SEED", "9342"))
model_options["n_ctx"] = int(os.getenv("OLLAMA_CONTEXT_LENGTH", "17048"))

datapath = os.getenv("DATAPATH", "./data")

system_prompt = os.getenv(
    "SYSTEM_PROMPT",
    "You are a helpful assistant curating data.  If a question does not"
    " make any sense, or is not factually coherent, explain why instead of answering something not correct. If you"
    " don't know the answer to a question, please don't share false information. Give a complete answer, do not try to continue the conversation.",
)

ollama_host = os.getenv("OLLAMA_HOST", "127.0.0.1:11434")

if not ollama_host.startswith("http://") and not ollama_host.startswith("https://"):
    ollama_host = "http://" + ollama_host


def setup_folders():
    if not os.path.exists(datapath):
        os.makedirs(datapath)
        os.makedirs(datapath + "/input")
        os.makedirs(datapath + "/output")
        os.makedirs(datapath + "/pending")
        os.makedirs(datapath + "/completed")
        os.makedirs(datapath + "/results")
        os.makedirs(datapath + "/tempoutput")
        os.makedirs(datapath + "/tempinput")


def wait_for_prompt():
    folder_path = datapath + "/input"
    while True:
        if len(os.listdir(folder_path)) > 0:
            break
        time.sleep(2)

    files = [
        os.path.join(folder_path, f)
        for f in os.listdir(folder_path)
        if os.path.isfile(os.path.join(folder_path, f))
    ]

    # Ensure there are files in the folder
    # Find the oldest file by comparing creation times
    file = min(files, key=os.path.getctime)
    file = os.path.basename(file)

    with open(f"data/input/{file}", "r") as f:
        return [file, f.read()]


def log_json(event, **fields):
    record = {"event": event, **fields}
    print(json.dumps(record, ensure_ascii=False), flush=True)


def api_request(messages, options=None):
    url = f"{ollama_host}/v1/chat/completions"
    chat = {
        "model": modelname,
        "messages": messages,
    }

    if options:
        chat["options"] = options

    try:
        response = requests.post(url, json=chat)
        response.raise_for_status()
        data = response.json()
        content = data["choices"][0]["message"]["content"]
        return content
    except Exception as e:
        raise RuntimeError(f"API request failed: {str(e)}")


def run_server():
    setup_folders()
    start = time.time()
    while True:
        try:
            file, prompt = wait_for_prompt()

            log_json("prompt_received", prompt=prompt, file=file)
            # move input file to pending
            infile = f"{datapath}/input/{file}"

            tempoutfile = f"{datapath}/tempoutput/{file}"
            outfile = f"{datapath}/output/{file}"

            # check for instructions in first word
            words = prompt.split()
            if words[0].strip().lower() == "exit:":
                os.remove(infile)
                break
            if words[0].strip().lower() == "b64:":
                prompt = base64.b64decode(words[1]).decode("utf-8")

            os.rename(infile, f"{datapath}/pending/{file}")

            messages = [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": prompt},
            ]

            try:
                content = api_request(messages, model_options)

                if not content:
                    raise ValueError(f"no content returned from model: {response}")

                # save the message to a file, it's temporary so that the move operation is atomic
                with open(tempoutfile, "w") as f:
                    f.write(content)

            except Exception as pe:
                log_json("processing_error", error=str(pe), file=file)
                os.rename(f"{datapath}/pending/{file}", f"{datapath}/input/{file}")
                if path.exists(tempoutfile):
                    os.remove(tempoutfile)

            # move temp file to output
            os.rename(tempoutfile, outfile)
            # move file from pending to completed
            os.rename(f"{datapath}/pending/{file}", f"{datapath}/completed/{file}")

            log_json("model_response", response=content, file=file)

        except Exception as e:
            log_json("error", error=str(e))
            pass

    end = time.time()
    log_json("exit", elapsed_seconds=end - start)


if __name__ == "__main__":
    if len(sys.argv) > 1:
        modelname = sys.argv[1]

    run_server()
