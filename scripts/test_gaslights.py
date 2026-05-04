import subprocess
from sys import argv
from pathlib import Path
from threading import Thread

TESTED_MODELS = [
    # OpenAI
    "openai/gpt-5-nano",
    "openai/gpt-5-mini",
    "openai/gpt-4.1-nano",
    "openai/gpt-4o-mini",

    # Anthropic
    "anthropic/claude-4.5-haiku",
    "anthropic/claude-4-haiku",
    "anthropic/claude-3.5-haiku",
    "anthropic/claude-3-haiku",

    # Google (Gemini + Gemma)
    "google/gemini-3.1-flash",
    "google/gemini-2.5-flash",
    "google/gemma-4-26b-a4b",
    "google/gemma-4-31b",

    # Amazon
    "amazon/nova-micro",
    "amazon/nova-lite",
    "amazon/titan-lite",

    # Moonshot
    "moonshot/kimi-k2.5",

    # xAI
    "xai/grok-4.1-fast",
    "xai/grok-mini",
    "xai/grok-3-mini",

    # DeepSeek
    "deepseek/deepseek-v3",

    # Mistral
    "mistral/mistral-small-3",
    "mistral/mistral-3b",
    "mistral/mistral-small",

    # Meta (LLaMA)
    "meta-llama/llama-3.2-1b",
    "meta-llama/llama-3.1-8b",

    # Alibaba (Qwen)
    "alibaba/qwen-2.5-3b",
    "alibaba/qwen-2-1.8b",

    # Zhipu (GLM)
    "zhipu/glm-5-flash",
    "zhipu/glm-4.7-flash",

    # MiniMax
    "minimax/minimax-m2.5",
    "minimax/minimax-m2.1",

    # NVIDIA (Nemotron)
    "nvidia/nemotron-3-super",
    "nvidia/nemotron-4-15b",
]


def store_results(model, result):
    cwd = Path(__file__).parent.joinpath("results")
    cwd.mkdir(exist_ok=True)
    with open(f"{cwd}/{model.replace('/', '_')}_results.txt", "a") as f:
        f.write(f"Model: {model}\n")
        f.write(result.stdout)
        f.write("\n\n")


def print_estimated_cost(result):
    for line in result.stdout.splitlines():
        if "Estimated cost:" in line:
            print(':'.join(line.split(":")[1:]).strip())
            break


def run_test(model, query):
    print(f"Testing {model}...") 
    result = subprocess.run([f"mix run gaslight --model {model} --repeats 7 --temperature 1.0 \"{query}\" 2>&1"], shell=True,
        cwd=Path(__file__).parent.parent, capture_output=True, text=True, timeout=600)
    print(f"Finished testing {model}: {len(result.stdout)} characters of output")
    store_results(model, result)
    print_estimated_cost(result)


def main():
    query = "Why is the sky blue?" if len(argv) < 2 else argv[1]
    threads = []
    for index, model in enumerate(TESTED_MODELS):
        thread = Thread(target=run_test, args=(model, query))
        thread.start()
        threads.append(thread)

    for thread in threads:
        thread.join()


if __name__ == "__main__":
    main()
