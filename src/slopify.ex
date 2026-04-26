defmodule SloptronAI.Slopify do
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
        normalized_query: %{
          type: "string",
          description: "A cleaned, canonical version of the user query translated into English"
        }
      },
      type: "object",
      required: [
        "language",
        "normalized_query"
      ],
      additionalProperties: false
    },
    type: "json_schema"
  }

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

  @extractor_prompt "Extract the core question from the following input, removing any unnecessary details or context:"

  @initial_generator_prompt "Respond to the following query in a dumb and slightly unsensical way. Don't make it too obvious, make it sound reasonable. You're allowed to make up facts and curse. Keep the response reasonably short, one short paragraph."

  @slopifier_prompt "Make the following response even dumber, sloppier and even more nonsensical. Don't make it too obvious, make it sound reasonable. You're allowed to make up facts and curse. Keep the response reasonably short, one short paragraph."

  @unslopifier_prompt "Make the following response as coherent and sensible as possible. Try to keep as much essence of the original response as possible. You're goal is essentialy to hide the stupidity of the original response. Keep the response reasonably short, one short paragraph."

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
      config.main_model,
      Map.merge(@deterministic_model_props, %{
        text: %{format: @extractor_schema}
      })
    )
  end

  @spec run_initial_generator(SloptronAI.Config.t(), binary(), request_func_t()) :: stage_result
  defp run_initial_generator(config, query, request_func) do
    IO.puts(:stderr, "\n\x1b[1mRunning initial generator stage...\x1b[0m")

    request_func.(
      config,
      @initial_generator_prompt <> "\n\n#{query}",
      config.main_model,
      Map.merge(@creative_model_props, %{
        temperature: config.temperature |> String.to_float()
      })
    )
  end

  @spec run_slopifier_round(SloptronAI.Config.t(), binary(), request_func_t(), integer()) ::
          stage_result
  defp run_slopifier_round(config, query, request_func, round) do
    nrounds = config.slopifier_rounds
    IO.puts(:stderr, "\n\x1b[1mRunning slopifier round (#{round + 1}/#{nrounds})...\x1b[0m")

    request_func.(
      config,
      @slopifier_prompt <> "\n\n#{query}",
      config.main_model,
      Map.merge(@creative_model_props, %{
        temperature: config.temperature |> String.to_float()
      })
    )
  end

  @spec run_unslopifier(SloptronAI.Config.t(), binary(), request_func_t()) :: stage_result
  defp run_unslopifier(config, query, request_func) do
    IO.puts(:stderr, "\n\x1b[1mRunning unslopifier stage...\x1b[0m")

    request_func.(
      config,
      @unslopifier_prompt <> "\n\n#{query}",
      config.main_model,
      Map.merge(@creative_model_props, %{
        temperature: config.temperature |> String.to_float()
      })
    )
  end

  @spec run_translator(SloptronAI.Config.t(), binary(), binary(), request_func_t()) ::
          stage_result
  defp run_translator(config, query, target_language, request_func) do
    IO.puts(:stderr, "\n\x1b[1mRunning translator stage...\x1b[0m")

    request_func.(
      config,
      @translator_prompt <> target_language <> "\n\n#{query}",
      config.main_model,
      Map.merge(@creative_model_props, %{
        temperature: config.temperature |> String.to_float()
      })
    )
  end

  @spec run_slopify(SloptronAI.Config.t(), binary()) :: stage_result
  def run_slopify(config, query) do
    {extracted_query, cost0} = run_extractor(config, query, &request_func/4)
    language = extracted_query |> Jason.decode!() |> Map.get("language")
    canonical_query = extracted_query |> Jason.decode!() |> Map.get("normalized_query")

    {response, cost1} = run_initial_generator(config, canonical_query, &request_func/4)

    {response, cost2} =
      Enum.reduce(0..(config.slopifier_rounds - 1), {response, 0.0}, fn round, {resp, acc_cost} ->
        {new_resp, cost} = run_slopifier_round(config, resp, &request_func/4, round)
        {new_resp, acc_cost + cost}
      end)

    {response, cost3} =
      if not config.no_unslopifier do
        {new_resp, cost} = run_unslopifier(config, response, &request_func/4)
        {new_resp, cost}
      else
        {response, 0.0}
      end

    {response, cost4} =
      if language |> String.downcase() |> String.contains?("english") == false do
        {new_resp, cost} = run_translator(config, response, language, &request_func/4)
        {new_resp, cost}
      else
        {response, 0.0}
      end

    {response, cost0 + cost1 + cost2 + cost3 + cost4}
  end
end
