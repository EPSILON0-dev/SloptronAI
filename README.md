# Sloptron AI

![Sloptron Logo](./docs/sloptron.png)

Make your favourite LLM sound like it's smoking crack! Sloptron AI is a command-line tool written in Elixir that intentionally degrades text through repeated high-temperature LLM prompts, then attempts to clean the result back into a coherent response.

## Overview

Sloptron AI runs a multi-stage pipeline that transforms an input query using different prompting strategies:

1. **Extractor:** Normalises the query into English and detects the input language.
2. **Initial Generator:** Produces a deliberately dumb and slightly nonsensical first response.
3. **Slopifier:** Applies N rounds of high-temperature prompting to progressively degrade coherence.
4. **Unslopifier** *(optional)*: Attempts to hide the stupidity while preserving the essence of the slopified output.
5. **Translator** *(if needed)*: Translates the result back into the original input language.

```
Extractor --> Initial Generator --> Slopifier (x N) --> [Unslopifier] --> [Translator]
```

Each stage streams its output to stderr in real time. The estimated API cost is printed at the end.

## Backstory

This project exists for one reason: I needed to learn the basics of Elixir. The slopification pipeline was a good excuse to explore the language's syntax, pattern matching, and standard library without building something boring.

## Requirements

- Elixir `~> 1.12`
- An [OpenRouter](https://openrouter.ai) API key

## Setup

```sh
mix deps.get
export OPENROUTER_API_KEY="sk-or-..."
```

## Usage

```sh
mix run "What is the capital of France?"
```

By default, 3 slopification rounds are run using `gpt-4.1-mini`. Pass `--` before your options to separate them from Mix's own flags.

### Options

| Flag | Type | Default | Description |
|---|---|---|---|
| `--openrouter-api-key` | string | `$OPENROUTER_API_KEY` | OpenRouter API key |
| `--openrouter-api-url` | string | `https://openrouter.ai/api/v1` | OpenRouter base URL |
| `--main-model` | string | `gpt-4.1-mini` | Model used for all stages |
| `--unslopifier-model` | string | `gpt-4.1-mini` | Reserved for the unslopifier stage |
| `--slopifier-rounds` | integer | `3` | Number of slopification rounds |
| `--no-unslopifier` | boolean | `false` | Skip the unslopifier stage |
| `--temperature` | float | `1.0` | Sloppifier model temperature |
| `--quiet` | boolean | `false` | Suppress streaming token output (stage labels still go to stderr; use `2>/dev/null` to silence those too) |

### Examples

```sh
# 5 rounds of slopification
mix run --slopifier-rounds 5 "Write a short product description for a portable coffee mug"

# Skip unslopifier, quiet output
mix run --no-unslopifier --quiet "Explain gravity"

# Use a different model
mix run --main-model "openai/gpt-4.1" "What is 2+2?"
```

## License

MIT License [LICENSE](LICENSE)
