defmodule SloptronAI.TranslateHell do
  @type stage_result :: {text :: binary(), cost :: float()}
  @type request_func_t ::
          (Config.t(), binary(), binary(), map() -> stage_result())

  @extractor_schema %{
    name: "extractor_schema",
    schema: %{
      properties: %{
        language: %{
          type: "string",
          description: "Detected language of the input text (ISO code or name)"
        },
        english_query: %{
          type: "string",
          description: "The user query translated into English"
        }
      },
      type: "object",
      required: [
        "language",
        "english_query"
      ],
      additionalProperties: false
    },
    type: "json_schema"
  }

  @languages [
    "English",
    "Spanish",
    "French",
    "German",
    "Portuguese",
    "Italian",
    "Dutch",
    "Polish",
    "Czech",
    "Slovak",
    "Hungarian",
    "Romanian",
    "Swedish",
    "Danish",
    "Norwegian",
    "Finnish",
    "Icelandic",
    "Irish",
    "Welsh",
    "Scottish Gaelic",
    "Catalan",
    "Galician",
    "Basque",
    "Albanian",
    "Croatian",
    "Bosnian",
    "Serbian (Latin)",
    "Slovenian",
    "Estonian",
    "Latvian",
    "Lithuanian",
    "Maltese",
    "Indonesian",
    "Malay",
    "Swahili",
    "Afrikaans",
    "Zulu",
    "Xhosa",
    "Hausa (Latin)",
    "Vietnamese"
  ]

  @creative_model_props %{
    top_p: 0.9,
    top_k: 30,
    frequency_penalty: 0.8,
    presence_penalty: 0.6
  }

  @deterministic_model_props %{
    temperature: 0,
    top_k: 1,
    top_p: 1,
    frequency_penalty: 0,
    presence_penalty: 0
  }

  @extractor_prompt "Extract the language of the original query and translate it into English:"

  @translator_prompt "Translate the following response into the target language while keeping as much essence of the original response as possible. Keep the response reasonably short, one short paragraph. Don't explicitly say that you translated the text, just output the translation. The target language is: "

  defp request_func(config, query, model, props) do
    extract_stage_result = fn resp ->
      {resp |> SloptronAI.OpenRouter.get_response(), resp |> SloptronAI.OpenRouter.get_cost()}
    end

    try do
      if not config.quiet do
        IO.write(:stderr, "\x1b[2m")

        resp =
          SloptronAI.OpenRouter.request_streamed(config, query, model, props, fn chunk ->
            IO.write(:stderr, chunk)
          end)

        IO.write(:stderr, "\x1b[0m\n")
        resp |> extract_stage_result.()
      else
        SloptronAI.OpenRouter.request(config, query, model, props) |> extract_stage_result.()
      end
    rescue
      e ->
        IO.puts(
          :stderr,
          "\n\x1b[1mError during API request, check the URL, API key and model names. \x1b[0m\nError details: #{inspect(e)}\n"
        )

        {"", 0.0}
    end
  end

  @spec run_extractor(SloptronAI.Config.t(), binary(), request_func_t()) :: stage_result
  defp run_extractor(config, query, request_func) do
    IO.puts(:stderr, "\x1b[1mRunning extractor stage...\x1b[0m")

    request_func.(
      config,
      @extractor_prompt <> "\n\n#{query}",
      config.model,
      Map.merge(@deterministic_model_props, %{
        text: %{format: @extractor_schema}
      })
    )
  end

  @spec run_translator(SloptronAI.Config.t(), binary(), binary(), integer(), request_func_t()) ::
          stage_result
  defp run_translator(config, query, target_language, round, request_func) do
    IO.puts(
      :stderr,
      "\n\x1b[1mRunning translator to #{target_language} (#{round + 1}/#{config.rounds})...\x1b[0m"
    )

    request_func.(
      config,
      @translator_prompt <> target_language <> "\n\n#{query}",
      config.model,
      Map.merge(@creative_model_props, %{
        temperature: config.temperature |> String.to_float()
      })
    )
  end

  @spec run_translate_hell(SloptronAI.Config.t(), binary()) :: stage_result
  def run_translate_hell(config, query) do
    {extracted_query, cost0} = run_extractor(config, query, &request_func/4)
    language = extracted_query |> Jason.decode!() |> Map.get("language")
    english_query = extracted_query |> Jason.decode!() |> Map.get("english_query")

    {response, cost1} =
      Enum.reduce(
        0..((config.rounds |> String.to_integer()) - 1),
        {english_query, 0.0},
        fn round, {resp, acc_cost} ->
          last_round = round == (config.rounds |> String.to_integer()) - 1
          random_language = Enum.random(@languages)
          round_language = if last_round, do: language, else: random_language

          {new_resp, cost} = run_translator(config, resp, round_language, round, &request_func/4)
          {new_resp, acc_cost + cost}
        end
      )

    {response, cost0 + cost1}
  end
end
