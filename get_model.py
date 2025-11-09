import sys
import ollama


def main(model_name):
    print(f"Checking for Ollama model '{model_name}'.")

    try:
        # See if model already exists locally
        local_models = ollama.list().get("models", [])
        if any(m["name"] == model_name for m in local_models):
            print(f"Model '{model_name}' already exists locally.")
            return

        print(f"Pulling model '{model_name}' from Ollama Hub.")
        result = ollama.pull(model_name)

        if isinstance(result, dict) and "model" in result:
            print(f"Successfully pulled model: {result['model']}")
        # TODO: Which ollama version forced me to use this?
        # is it still needed?
        else:
            print(f"Finished pulling model '{model_name}'")

    except ollama.ResponseError as e:
        print(f"Failed to pull model '{model_name}': {e}")
    except Exception as e:
        print(f"Unexpected error: {e}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python get_ollama_model.py <model_name>")
        print("Example: python get_ollama_model.py llama2:7b")
        sys.exit(1)

    model_name = sys.argv[1]
    main(model_name)
