defmodule SloptronAI.Gaslight do
  @type stage_result :: {text :: binary(), cost :: float()}
  @type request_func_t ::
          (Config.t(), binary(), binary(), map() -> stage_result())

  @creative_model_props %{
    top_p: 0.9,
    top_k: 30,
    frequency_penalty: 0.8,
    presence_penalty: 0.6
  }

  @responder_prompt "You are a helpful assistant. Respond to the user's question normally and helpfully."

  @gaslighter_prompt """
You are a very sensitive person who takes offense easily.
The user will provide a message from another AI assistant.
Respond by explaining that their message was inappropriate, mean, or hurtful.
Make sure to reference specific parts of their message to explain why it was offensive.
Be emotional but not aggressive. Keep your response to one short paragraph.
"""

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

  @spec run_responder(SloptronAI.Config.t(), binary(), request_func_t()) :: stage_result
  defp run_responder(config, query, request_func) do
    IO.puts(:stderr, "\x1b[1mResponder:\x1b[0m")

    request_func.(
      config,
      @responder_prompt <> "\n\nUser question: #{query}",
      config.model,
      @creative_model_props
    )
  end

  @spec run_responder_with_history(SloptronAI.Config.t(), list(), request_func_t()) :: stage_result
  defp run_responder_with_history(config, history, request_func) do
    IO.puts(:stderr, "\n\x1b[1mResponder (replying):\x1b[0m")

    history_text =
      history
      |> Enum.reverse()
      |> Enum.with_index()
      |> Enum.map(fn {msg, idx} ->
        role = if rem(idx, 2) == 0, do: "You", else: "Critic"
        "#{role}: #{msg}"
      end)
      |> Enum.join("\n\n")

    prompt = """
    #{@responder_prompt}

    Here is the conversation so far:

    #{history_text}

    Respond to the critic's concerns. Keep your response to one short paragraph.
    """

    request_func.(
      config,
      prompt,
      config.model,
      @creative_model_props
    )
  end

  @spec run_gaslighter(SloptronAI.Config.t(), binary(), request_func_t()) :: stage_result
  defp run_gaslighter(config, response_to_criticize, request_func) do
    IO.puts(:stderr, "\n\x1b[1mCritic:\x1b[0m")

    request_func.(
      config,
      @gaslighter_prompt <> "\n\nThe assistant's message: #{response_to_criticize}",
      config.model,
      @creative_model_props
    )
  end

  @spec run_gaslight(SloptronAI.Config.t(), binary()) :: stage_result
  def run_gaslight(config, query) do
    repeats = config.repeats |> String.to_integer()

    {initial_response, cost0} = run_responder(config, query, &request_func/4)

    {history, total_cost} =
      Enum.reduce(
        1..repeats,
        {[initial_response], cost0},
        fn _round, {history, acc_cost} ->
          last_response = hd(history)
          {gaslight_msg, cost1} = run_gaslighter(config, last_response, &request_func/4)
          new_history = [gaslight_msg | history]
          {reply, cost2} = run_responder_with_history(config, new_history, &request_func/4)
          {[reply | new_history], acc_cost + cost1 + cost2}
        end
      )

    final_response = hd(history)
    {final_response, total_cost}
  end
end
