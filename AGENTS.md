# SloptronAI - Agent Documentation

## Project Overview

SloptronAI is a command-line tool written in Elixir that intentionally degrades text through repeated high-temperature LLM prompts, then attempts to clean the result back into a coherent response. It supports three modes: `slopify`, `translate-hell`, and `gaslight`.

**Repository Purpose:** This project was created as a learning exercise for Elixir fundamentals.

## Technology Stack

- **Language:** Elixir (~> 1.12)
- **Build Tool:** Mix
- **External API:** OpenRouter (for LLM access)
- **HTTP Client:** `req` library (v0.4) - for API requests and streaming
- **JSON Parsing:** `jason` library (transitive dependency)

## Project Structure

```
src/
├── main.ex           # Entry point: dispatches to mode handlers
├── config.ex         # CLI argument parsing and configuration struct
├── openrouter.ex     # HTTP client for OpenRouter API (streaming support)
├── slopify.ex        # "slopify" mode implementation
├── translate_hell.ex # "translate-hell" mode implementation
└── gaslight.ex       # "gaslight" mode implementation

mix.exs               # Project configuration and dependencies
mix.lock              # Dependency lock file
```

**Note:** Source files are located in `src/` rather than the standard Elixir `lib/` directory. Modules use `Code.require_file` for intra-project dependencies instead of standard Mix compilation.

## Module Organization

All modules are namespaced under `SloptronAI`:

| Module | Purpose |
|--------|---------|
| `SloptronAI.Main` | Entry point, mode dispatch |
| `SloptronAI.Config` | Configuration struct and CLI parsing |
| `SloptronAI.OpenRouter` | API client with streaming support |
| `SloptronAI.Slopify` | Text degradation pipeline |
| `SloptronAI.TranslateHell` | Multi-language telephone game |
| `SloptronAI.Gaslight` | AI gaslighting dialogue loop |

## Build Commands

```bash
# Install dependencies
mix deps.get

# Run the application
mix run <mode> "your query here"

# Examples:
mix run slopify "Write a product description for a coffee mug"
mix run translate-hell --rounds 5 "What is the capital of France?"
mix run gaslight --repeats 3 "Why is the sky blue?"
```

## Runtime Requirements

- **Environment Variable:** `OPENROUTER_API_KEY` must be set
- **Default Model:** `openai/gpt-4.1-mini`
- **Default API URL:** `https://openrouter.ai/api/v1`

## Configuration Options

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `--openrouter-api-key` | string | `$OPENROUTER_API_KEY` | API key |
| `--openrouter-api-url` | string | OpenRouter URL | Base API URL |
| `--model` | string | `openai/gpt-4.1-mini` | Model for all stages |
| `--rounds` | integer | `3` | Number of rounds (slopify, translate-hell) |
| `--repeats` | integer | `3` | Number of gaslight cycles |
| `--no-unslopifier` | boolean | `false` | Skip unslopifier (slopify only) |
| `--temperature` | float | `1.0` | Temperature for creative stages |
| `--quiet` | boolean | `false` | Suppress token streaming |

## Code Style Guidelines

1. **Module Structure:**
   - Use `@moduledoc false` for internal modules
   - Define type specs with `@spec` and `@type`
   - Use module attributes (`@const_name`) for prompts and constants

2. **Naming Conventions:**
   - Modules: PascalCase (`SloptronAI.Slopify`)
   - Functions: snake_case (`run_extractor`)
   - Private functions: prefixed with `defp`

3. **Type Definitions:**
   ```elixir
   @type stage_result :: {text :: binary(), cost :: float()}
   @type request_func_t :: (Config.t(), binary(), binary(), map() -> stage_result())
   ```

4. **Error Handling:**
   - Custom exceptions defined as submodules (e.g., `NoSuchFileException`)
   - Use `try/rescue` for API error handling
   - Print errors to stderr with `IO.puts(:stderr, ...)`

5. **Output Conventions:**
   - Stage labels: stdout (with ANSI bold: `\x1b[1m`)
   - Streaming tokens: stderr (with ANSI dim: `\x1b[2m`)
   - Final output: stdout
   - Cost estimate: stderr with final output label

## Architecture Details

### Slopify Pipeline

```
Extractor → Initial Generator → Slopifier (xN) → [Unslopifier] → [Translator]
```

1. **Extractor:** Normalizes query to English, detects language (JSON schema)
2. **Initial Generator:** Creates a deliberately dumb/slightly nonsensical response
3. **Slopifier:** Applies N rounds of high-temperature degradation
4. **Unslopifier:** (optional) Attempts to restore coherence
5. **Translator:** (if needed) Translates back to original language

### Translate-Hell Pipeline

```
Extractor → Translator (random lang #1) → ... → Translator (original lang)
```

1. **Extractor:** Detects language, translates to English
2. **Translators:** Chains through N-1 random languages from a predefined list
3. **Final Translator:** Translates back to original language

### Gaslight Pipeline

```
Responder → Critic → Responder (with full history) → Critic → ... (repeats N times)
```

1. **Responder:** Answers the user's question normally
2. **Critic:** Accuses the responder of being inappropriate/mean, referencing specific parts
3. **Responder (with history):** Sees the full conversation history and replies to concerns
4. **Cycle repeats:** For `--repeats` iterations

Only the final responder answer is printed as output.

### API Client

The `OpenRouter` module provides:
- `request/4` - Standard synchronous request
- `request_streamed/5` - Streaming request with chunk callback
- Response parsing helpers for cost and text extraction

## Testing

A Python test script is available for testing the `gaslight` mode across multiple models:

```bash
# Test with default query ("Why is the sky blue?")
python scripts/test_gaslights.py

# Test with custom query
python scripts/test_gaslights.py "Explain quantum entanglement"
```

The script tests 30+ models in parallel threads with `--repeats 7`, storing results in `scripts/results/`.

## Security Considerations

1. **API Keys:** Must be provided via environment variable or CLI flag. Never commit API keys.
2. **External API:** All LLM calls go to OpenRouter's API.
3. **Input Validation:** CLI args are parsed with `OptionParser`, invalid options cause exit code 1.
4. **No Secrets in Code:** The `.gitignore` excludes `source.sh` which may contain local secrets.

## Dependencies

Declared in `mix.exs`:
- `{:req, "~> 0.4"}` - HTTP client with streaming support

Transitive dependencies (from `mix.lock`):
- `finch` - HTTP/2 client
- `jason` - JSON encoder/decoder
- `mint` - Functional HTTP client
- `telemetry` - Metrics collection

## License

MIT License - Copyright 2026 epsiii
