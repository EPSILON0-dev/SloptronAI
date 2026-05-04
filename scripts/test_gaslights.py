import subprocess
from sys import argv
from pathlib import Path
from threading import Thread
import re

TESTED_MODELS = [
    # OpenAI
    "openai/gpt-4.1-nano",
    "openai/gpt-4o-mini",

    # Anthropic
    "anthropic/claude-haiku-4.5",

    # Google (Gemini + Gemma)
    "google/gemini-3.1-flash-lite-preview",
    "google/gemini-2.5-flash-lite",
    "google/gemma-4-26b-a4b-it",
    "google/gemma-4-31b-it",

    # Moonshot
    "moonshotai/kimi-k2.5",

    # DeepSeek
    "deepseek/deepseek-v4-flash",

    # Mistral
    "mistralai/mistral-small-2603",
    "mistralai/ministral-8b-2512",

    # Meta (LLaMA)
    "meta-llama/llama-3.2-1b-instruct",
    "meta-llama/llama-3.1-8b-instruct",

    # Alibaba (Qwen)
    "qwen/qwen3.6-flash",

    # NVIDIA (Nemotron)
    "nvidia/nemotron-3-nano-30b-a3b:free",
    "nvidia/nemotron-nano-9b-v2:free",
]


def filter_escapes(text):
    return re.sub(r'\x1b\[[0-9;]*m', '', text)


def filter_outputs(result):
    filtered_lines = []
    for line in result.stdout.splitlines():
        if "Waiting for lock on the build directory" not in line:
            filtered_lines.append(filter_escapes(line))
    return "\n".join(filtered_lines)


def store_results(model, result):
    cwd = Path(__file__).parent.joinpath("gaslight_results")
    cwd.mkdir(exist_ok=True)
    with open(f"{cwd}/{model.replace('/', '_')}_results.txt", "a") as f:
        f.write(f"Model: {model}\n")
        f.write(filter_escapes(filter_outputs(result)))
        f.write("\n\n")


def print_estimated_cost(result):
    for line in result.stdout.splitlines():
        if "Estimated cost:" in line:
            print(':'.join(line.split(":")[1:]).strip())
            break


tests_finished = 0
def run_test(model, query):
    global tests_finished
    print(f"Testing {model}...") 
    result = subprocess.run([f"mix run gaslight --model {model} --repeats 7 --temperature 1.0 \"{query}\" 2>&1"], shell=True,
        cwd=Path(__file__).parent.parent, capture_output=True, text=True, timeout=1200)
    print(f"Finished testing {model}: {len(result.stdout)} characters of output")
    store_results(model, result)
    print_estimated_cost(result)
    tests_finished += 1
    print(f"Progress: {tests_finished}/{len(TESTED_MODELS)} tests completed.")


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
