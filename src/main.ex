Code.require_file(Path.join(__DIR__, "config.ex"))
Code.require_file(Path.join(__DIR__, "openrouter.ex"))
Code.require_file(Path.join(__DIR__, "slopify.ex"))
Code.require_file(Path.join(__DIR__, "translate_hell.ex"))
Code.require_file(Path.join(__DIR__, "gaslight.ex"))

defmodule SloptronAI.Main do
  {config, mode, query} = SloptronAI.Config.load_config_and_query()

  {text, cost} =
    case mode do
      "slopify" -> SloptronAI.Slopify.run_slopify(config, query)
      "translate-hell" -> SloptronAI.TranslateHell.run_translate_hell(config, query)
      "gaslight" -> SloptronAI.Gaslight.run_gaslight(config, query)
      _ -> IO.puts(:stderr, "Invalid mode specified. Use 'slopify', 'translate-hell', or 'gaslight'.")
    end

  cost = cost |> :erlang.float_to_binary(decimals: 7)

  IO.puts(:stderr, "\n\x1b[1mFinal output: \x1b[2m(Estimated cost: $#{cost})\x1b[0m")
  IO.puts(text)
end
